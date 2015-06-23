#!/usr/bin/env ruby

require 'nanomsg'
require 'open3'
require 'trollop'

conf = Trollop::options do
  opt :action, "tokenize (T) or detokenize (D)", :type => :string, :requred => true
  opt :addr, "socket address", :short => "-S", :type => :string, :required => true
  opt :scripts, "path to scripts directory", :short => "-p", :type => :string, :required => true
  opt :lang, "language", :short => "-l", :type => :string, :required => true
end

sock = NanoMsg::PairSocket.new
sock.bind conf[:addr]
sock.send "hello"

if conf[:action] == "D"
  cmd = "#{conf[:scripts]}/detokenizer.perl -q -b -u -l #{conf[:lang]}"
elsif conf[:action] == "T"
  cmd = "#{conf[:scripts]}/tokenizer-no-escape.perl -q -b -a -l #{conf[:lang]}"
else
  # ERROR
end
while true
  inp = sock.recv
  break if !inp||inp=="shutdown"
  Open3.popen3(cmd) do |pin, pout, perr|
    pin.write inp
    pin.close
    sock.send pout.gets.strip
  end
end

sock.send "off"

