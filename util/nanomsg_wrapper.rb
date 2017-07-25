#!/usr/bin/env ruby

require 'nanomsg'
require 'open3'
require 'trollop'

conf = Trollop::options do
  opt :action,         "tokenize,  detokenize, truecase, lowercase, [de-]bpe", :short => "-a", :type => :string, :required => true
  opt :addr,           "socket address",                    :short => "-S", :type => :string, :required => true
  opt :ext,            "path to externals",                 :short => "-e", :type => :string, :required => true
  opt :lang,           "language",                          :short => "-l", :type => :string
  opt :truecase_model, "model file for truecaser",          :short => "-t", :type => :string
  opt :bpe,            "codes",                             :short => "-b", :type => :string
  opt :bpe_vocab,      "BPE vocab",                         :short => "-B", :type => :string
end

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
elsif conf[:action] == "bpe"
  cmd = "#{conf[:ext]}/apply_bpe.py -c #{conf[:bpe]}" # --vocabulary #{conf[:bpe_vocab]} --vocabulary-threshold 1"
elsif conf[:action] == "de-bpe"
  cmd = "#{conf[:ext]}/de-bpe"
else
  STDERR.write "[wrapper] Unknown action #{conf[:action]}, exiting!\n"; exit
end
STDERR.write "[wrapper] will run cmd '#{cmd}'\n"

sock = NanoMsg::PairSocket.new
STDERR.write "[wrapper] addr: #{conf[:addr]}\n"
sock.bind conf[:addr]
sock.send "hello"
STDERR.write "[wrapper] sent hello\n"

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

