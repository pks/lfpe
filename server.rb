#!/usr/bin/env ruby

require 'sinatra'
require 'sinatra/cross_origin'
require "sinatra/reloader"
require 'nanomsg'
require 'zipf'
require 'digest'
require 'json'

# load configuration file and setup global variables
require_relative "#{ARGV[0]}"
$lock       = false # lock if currently learning/translating
$last_reply = nil   # cache last reply
$confirmed = true   # client received translation?
if !FileTest.exist? LOCK_FILE
  $db  = {} # FIXME: that is supposed to be a database connection
  $env = {}
end

$daemons = {
  :detokenizer  => "/fast_scratch/simianer/lfpe/lfpe/de-tok.rb -a D -S '__ADDR__' -p #{SCRIPTS_DIR} -l #{TARGET_LANG}",
  :tokenizer    =>  "/fast_scratch/simianer/lfpe/lfpe/de-tok.rb -a T -S '__ADDR__' -p #{SCRIPTS_DIR} -l #{TARGET_LANG}",
  :extractor    => "python -m cdec.sa.extract -c #{DATA_DIR}/sa.ini --online -u -S '__ADDR__'",
  :aligner_fwd  => "#{CDEC_NET}/word-aligner/net_fa -f #{DATA_DIR}/a/forward.params -m #{FWD_MEAN_SRCLEN_MULT} -T #{FWD_TENSION} --sock_url '__ADDR__'",
  :aligner_back => "#{CDEC_NET}/word-aligner/net_fa -f #{DATA_DIR}/a/backward.params -m #{BACK_MEAN_SRCLEN_MULT} -T #{BACK_TENSION} --sock_url '__ADDR__'",
  :atools       => "#{CDEC_NET}/utils/atools_net -c grow-diag-final-and -S '__ADDR__'",
  :dtrain       => "#{CDEC_NET}/training/dtrain/dtrain_net_interface -c #{DATA_DIR}/dtrain.ini -o #{WORK_DIR}/weights.final -a '__ADDR__'"
}

# setup Sinatra
set :bind,              SERVER_IP
set :port,              WEB_PORT
set :allow_origin,      :any
set :allow_methods,     [:get, :post, :options]
set :allow_credentials, true
set :max_age,           "1728000"
set :expose_headers,    ['Content-Type']

def start_daemon cmd, name, addr
  STDERR.write "> starting #{name} daemon\n"
  cmd.gsub! '__ADDR__', addr
  pid = fork do
    exec cmd
  end
  sock = NanoMsg::PairSocket.new
  sock.connect addr
  STDERR.write "< got #{sock.recv} from #{name}\n"

  return sock, pid
end

def stop_all_daemons
  STDERR.write "shutting down all daemons\n"
  $env.each { |name,p|
    p[:socket].send "shutdown"
    STDERR.write "< #{name} is #{p[:socket].recv}\n"
  }
end

def update_database # FIXME: real database
  $db['progress'] += 1
  j = JSON.generate $db
  f = WriteFile.new DB_FILE
  f.write j.to_s
  f.close
end

def init
  # database connection
  $db = JSON.parse ReadFile.read DB_FILE
  # working directory
  `mkdir -p #{WORK_DIR}/g`
  # setup environment, start daemons
  port = BEGIN_PORT_RANGE
  $daemons.each { |name,cmd|
    sock, pid = start_daemon cmd, name, "tcp://127.0.0.1:#{port}"
    $env[name] = { :socket => sock, :pid => pid }
    port += 1
  }
  `touch #{LOCK_FILE}`
end

init if !FileTest.exist?(LOCK_FILE)

get '/' do
  cross_origin
  "Nothing to see here."
end

# receive post-edit, send translation
get '/next' do
  cross_origin
  return "locked" if $lock
  $lock = true
  key = params[:key] # FIXME: do something with it
  if params[:example]
    source, reference = params[:example].strip.split(" ||| ")
    # tokenize, lowercase
    $db['post_edits_raw'] << reference.strip
    $env[:tokenizer][:socket].send reference
      STDERR.write "[tokenizer] waiting ...\n"
    reference = $env[:tokenizer][:socket].recv.force_encoding("UTF-8").strip
      STDERR.write "[tokenizer] < received tokenized reference: '#{reference}'\n"
    reference.downcase!
    # save post-edits
    $db['post_edits'] << reference.strip
    # update weights
    grammar = "#{WORK_DIR}/g/#{Digest::SHA256.hexdigest(source)}.grammar"
    annotated_source = "<seg grammar=\"#{grammar}\"> #{source} </seg>"
    msg = "#{annotated_source} ||| #{reference}"
      STDERR.write "[dtrain] > sending '#{msg}' for update\n"
    $env[:dtrain][:socket].send msg
      STDERR.write "[dtrain] waiting for confirmation ...\n"
      STDERR.write "[dtrain] < says it's #{$env[:dtrain][:socket].recv}\n"
    # update grammar extractor
    # get forward alignment
    msg = "#{source} ||| #{reference}"
      STDERR.write "[aligner_fwd] > sending '#{msg}' for forced alignment\n"
    $env[:aligner_fwd][:socket].send msg
      STDERR.write "[aligner_fwd] waiting for alignment ...\n"
    a_fwd = $env[:aligner_fwd][:socket].recv.strip
      STDERR.write "[aligner_fwd] < got alignment: '#{a_fwd}'\n"
    # get backward alignment
    msg = "#{source} ||| #{reference}"
      STDERR.write "[aligner_back] > sending '#{msg}' for forced alignment\n"
    $env[:aligner_back][:socket].send msg
      STDERR.write "[aligner_back] waiting for alignment ...\n"
    a_back = $env[:aligner_back][:socket].recv.strip
      STDERR.write "[aligner_back] < got alignment: '#{a_back}'\n"
    # symmetrize alignment
    msg = "#{a_fwd} ||| #{a_back}"
      STDERR.write "[atools] > sending '#{msg}' to combine alignments\n"
    $env[:atools][:socket].send msg
      STDERR.write "[atools] waiting for alignment ...\n"
    a = $env[:atools][:socket].recv.strip
      STDERR.write "[atools] < got alignment '#{a}'\n"
    # actual extractor
    msg = "TEST ||| #{source} ||| #{reference} ||| #{a}"
      STDERR.write "[extractor] > sending '#{msg}' for learning\n"
    $env[:extractor][:socket].send "TEST ||| #{source} ||| #{reference} ||| #{a}"
      STDERR.write "[extractor] waiting for confirmation ...\n"
      STDERR.write "[extractor] < got '#{$env[:extractor][:socket].recv}'\n"
    update_database
  end
  source     = $db['source_segments'][$db['progress']]
  raw_source = $db['raw_source_segments'][$db['progress']]
  if !source # input is done -> displays 'Thank you!'
    STDERR.write ">>> end of input, sending 'fi'\n"
    $lock = false
    return "fi"
  elsif !$confirmed
    $lock = false
    return $last_reply
  else # translate next sentence
    source.strip!
    # generate grammar for current sentence
    grammar = "#{WORK_DIR}/g/#{Digest::SHA256.hexdigest(source)}.grammar" # FIXME: keep grammars?
    msg = "- ||| #{source} ||| #{grammar}"                                # FIXME: content identifier useful?
      STDERR.write "[extractor] > asking to generate grammar: '#{msg}'\n"
    $env[:extractor][:socket].send msg
      STDERR.write "[extractor] waiting for confirmation ...\n"
      STDERR.write "[extractor] < says it generated #{$env[:extractor][:socket].recv.force_encoding("UTF-8").strip}\n"
    # translation
    msg = "act:translate ||| <seg grammar=\"#{grammar}\"> #{source} </seg>"
      STDERR.write "[dtrain] > asking to translate: '#{msg}'\n"
    $env[:dtrain][:socket].send msg
      STDERR.write "[dtrain] waiting for translation ...\n"
    transl = $env[:dtrain][:socket].recv.force_encoding "UTF-8"
      STDERR.write "[dtrain] < received translation: '#{transl}'\n"
    # detokenizer
    $env[:detokenizer][:socket].send transl
      STDERR.write "[detokenizer] waiting ...\n"
    transl = $env[:detokenizer][:socket].recv.force_encoding("UTF-8").strip
      STDERR.write "[detokenizer] < received final translation: '#{transl}'\n"
    # reply
    $last_reply = "#{$db['progress']}\t#{source}\t#{transl.strip}\t#{raw_source}"
    $lock = false
    $confirmed = false
    STDERR.write ">>> response: '#{$last_reply}'"
    return $last_reply
  end

  return "oh oh" # FIXME: do something sensible
end

# client confirms received translation
get '/confirm' do
  cross_origin
  STDERR.write "confirmed = #{$confirmed}\n"
  $confirmed = true

  return "#{$confirmed}"
end

# stop daemons and shut down server
get '/shutdown' do
  stop_all_daemons

  "ready to shutdown"
end

# reset current session
get '/reset' do
  return "locked" if $lock
  $db = JSON.parse ReadFile.read DB_FILE # FIXME: database ..
  $db['post_edits'].clear
  $db['post_edits_raw'].clear
  update_database
  $db['progress'] = 0
  $confirmed = true

  return "#{$db.to_s}"
end

# load other db file than configured
get '/load/:name' do
  return "locked" if $lock
  $db = JSON.parse ReadFile.read "/fast_scratch/simianer/lfpe/example_pattr/#{params[:name]}.json.original"
  $db['post_edits'].clear
  $db['post_edits_raw'].clear
  update_database
  $db['progress'] = 0
  $confirmed = true

  "#{$db.to_s}"
end

