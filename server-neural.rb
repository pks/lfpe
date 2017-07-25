#!/usr/bin/env ruby

require 'sinatra'
require 'sinatra/cross_origin'
require 'sinatra/reloader'
require 'nanomsg'
require 'zipf'
require 'json'
require 'tilt/haml'
require 'uri'
require 'rack'

# #############################################################################
# Load configuration file and setup global variables
# #############################################################################
require_relative "#{ARGV[0]}"        # load configuration for this session
$lock                    = false     # lock if currently learning/translating
$last_reply              = nil       # cache last reply
$last_processed_postedit = ""        # to show to the user
$confirmed               = true      # client received translation?
if !FileTest.exist? LOCK_FILE        # locked?
  $db  = {}                          # data file (JSON format)
  $env = {}                          # environment variables (socket connections to daemons)
end
$status                  = "Idle"    # current server status

# #############################################################################
# Daemons
# #############################################################################
DIR="/srv/postedit"
$daemons = {
  :tokenizer        => "#{DIR}/lfpe/util/nanomsg_wrapper.rb -a tokenize   -S '__ADDR__' -e #{EXTERNAL} -l #{TARGET_LANG}",
  :tokenizer_src    => "#{DIR}/lfpe/util/nanomsg_wrapper.rb -a tokenize   -S '__ADDR__' -e #{EXTERNAL} -l #{SOURCE_LANG}",
  :detokenizer      => "#{DIR}/lfpe/util/nanomsg_wrapper.rb -a detokenize -S '__ADDR__' -e #{EXTERNAL} -l #{TARGET_LANG}",
  :detokenizer_src  => "#{DIR}/lfpe/util/nanomsg_wrapper.rb -a detokenize -S '__ADDR__' -e #{EXTERNAL} -l #{SOURCE_LANG}",
  :bpe              => "#{DIR}/lfpe/util/nanomsg_wrapper.rb -a bpe        -S '__ADDR__' -e #{EXTERNAL} -b #{SESSION_DIR}/bpe", #-B #{SESSION_DIR}/#{TARGET_LANG}",
  #:debpe            => "#{DIR}/lfpe/util/nanomsg_wrapper.rb -a de-bpe     -S '__ADDR__' -e #{EXTERNAL}",
  :truecaser        => "#{DIR}/lfpe/util/nanomsg_wrapper.rb -a truecase   -S '__ADDR__' -e #{EXTERNAL} -t #{SESSION_DIR}/truecase.model",
  #:lamtram          => "#{DIR}/online-lamtram/src/lamtram/lamtram-train-online --master_addr '__ADDR__' --model_in #{SESSION_DIR}/model --model_out #{SESSION_DIR}/model.out --dropout 0.5 --learning_rate 0.5 --beam_size 1 --size_limit 100 --unk_penalty 1.0 --word_penalty 2.5"
}

$remote_daemons = {
  :lamtram => true
}

# #############################################################################
# Set-up Sinatra
# #############################################################################
set :server,            'thin'
set :bind,              SERVER_IP
set :port,              WEB_PORT
set :allow_origin,      :any
set :allow_methods,     [:get, :post]
set :allow_credentials, true
set :max_age,           "1728000"
set :expose_headers,    ['Content-Type']
set :public_folder,     File.dirname(__FILE__) + '/static'

Rack::Utils.key_space_limit = 68719476736

# #############################################################################
# Helper functions
# #############################################################################
def logmsg name, msg
  STDERR.write "[#{name}] #{msg}\n"
end

def start_daemon cmd, name, addr
  logmsg :server, "starting #{name} daemon"
  cmd.gsub! '__ADDR__', addr

  sock = NanoMsg::PairSocket.new
  sock.connect addr
  pid = spawn(cmd)
  Process.detach pid
  logmsg :server, "#{name} detached"
  logmsg :server, "< got #{sock.recv} from #{name}"

  return sock, pid
end

def stop_daemon key
    $env[key][:socket].send "shutdown"                   # every daemon shuts down
                                                 # after receiving this keyword
    logmsg :server, "< #{key} is #{$env[key][:socket].recv}"
end

def stop_all_daemons
  $status = "Shutting down"                                            # status
  logmsg :server, "shutting down all daemons"
  $env.each_key { |k|
    stop_daemon k
  }

  $status = "Ready to shutdown"                                        # status
end

def update_database reset=false
  $status = "Updating database"                                        # status
  if !reset
    $db['progress'] += 1
  else
    $db['progress'] = 0
  end
  j = JSON.generate $db
  f = WriteFile.new DB_FILE
  f.write j.to_s
  f.close

  $status = "Updated database"                                         # status
end

def init
  $status = "Initialization"                                           # status
  $db = JSON.parse ReadFile.read DB_FILE                  # data from JSON file
                                                            # working directory
  `mkdir -p #{WORK_DIR}/`
  `mkdir #{WORK_DIR}/g`

  if OLM
    `mkfifo #{WORK_DIR}/refp`
  end

                                             # setup environment, start daemons
  port = BEGIN_PORT_RANGE
  $daemons.each { |name,cmd|
    logmsg :server, "starting #{name} daemon"
    sock, pid = start_daemon cmd, name, "tcp://147.142.207.34:#{port}"
    $env[name] = { :socket => sock, :pid => pid }
    port += 1
    logmsg :server, "starting #{name} daemon done"
  }
  $remote_daemons.each { |name,_|
    addr = "tcp://147.142.207.34:#{port}"
    sock = NanoMsg::PairSocket.new
    sock.bind addr 
    logmsg :server, "waiting for remote daemon #{name} on #{addr}"
    logmsg :server, "< got #{sock.recv} from remote #{name}"
    $env[name] =  { :socket => sock, :pid => nil }
    port += 1
  }

  send_recv :truecaser, "lOaD iT"
  send_recv :bpe, "blablablubbbla"
  #send_recv :debpe, "asdf@@ asd"

                                                                   #  lock file
  `touch #{LOCK_FILE}`
  $status = "Initialized"                                              # status
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
  cross_origin                           # enable Cross-Origin Resource Sharing

  return ""                                                            # return
end

post '/next' do
  cross_origin

  $status = "Received request"                                         # status
  reply = request.body.read
  Thread.new { process_next reply }
end

def process_next reply
  $status = "Processing request"                                       # status
  data = JSON.parse(URI.decode(reply))
  if $lock
    $status = "Locked"                                                 # status
    return
  end
  $lock = true                                                           # lock
  if !data['name'] || data['name'] == ""
    $status = "Error: Name not given."
    return
  end
  if data['key'] != SESSION_KEY
    $status =  "Error: Key mismatch (#{data['key']}, #{SESSION_KEY})"
    return
  end

  if data["EDIT"]
    $status = "Processing post-edit"                                   # status
    logmsg :server, "received post-edit"
                                                        # 0. save raw post-edit
    source = data["source_value"]
    post_edit = data["post_edit"]
    $status  = "Processing post-edit ..."                              # status
    post_edit.strip!
    post_edit.lstrip!
                                                                      # fill db
    $db['feedback']           << reply
    $db['post_edits_raw']     << post_edit
    $db['durations']          << data['duration'].to_f
    $db['durations_rating']   << data['duration_rating'].to_f
    $db['count_click']        << data['count_click'].to_i
    $db['count_kbd']          << data['count_kbd'].to_i
    $db['post_edits_display'] << send_recv(:detokenizer, post_edit)
    $db['ratings']            << data['rating'].to_f
    $last_processed_postedit = $db['post_edits_display'].last
    # 1. tokenize
      $status = "Tokenizing post-edit"                                 # status
      logmsg :server, "tokenizing post-edit"
      post_edit = send_recv :tokenizer, post_edit
    # 2. truecase
      $status = "Truecasing post-edit"                                 # status
      logmsg :server, "truecasing post-edit"
      post_edit = send_recv :truecaser, post_edit
    # 3. bpe
      $status = "BPE'ing post-edit"
      logmsg :server, "bpe'ing post-edit"
      post_edit = send_recv :bpe, post_edit
    # 4. save processed post-edits
      $status = "saving processed post-edit"                           # status
      logmsg :db, "saving processed post-edit"
      $db['post_edits'] << post_edit.strip
    if data['nochange']
      logmsg :server, "no change"
    end
    if !NOLEARN && !NOMT
      $status = "Updating model"                                      # status
      logmsg :server, "updating ..."
      $status = "Learning from post-edit"                              # status
      send_recv :lamtram, "act:learn ||| #{source} ||| #{post_edit}"
      $db['updated'] << true
    end
    logmsg :db, "updating database"
    update_database
  end
  $status = "Getting next data to translate"                           # status
  source     = $db['source_segments'][$db['progress']]
  raw_source = $db['raw_source_segments'][$db['progress']]
  if !source                                                    # input is done
    begin
      stop_daemon :lamtram
    rescue
    end
    logmsg :server, "end of input, sending 'fin'"
    $lock = false
    $status = "Ready"                                                  # status
    $last_reply = {'fin'=>true,
      'processed_postedit'=>$last_processed_postedit
    }.to_json
    return                                                             # return
  elsif !$confirmed \
    || ($confirmed && $last_reply && $last_reply!="" \
        && !data["EDIT"])                                     # send last reply
    logmsg :server, "locked, re-sending last reply"
    logmsg :server, "last_reply: '#{$last_reply}'"
    $lock = false
    $status = "Ready"                                                  # status
    return
  else
    source = source.strip.lstrip
    raw_source = raw_source.strip.lstrip

    if NOMT                                                         # 0. no mt?
      $lock = false
      logmsg :server, "no mt"
      obj = Hash.new
      obj["progress"]   = $db["progress"]
      obj["source"]     = source
      obj["raw_source"] = raw_source
      obj["processed_postedit"] = $last_processed_postedit
      $last_reply = obj.to_json
      $status = "Ready"                                                # status
      return
    end

    $status = "Translating"                                            # status
    msg = "act:translate ||| #{source}"
    obj = Hash.new
    obj["transl_bpe"] = send_recv :lamtram, msg
    obj["transl"] = send_recv(:truecaser, obj["transl_bpe"].gsub(/((@@ )|@@$)/, "")).strip
    $status = "Processing raw translation"                             # status
    obj["transl_detok"] = send_recv(:detokenizer, obj["transl"]).strip
    obj["source"]     = source
    obj["progress"]   = $db['progress']
    obj["raw_source"] = raw_source
    $db["mt_raw_bpe"]       << obj["transl_bpe"]
    $db["mt_raw"]           << obj["transl"]
    $db["mt"]               << obj["transl_detok"]
    obj["processed_postedit"] = $last_processed_postedit
                                                                     # 5. reply
    $last_reply = obj.to_json
    $lock = false
    $confirmed = false
    logmsg :server, "response: '#{$last_reply}'"
    $status = "Ready"                                                  # status
    return                                                             # return
  end
end

get '/fetch' do                                                    # fetch next
  cross_origin
  return "Locked" if $locked
  return $last_reply
end

get '/fetch_processed_postedit/:i' do                     # processed post-edit
  cross_origin
  i = params[:i].to_i
  return $db['post_edits_display'][i]
end

get '/progress' do                                        # processed post-edit
  cross_origin
  return $db['progress']
end

get '/status' do                                                 # check status
  cross_origin
  logmsg :server, "status: #{$status}"
  return "Locked" if $locked
  return $status
end

get '/status_debug' do                                                 # check status
  cross_origin
  logmsg :server, "status: #{$status}"
  return "[##{$db["progress"]}] Locked" if $locked
  return "[##{$db["progress"]}] #{$status}"
end

get '/confirm' do                        # client confirms received translation
  cross_origin
  $confirmed = true
  logmsg :server, "confirmed = #{$confirmed}"

  return "#{$confirmed}"
end

get '/reset_progress' do                                # reset current session
  return "locked" if $lock
  $db = JSON.parse ReadFile.read DB_FILE
  $db['post_edits'].clear
  $db['post_edits_raw'].clear
  $db['post_edits_display'].clear
  $db['mt'].clear
  $db['mt_raw'].clear
  $db['updated'].clear
  $db['durations'].clear
  $db['durations_rating'].clear
  $db['feedback'].clear
  $db['progress'] = -1
  $db['count_kbd'].clear
  $db['count_click'].clear
  $db['ratings'].clear
  update_database true
  $confirmed = true
  $last_reply = nil

  return "progress reset: done"
end

get '/shutdown' do                          # stop daemons and shut down server
  logmsg :server, "shutting down daemons"
  stop_all_daemons

  return "stopped all daemons, ready to shutdown"
end

get '/summary' do
  logmsg :server, "showing summary"

  data = JSON.parse ReadFile.read(DB_FILE).force_encoding("UTF-8")

  bleu_scores = []
  data["post_edits"].each_with_index { |pe,j|
    f = Tempfile.new "lfpe-summary-pe"
    g = Tempfile.new "lfpe-summary-ref"
    f.write pe+"\n"
    g.write data["references"][j]+"\n"
    f.close
    g.close
    bleu_scores << [1.0, (`#{CDEC}/mteval/fast_score -i #{f.path} -r #{g.path} -m ibm_bleu 2>/dev/null`.to_f).round(2)].min
    f.unlink
    g.unlink
  }

  ter_scores = []
  data["post_edits"].each_with_index { |pe,j|
    f = Tempfile.new "lfpe-summary-pe"
    g = Tempfile.new "lfpe-summary-ref"
    f.write pe.gsub("@@ ","")+"\n"
    g.write data["references"][j]+"\n"
    f.close
    g.close
    ter_scores << [1.0, (`#{CDEC}/mteval/fast_score -i #{f.path} -r #{g.path} -m ter 2>/dev/null`.to_f).round(2)].min
    f.unlink
    g.unlink
  }

  hter_scores = []
  data["post_edits"].each_with_index { |pe,j|
    f = Tempfile.new "lfpe-summary-mt"
    g = Tempfile.new "lfpe-summary-pe"
    f.write data["mt_raw"][j]+"\n"
    g.write pe.gsub("@@ ", "")+"\n"
    f.close
    g.close
    hter_scores << [1.0, (`#{CDEC}/mteval/fast_score -i #{f.path} -r #{g.path} -m ter 2>/dev/null`.to_f).round(2)].min
    f.unlink
    g.unlink
  }

  haml :summary, :locals => { :session_key => SESSION_KEY,
                              :data => data,
                              :bleu_scores => bleu_scores,
                              :ter_scores => ter_scores,
                              :hter_scores => hter_scores }

end

