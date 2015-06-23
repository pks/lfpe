#!/usr/bin/env ruby

require 'sinatra'
require 'sinatra/cross_origin'
require "sinatra/reloader"
require 'nanomsg'
require 'zipf'
require 'digest'
require 'json'
require 'haml'

# #############################################################################
# Load configuration file and setup global variables
# #############################################################################
require_relative "#{ARGV[0]}" # load configuration for this session
$lock       = false           # lock if currently learning/translating
$last_reply = nil             # cache last reply
$confirmed = true             # client received translation?
if !FileTest.exist? LOCK_FILE # locked?
  $db  = {}                   # FIXME: that is supposed to be a database connection
  $env = {}                   # environment variables (socket connections to daemons)
end

# #############################################################################
# Daemons
# #############################################################################
$daemons = {
  :detokenizer  => "/fast_scratch/simianer/lfpe/lfpe/util/de-tok.rb -a D -S '__ADDR__' -p #{SCRIPTS} -l #{TARGET_LANG}",
  :tokenizer    => "/fast_scratch/simianer/lfpe/lfpe/util/de-tok.rb -a T -S '__ADDR__' -p #{SCRIPTS} -l #{TARGET_LANG}",
  :truecaser    => "/fast_scratch/simianer/lfpe/lfpe/util/truecase.rb -S '__ADDR__' -m #{MOSES} -n #{DATA_DIR}/truecaser", # FIXME: run as real daemon
  :dtrain       => "#{CDEC}/training/dtrain/dtrain_net_interface -c #{DATA_DIR}/dtrain.ini -d #{WORK_DIR}/dtrain.debug.json -o #{WORK_DIR}/weights.final -a '__ADDR__'",
  :extractor    => "python -m cdec.sa.extract -c #{DATA_DIR}/sa.ini --online -u -S '__ADDR__'",
  :aligner_fwd  => "#{CDEC}/word-aligner/net_fa -f #{DATA_DIR}/forward.params  -m #{FWD_MEAN_SRCLEN_MULT}  -T #{FWD_TENSION}  --sock_url '__ADDR__'",
  :aligner_back => "#{CDEC}/word-aligner/net_fa -f #{DATA_DIR}/backward.params -m #{BACK_MEAN_SRCLEN_MULT} -T #{BACK_TENSION} --sock_url '__ADDR__'",
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
  j = JSON.generate $db                                  # FIXME: real database
  f = WriteFile.new DB_FILE
  f.write j.to_s
  f.close
end

def init
  # database connection
  $db = JSON.parse ReadFile.read DB_FILE                 # FIXME: real database
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
  socket = $env[daemon][:socket]
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

  return ""
end

get '/next' do      # (receive post-edit, update models), send next translation
  cross_origin
  # already processing request?
  return "locked" if $lock                                             # return
  $lock = true
  key = params[:key]                              # FIXME: do something with it

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
    # 1. tokenize
      reference = send_recv :tokenizer, reference
    # 2. truecase
      reference = send_recv :truecaser, reference
    # 3. save processed post-edits
      logmsg "db", "saving processed post-edit"
      $db['post_edits'] << reference.strip
    # 4. update weights
      grammar = "#{WORK_DIR}/g/#{Digest::SHA256.hexdigest(source)}.grammar"
      annotated_source = "<seg grammar=\"#{grammar}\"> #{source} </seg>"
      send_recv :dtrain, "#{annotated_source} ||| #{reference}"
    # 5. update grammar extractor
    # 5a. get forward alignment
      a_fwd = send_recv :aligner_fwd, "#{source} ||| #{reference}"
    # 5b. get backward alignment
      a_back = send_recv :aligner_back, "#{reference} ||| #{source}"
    # 5c. symmetrize alignment
      a = send_recv :atools, "#{a_fwd} ||| #{a_back}"
    # 5d actual extractor
      send_recv :extractor, "- ||| #{source} ||| #{reference} ||| #{a}"
    # 6. update database
      logmsg "db", "updating database"
      update_database
  end
  source     = $db['source_segments'][$db['progress']]
  raw_source = $db['raw_source_segments'][$db['progress']]
  if !source # input is done -> displays 'Thank you!'
    logmsg "server", "end of input, sending 'fi'"
    $lock = false
    return "fi"                                                        # return
  elsif !$confirmed
    logmsg :server, "locked, re-sending last reply"
    $lock = false
    return $last_reply                                                 # return
  else
    # translate next sentence
    # 1. generate grammar
    # 2. translate
    # 3. detokenize
    # 4. reply
    source.strip!
    # 1. generate grammar for current sentence
    grammar = "#{WORK_DIR}/g/#{Digest::SHA256.hexdigest(source)}.grammar"
    msg = "- ||| #{source} ||| #{grammar}"
    send_recv :extractor, msg               # FIXME: content identifier useful?
    # 2. translation
    msg = "act:translate ||| <seg grammar=\"#{grammar}\"> #{source} </seg>"
    transl = send_recv :dtrain, msg
    # 3. detokenizer
    transl = send_recv :detokenizer, transl
    # 4. reply
    $last_reply = "#{$db['progress']}\t#{source}\t#{transl.strip}\t#{raw_source}"
    $lock = false
    $confirmed = false
    logmsg :server, "response: '#{$last_reply}'"
    return $last_reply                                                 # return
  end

  return "oh oh"                          # return FIXME: do something sensible
end

get '/debug' do                                                    # debug view
  fn = "#{WORK_DIR}/dtrain.debug.json"
  data = JSON.parse ReadFile.read(fn).force_encoding("UTF-8")

  haml :debug, :locals => { :data => data }
end

get '/confirm' do                        # client confirms received translation
  cross_origin
  $confirmed = true
  logmsg :server, "confirmed = #{$confirmed}"

  return "#{$confirmed}"
end

get '/shutdown' do                          # stop daemons and shut down server
  logmsg :server, "shutting down daemons"
  stop_all_daemons

  return "ready to shutdown"
end

get '/reset' do                                         # reset current session
  return "locked" if $lock
  $db = JSON.parse ReadFile.read DB_FILE                   # FIXME: database ..
  $db['post_edits'].clear
  $db['post_edits_raw'].clear
  update_database
  $db['progress'] = 0
  $confirmed = true

  return "#{$db.to_s}"
end

get '/load/:name' do                       # load other db file than configured
  return "locked" if $lock
  $db = JSON.parse ReadFile.read "#{DATA_DIR}/#{params[:name]}.json.original"
  $db['post_edits'].clear
  $db['post_edits_raw'].clear
  update_database
  $db['progress'] = 0
  $confirmed = true

  "#{$db.to_s}"
end

