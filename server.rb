#!/usr/bin/env ruby

require 'sinatra'
require 'sinatra/cross_origin'
require 'nanomsg'
require 'zipf'

set :bind, '0.0.0.0'
set :port, 31337

set :allow_origin, :any
set :allow_methods, [:get, :post, :options]
set :allow_credentials, true
set :max_age, "1728000"
set :expose_headers, ['Content-Type']

sock = NanoMsg::PairSocket.new
addr = "ipc:///tmp/dtrain.ipc"
sock.bind addr

input = ReadFile.readlines_strip "model/src.gz"
input_ = Array.new input

get '/' do
  cross_origin
  "Nothing to see here."
end

get '/next' do
  cross_origin
  if params[:example]
    sock.send params[:example].strip
    puts params.to_s
    sock.recv # dummy
  end
  src = input.shift
  if !src
    puts "end of input, sending 'fi'"
    "fi"
  else
    puts "sending source '#{src}' ..."
    sock.send "act:translate ||| #{src}"
    puts "done"
    sleep 1
    puts "waiting for translation ..."
    t = sock.recv
    puts "got translation '#{t}'"
    "#{src}\t#{t}"
  end
end

get '/reset' do
  cross_origin
  input = Array.new input_
  "done"
end

