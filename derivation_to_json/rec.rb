#!/usr/bin/env ruby

require 'json'
require 'zipf'


before = JSON.parse(ReadFile.read('x.json'))
after = JSON.parse(ReadFile.read('y.json'))

alignment = {}
after["align"].each { |i|
  a,b = i.split '-'
  a = a.to_i
  b = b.to_i
  if alignment[a]
    alignment[a] << b
  else
    alignment[a] = [b]
  end
}

srg2idx = {}
before['source_rgroups'].uniq.each { |k|
  srg2idx[k] = []
  before['source_rgroups'].each_with_index { |i,j|
    if i==k
      srg2idx[k] << j
    end
  } 
}

srg2idx.each_pair { |k,v|
  a = []
  tgt = []
  v.each { |i|
    a << after["source"][i]
    tgt << after["target"][alignment[i].first]
  }
  rule_before = before['rules_by_span_id'][k.to_s]
  src_side_before = splitpipe(rule_before)[1]
  x = src_side_before.split
  a.first.insert(0, " [X] ") if x[0] == "[X]"
  a[a.size-1] += " [X] " if x[x.size-1] == "[X]"
  puts rule_before
  puts "#{k} #{a.join " [X] "}"
  puts tgt.to_s
  puts "---"
  puts
}

