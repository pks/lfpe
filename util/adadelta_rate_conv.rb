#!/usr/bin/env ruby

require 'zipf'

updates = SparseVector.new
ReadFile.readlines_strip(ARGV[0]).each { |line|
  k,v = line.split
  updates[k] = v.to_f
}
grads = SparseVector.new
ReadFile.readlines_strip(ARGV[1]).each { |line|
  k,v = line.split
  grads[k] = v.to_f
}

smooth = 0.000001

ks = updates.keys + grads.keys

rates = SparseVector.new
ks.each { |k|
  rates[k] = Math.sqrt(updates[k]+smooth)/Math.sqrt(grads[k]+smooth)
}

rates.each { |k,v|
  puts "#{k} #{v}"
}

