#!/usr/bin/env ruby

require 'sinatra'
require 'sinatra/cross_origin'
require "sinatra/reloader"
require 'nanomsg'
require 'zipf'
require 'json'
require 'haml'

# #############################################################################
# Load configuration file and setup global variables
# #############################################################################
require_relative "#{ARGV[0]}" # load configuration for this session
$lock       = false           # lock if currently learning/translating
$last_reply = nil             # cache last reply
$confirmed = true             # client received translation?
$additional_rules = []
if !FileTest.exist? LOCK_FILE # locked?
  $db  = {}                   # FIXME: that is supposed to be a database connection
  $env = {}                   # environment variables (socket connections to daemons)
end

# #############################################################################
# Daemons
# #############################################################################
$daemons = {
  :tokenizer    => "/fast_scratch/simianer/lfpe/lfpe/util/wrapper.rb -a tokenize   -S '__ADDR__' -e #{EXTERNAL} -l #{TARGET_LANG}",
  :detokenizer  => "/fast_scratch/simianer/lfpe/lfpe/util/wrapper.rb -a detokenize -S '__ADDR__' -e #{EXTERNAL} -l #{TARGET_LANG}",
  :truecaser    => "/fast_scratch/simianer/lfpe/lfpe/util/wrapper.rb -a truecase   -S '__ADDR__' -e #{EXTERNAL} -t #{SESSION_DIR}/truecase.model",
  :dtrain       => "#{CDEC}/training/dtrain/dtrain_net_interface -c #{SESSION_DIR}/dtrain.ini -d #{WORK_DIR}/dtrain.debug.json -o #{WORK_DIR}/weights -a '__ADDR__'",
  :extractor    => "python -m cdec.sa.extract -c #{SESSION_DIR}/sa.ini --online -u -S '__ADDR__'",
  :aligner_fwd  => "#{CDEC}/word-aligner/net_fa -f #{SESSION_DIR}/forward.params  -m #{FWD_MEAN_SRCLEN_MULT}  -T #{FWD_TENSION}  --sock_url '__ADDR__'",
  :aligner_back => "#{CDEC}/word-aligner/net_fa -f #{SESSION_DIR}/backward.params -m #{BACK_MEAN_SRCLEN_MULT} -T #{BACK_TENSION} --sock_url '__ADDR__'",
  :atools       => "#{CDEC}/utils/atools_net -c grow-diag-final-and -S '__ADDR__'"
}

# #############################################################################
# Set-up Sinatra
# #############################################################################
set :bind,              SERVER_IP
set :port,              WEB_PORT
set :allow_origin,      :any
set :allow_methods,     [:get, :post, :options]
set :allow_credentials, true
set :max_age,           "1728000"
set :expose_headers,    ['Content-Type']
set :public_folder,     File.dirname(__FILE__) + '/static'


# #############################################################################
# Helper functions
# #############################################################################
def logmsg name, msg
  STDERR.write "[#{name}] #{msg}\n"
end

def start_daemon cmd, name, addr
  logmsg :server, "starting #{name} daemon"
  cmd.gsub! '__ADDR__', addr
  pid = fork do
    exec cmd
  end
  sock = NanoMsg::PairSocket.new
  sock.connect addr
  logmsg :server, "< got #{sock.recv} from #{name}"

  return sock, pid
end

def stop_all_daemons
  logmsg :server, "shutting down all daemons"
  $env.each { |name,p|
    p[:socket].send "shutdown" # every daemon shuts down after receiving this keyword
    logmsg :server, "< #{name} is #{p[:socket].recv}"
  }
end

def update_database
  $db['progress'] += 1
  j = JSON.generate $db                                # FIXME: proper database
  f = WriteFile.new DB_FILE
  f.write j.to_s
  f.close
end

def init
  # database connection
  $db = JSON.parse ReadFile.read DB_FILE               # FIXME: proper database
  # working directory
  `mkdir -p #{WORK_DIR}/g`
  # setup environment, start daemons
  port = BEGIN_PORT_RANGE
  $daemons.each { |name,cmd|
    sock, pid = start_daemon cmd, name, "tcp://127.0.0.1:#{port}"
    $env[name] = { :socket => sock, :pid => pid }
    port += 1
  }
  # lock
  `touch #{LOCK_FILE}`
end

def send_recv daemon, msg                            # simple pair communcation
  socket = $env[daemon][:socket]                     # query -> answer
  logmsg daemon, "> sending message: '#{msg}'"
  socket.send msg
  logmsg daemon, "waiting ..."
  ans = socket.recv.force_encoding("UTF-8").strip
  logmsg daemon, "< received answer: '#{ans}'"

  return ans
end

# #############################################################################
# Run init() [just once]
# #############################################################################
init if !FileTest.exist?(LOCK_FILE)

# #############################################################################
# Routes
# #############################################################################
get '/' do
  cross_origin

  return ""                                                            # return
end

get '/next' do      # (receive post-edit, update models), send next translation
  cross_origin
  # already processing request?
  return "locked" if $lock                                             # return
  $lock = true
  key = params[:key]            # FIXME: do something with it, e.g. simple auth

  if params[:correct]
    logmsg :server, "correct: #{params[:correct]}"
    grammar = "#{WORK_DIR}/g/#{$db['progress']}.grammar"
    src, tgt = splitpipe(params[:correct])
    src = src.split(';').map { |i| i.strip }
    tgt = tgt.split(';').map { |i| i.strip }
    src.each_with_index { |s,i|
      rule = "[X] ||| #{s} ||| #{tgt[i]} ||| ForceRule=1 ||| 0-0"
      $additional_rules << rule
    }
    $confirmed = true
  end
  # received post-edit -> update models
  # 0. save raw post-edit
  # 1. tokenize
  # 2. truecase
  # 3. save processed post-edit
  # 4. update weights
  # 5. update grammar extractor
  # 5a. forward alignment
  # 5b. backward alignment
  # 5c. symmetrize alignment
  # 5d. actual update
  # 6. update database
  if params[:example]
    # 0. save raw post-edit
    source, reference = params[:example].strip.split(" ||| ")
    $db['post_edits_raw'] << reference.strip
    $db['durations'] << params['duration'].to_i
    # 1. tokenize
      reference = send_recv :tokenizer, reference
    # 2. truecase
      reference = send_recv :truecaser, reference
    # 3. save processed post-edits
      logmsg "db", "saving processed post-edit"
      $db['post_edits'] << reference.strip
    if !NOLEARN && !NOMT
    # 4. update weights
      grammar = "#{WORK_DIR}/g/#{$db['progress']}.grammar"
      annotated_source = "<seg grammar=\"#{grammar}\"> #{source} </seg>"
      send_recv :dtrain, "#{annotated_source} ||| #{reference}"
    # 5. update grammar extractor
    # 5a. get forward alignment
      a_fwd = send_recv :aligner_fwd, "#{source} ||| #{reference}"
    # 5b. get backward alignment
      a_back = send_recv :aligner_back, "#{source} ||| #{reference}"
    # 5c. symmetrize alignment
      a = send_recv :atools, "#{a_fwd} ||| #{a_back}"
    # 5d actual extractor
      send_recv :extractor, "default_context ||| #{source} ||| #{reference} ||| #{a}"
    # 6. update database
      logmsg "db", "updating database"
    end
      update_database
  end
  source     = $db['source_segments'][$db['progress']]
  raw_source = $db['raw_source_segments'][$db['progress']]
  if !source # input is done -> displays 'Thank you!'
    logmsg :server, "end of input, sending 'fi'"
    $lock = false
    return "fi"                                                        # return
  elsif !$confirmed
    logmsg :server, "locked, re-sending last reply"
    $lock = false
    return $last_reply                                                 # return
  else
    # translate next sentence
    # 0. no mt?
    # 1. generate grammar
    # 2. check for OOV
    # 3. translate
    # 4. detokenize
    # 5. reply
    source.strip!
    # 0. no mt?
    if NOMT
      $lock = false
      logmsg :server, "no mt"
      return "#{$db['progress']}\t#{source}\t \t#{raw_source}"         # return
    end
    # 1. generate grammar for current sentence
    grammar = "#{WORK_DIR}/g/#{$db['progress']}.grammar"
    send_recv :extractor, "default_context ||| #{source} ||| #{grammar}"
    # - additional rules
    $additional_rules.each { |rule|
     logmsg :server, "adding rule '#{rule}' to grammar '#{grammar}'"
     `echo "#{rule}" >> #{grammar}`
    }
    # 2. check for OOV
    src_r = ReadFile.readlines(grammar).map {
      |l| splitpipe(l)[1].strip.split
    }.flatten.uniq
    oovs = []
    source.split.each { |token|
      if !src_r.include? token
        oovs << token
        logmsg :server, "OOV token: '#{token}'"
      end
    }
    oovs.uniq!
    logmsg :server, "OOVs: #{oovs.to_s}"
    if oovs.size > 0
      $last_reply = "OOV\t#{$db['progress']}\t#{oovs.map{|i| "\"#{i}\""}.join("\t")}"
      logmsg :server, "OOV reply: '#{$last_reply}'"
      $lock = false
      $confirmed = false
      return $last_reply                                               # return
    end
    # 3. translation
    msg = "act:translate ||| <seg grammar=\"#{grammar}\"> #{source} </seg>"
    transl = send_recv :dtrain, msg
    $db['mt_raw'] << transl
    # 4. detokenizer
    transl = send_recv :detokenizer, transl
    $db['mt'] << transl
    # 5. reply
    $last_reply = "#{$db['progress']}\t#{source}\t#{transl.strip}\t#{raw_source}"
    $lock = false
    $confirmed = false
    logmsg :server, "response: '#{$last_reply}'"
    return $last_reply                                                 # return
  end

  return "oh oh"                          # return FIXME: do something sensible
end

get '/debug' do                                                    # debug view
  fn = "#{WORK_DIR}/dtrain.debug.json"                      # TODO: other tools
  data = JSON.parse ReadFile.read(fn).force_encoding("UTF-8")

  haml :debug, :locals => { :data => data, :session_key => SESSION_KEY }
end

get '/confirm' do                        # client confirms received translation
  cross_origin
  $confirmed = true
  logmsg :server, "confirmed = #{$confirmed}"

  return "#{$confirmed}"
end

get '/set_learning_rate/:rate' do
  logmsg :server, "set learning rate, #{params[:rate]}"
  return "locked" if $lock
  send_recv :dtrain, "set_learning_rate #{params[:rate].to_f}"

  return "done"
end

get '/set_sparse_learning_rate/:rate' do
  logmsg :server, "set sparse learning rate, #{params[:rate]}"
  return "locked" if $lock
  send_recv :dtrain, "set_sparse_learning_rate #{params[:rate].to_f}"

  return "done"
end

get '/reset' do                                         # reset current session
  return "locked" if $lock
  $db = JSON.parse ReadFile.read DB_FILE               # FIXME: proper database
  $db['post_edits'].clear
  $db['post_edits_raw'].clear
  update_database
  $db['progress'] = 0
  $confirmed = true

  return "#{$db.to_s}"
end

get '/reset_weights' do
  logmsg :server, "reset weights"
  return "locked" if $lock
  send_recv :dtrain, "reset_weights"

  return "done"
end

get '/reset_extractor' do
  logmsg :server, "reset extractor"
  return "locked" if $lock
  send_recv :extractor, "default_context ||| drop"

  return "done"
end

get '/reset_add_rules' do
  $additional_rules.clear

  return "done"
end

get '/shutdown' do                          # stop daemons and shut down server
  logmsg :server, "shutting down daemons"
  stop_all_daemons

  return "stopped all daemons, ready to shutdown"
end

