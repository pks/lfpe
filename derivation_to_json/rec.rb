#!/usr/bin/env ruby

require 'json'
require 'zipf'


before = JSON.parse(ReadFile.read('in7.json'))
after = JSON.parse(ReadFile.read('out7.json'))

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

def get_target_phrases_for_source_span before, after, alignment, v, dontsort=false
  a = []
  tgt = []
  target_phrases = [] # alignment seen from target
  v.each { |i|
    a << after["source"][i]
    target_phrases << alignment[i].first if alignment[i]
  }
  target_phrases.sort! if !dontsort
  target_phrases.each { |j|
    tgt << after["target"][j]
  }

  return a, tgt, target_phrases
end


# k is a rule id in after['rules_by_span_id']
srg2idx.each_pair { |k,v|
  a, tgt, target_phrases = get_target_phrases_for_source_span before, after, alignment, v
  rule_before = before['rules_by_span_id'][k.to_s]
  src_side_before = splitpipe(rule_before)[1]
  x = src_side_before.split
  a.first.insert(0, " [X] ") if x[0] == "[X]"
  a[a.size-1] += " [X] " if x[x.size-1] == "[X]"
  puts rule_before
  puts "#{k} #{a.join " [X] "}"
  puts tgt.to_s
  puts before["span_info"][k.to_s].to_s
  puts "target phrases #{target_phrases}"
  s = ""
  target_phrases.uniq.each { |j| s += after["target"][j]+" " }
  puts "S: #{s}"
  puts "nothing to do" if before["span_info"][k.to_s][1].size==0
  target_phrase_sub = []
  before["span_info"][k.to_s][1].each { |subspan|
    puts subspan.to_s
    subid = before["span2id"][subspan.to_s]
    puts "subid #{subid}"
    puts "XXX #{srg2idx[subid]}"
    _, _, tp = get_target_phrases_for_source_span before, after, alignment, srg2idx[subid], true
    target_phrase_sub << tp
  }
  puts "targ ph sub #{target_phrase_sub.to_s}"
  puts "---"
  puts
}

