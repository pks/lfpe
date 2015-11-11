#!/usr/bin/env ruby

require 'nanomsg'
require 'open3'
require 'trollop'

conf = Trollop::options do
  opt :action,         "tokenize,  detokenize, truecase, or lowercase", :short => "-a", :type => :string, :required => true
  opt :addr,           "socket address",                    :short => "-S", :type => :string, :required => true
  opt :ext,            "path to externals",                 :short => "-e", :type => :string, :required => true
  opt :lang,           "language",                          :short => "-l", :type => :string
  opt :truecase_model, "model file for truecaser",          :short => "-t", :type => :string
end

sock = NanoMsg::PairSocket.new
sock.bind conf[:addr]
sock.send "hello"

if conf[:action] == "detokenize"
  cmd = "#{conf[:ext]}/detokenizer.perl -q -b -u -l #{conf[:lang]}"
  if !conf[:lang]
    STDERR.write "[detokenizer] No language given, exiting!\n"; exit
  end
elsif conf[:action] == "tokenize"
  cmd = "#{conf[:ext]}/tokenizer-no-escape.perl -q -b -l #{conf[:lang]}"
  if !conf[:lang]
    STDERR.write "[tokenizer] No language given, exiting!\n"; exit
  end
elsif conf[:action] == "truecase"
  cmd = "#{conf[:ext]}/truecase.perl -b --model #{conf[:truecase_model]}"
  if !conf[:truecase_model]
    STDERR.write "[truecaser] No model given for truecaser, exiting!\n"; exit
  end
elsif conf[:action] == "lowercase"
  cmd = "#{conf[:ext]}/lowercase.perl"
else
  STDERR.write "[wrapper] Unknown action #{conf[:action]}, exiting!\n"; exit
end
pin, pout, perr = Open3.popen3(cmd)
while true
  inp = sock.recv.strip
  break if !inp||inp=="shutdown"
  pin.write inp+"\n"
  sock.send pout.gets.strip
end

STDERR.write "[wrapper] shutting down\n"
pin.close; pout.close; perr.close
sock.send "off"
exit 0

