#!/usr/bin/env ruby

require 'nanomsg'
require 'open3'
require 'trollop'

conf = Trollop::options do
  opt :addr, "socket address", :short => "-S", :type => :string, :required => true
  opt :moses, "path to moses directory", :short => "-m", :type => :string, :required => true
  opt :model, "model file", :short => "-n", :type => :string, :required => true
end

sock = NanoMsg::PairSocket.new
sock.bind conf[:addr]
sock.send "hello"

cmd = "#{conf[:moses]}/scripts/recaser/truecase.perl -b --model #{conf[:model]}"
while true
  inp = sock.recv + " " # FIXME?
  break if !inp||inp=="shutdown"
  Open3.popen3(cmd) do |pin, pout, perr|
    pin.write inp
    pin.close
    s = pout.gets.strip
    sock.send s #pout.gets.strip
  end
end

sock.send "off"

