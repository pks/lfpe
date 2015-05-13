#!/usr/bin/env ruby

require 'sinatra'
require 'sinatra/cross_origin'
require 'nanomsg'
require 'zipf'
require 'digest'

require_relative "#{ARGV[0]}"
INPUT = ReadFile.readlines INPUT_FILE
`mkdir -p #{WORK_DIR}/g`

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

def stop_all_daemons env
  STDERR.write "shutting down all daemons\n"
  env.each { |name,p|
    p[:socket].send "shutdown"
    STDERR.write "< #{name} is #{p[:socket].recv}\n"
  }
end

daemons = {
  :extractor    => "python -m cdec.sa.extract -c #{DATA_DIR}/sa.ini --online -u -S '__ADDR__'",
  :aligner_fwd  => "#{CDEC_NET}/word-aligner/net_fa -f #{DATA_DIR}/a/forward.params -m #{FWD_MEAN_SRCLEN_MULT} -T #{FWD_TENSION} --sock_url '__ADDR__'",
  :aligner_back => "#{CDEC_NET}/word-aligner/net_fa -f #{DATA_DIR}/a/backward.params -m #{BACK_MEAN_SRCLEN_MULT} -T #{BACK_TENSION} --sock_url '__ADDR__'",
  :atools       => "#{CDEC_NET}/utils/atools_net -c grow-diag-final-and -S '__ADDR__'",
  :dtrain       => "#{CDEC_NET}/training/dtrain/dtrain_net_interface -c #{DATA_DIR}/dtrain.ini -o #{WORK_DIR}/weights.final -a '__ADDR__'" ##{DTRAIN_EXTRA}"
}

env = {}
port = BEGIN_PORT_RANGE
daemons.each { |name,cmd|
  sock, pid = start_daemon cmd, name, "tcp://127.0.0.1:#{port}"
  env[name] = { :socket => sock, :pid => pid }
  port += 1
}

set :bind, SERVER_IP
set :port, WEB_PORT
set :allow_origin, :any
set :allow_methods, [:get, :post, :options]
set :allow_credentials, true
set :max_age, "1728000"
set :expose_headers, ['Content-Type']

get '/' do
  cross_origin
  "Nothing to see here."
end

get '/next' do
  cross_origin
  if params[:example]
    source, reference = params[:example].strip.split(" ||| ")
    # update weights
    grammar = "#{WORK_DIR}/g/#{Digest::SHA256.hexdigest(source)}.grammar"
    annotated_source = "<seg grammar=\"#{grammar}\"> #{source} </seg>"
    msg = "#{annotated_source} ||| #{reference}"
      STDERR.write "[dtrain] > sending '#{msg}' for update\n"
    env[:dtrain][:socket].send msg
      STDERR.write "[dtrain] waiting for confirmation ...\n"
      STDERR.write "[dtrain] < says it's #{env[:dtrain][:socket].recv}\n"
    # update grammar extractor
    # get forward alignment
    msg = "#{source} ||| #{reference}"
      STDERR.write "[aligner_fwd] > sending '#{msg}' for forced alignment\n"
    env[:aligner_fwd][:socket].send msg
      STDERR.write "[aligner_fwd] waiting for alignment ...\n"
    a_fwd = env[:aligner_fwd][:socket].recv.strip
      STDERR.write "[aligner_fwd] < got alignment: '#{a_fwd}'\n"
    # get backward alignment
    msg = "#{source} ||| #{reference}"
      STDERR.write "[aligner_back] > sending '#{msg}' for forced alignment\n"
    env[:aligner_back][:socket].send msg
      STDERR.write "[aligner_back] waiting for alignment ...\n"
    a_back = env[:aligner_back][:socket].recv.strip
      STDERR.write "[aligner_back] < got alignment: '#{a_back}'\n"
    # combine alignments
    msg = "#{a_fwd} ||| #{a_back}"
      STDERR.write "[atools] > sending '#{msg}' to combine alignments\n"
    env[:atools][:socket].send msg
      STDERR.write "[atools] waiting for alignment ...\n"
    a = env[:atools][:socket].recv.strip
      STDERR.write "[atools] < got alignment '#{a}'\n"
    # actual extractor
    msg = "TEST ||| #{source} ||| #{reference} ||| #{a}"
      STDERR.write "[extractor] > sending '#{msg}' for learning\n"
    env[:extractor][:socket].send "TEST ||| #{source} ||| #{reference} ||| #{a}"
      STDERR.write "[extractor] waiting for confirmation ...\n"
      STDERR.write "[extractor] < got '#{env[:extractor][:socket].recv}'\n"
  end
  source = INPUT.shift
  if !source # input is done -> displays 'Thank you!'
    STDERR.write ">>> end of input, sending 'fi'\n"
    "fi"
  else # translate next sentence
    source.strip!
    # generate grammar for current sentence
    grammar = "#{WORK_DIR}/g/#{Digest::SHA256.hexdigest(source)}.grammar" # FIXME: keep grammars?
    msg = "- ||| #{source} ||| #{grammar}"                                # FIXME: content identifier useful?
      STDERR.write "[extractor] > asking to generate grammar: '#{msg}'\n"
    env[:extractor][:socket].send msg
      STDERR.write "[extractor] waiting for confirmation ...\n"
      STDERR.write "[extractor] < says it generated #{env[:extractor][:socket].recv.strip}\n"
    # translation
    msg = "act:translate ||| <seg grammar=\"#{grammar}\"> #{source} </seg>"
      STDERR.write "[dtrain] > asking to translate: '#{msg}'\n"
    env[:dtrain][:socket].send msg
      STDERR.write "[dtrain] waiting for translation ...\n"
    transl = env[:dtrain][:socket].recv.encode "UTF-8"
      STDERR.write "[dtrain] < received translation: '#{transl}'\n"
    "#{source}\t#{transl}"
  end
end

# stop daemons and shut down server
get '/shutdown' do
  stop_all_daemons env
  exit
end

