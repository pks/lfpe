#!/usr/bin/env ruby

require 'zipf'

def conv_cdec_show_deriv s
  s.gsub! /\(/, "\n"
  s.gsub! /[{}]/, ""
  a = s.split "\n"
  a.map! { |i|
    i.strip.gsub /(\s*\))+$/, ""
  }
  a.reject! { |i| i.strip=="" }
  return a
end

class RuleAndSpan
  attr_accessor :span, :symbol, :source, :target, :subspans, :done, :id

  def initialize s, id
    spans, srcs, tgts = splitpipe s.strip
    _,@symbol = spans.split
    @span = _.split(",", 2).map { |i| i.gsub(/[<>]/, "").to_i}
    @source = srcs.strip.split
    j = 0
    @source.map! { |i| if i.match(/\[X\]/) then "[#{j+=1}]"  else i end }
    @target = tgts.strip.split
    @subspans = []
    @done = false
    @id = id
  end

  def to_s
    return "#{@id}\t<#{@span.first},#{@span[1]}> [X] ||| #{@source.join " "} ||| #{@target.join " "}"
  end

  def is_terminal_rule?
    @source.each { |w|
      return true if !w.match(/\[S|(\d+)\]/)
    }

    return false
  end
end

def proc_deriv s
a = conv_cdec_show_deriv s

by_span = {}
spans = []
id = 0
a.each { |line|
  rs = RuleAndSpan.new line, id
  id += 1
  by_span[rs.span] = rs
  if rs.is_terminal_rule?
    spans << rs.span
  end
}

spans.reverse.each_with_index { |s,k|
  (spans.size-(k+2)).downto(0) { |l|
    t = spans[l]
    if s[0] >= t[0] and s[1] <= t[1]
      by_span[t].subspans << s
      break
    end
  }
}

# fix order
spans.each { |s|
  by_span[s].subspans.reverse!
}

def derive span, spans, by_span, o, groups, source
  if groups.size==0 || groups.last.size>0
    groups << []
  end
  a = nil
  if source
    a = span.source
  else
    a = span.target
  end
  a.each_with_index { |w,k|
    nt = w.match /\[(\d+)\]/
    if nt
      idx = nt.captures.first.to_i-1
      _ = derive by_span[span.subspans[idx]], spans, by_span, o, groups, source
      (k+1).upto(a.size-1) { |i|
        if !a[i].match(/\[(\d+)\]/) && groups.last.size>0
          groups << []
        end
      }
    else
      groups.last << ["#{w}", span.id]
      o << w
    end
  }
  span.done = true
end

so = []
source_groups = []
spans.each { |span|
  next if by_span[span].done
  derive by_span[span], spans, by_span, so, source_groups, true
}
#puts "SOURCE"
#puts so.join " "
#puts source_groups.to_s
#puts "##{source_groups.size}"

spans.each { |s| by_span[s].done = false }

o = []
groups = []
spans.each { |span|
  next if by_span[span].done
  derive by_span[span], spans, by_span, o, groups, false
}
#puts "TARGET"
#puts o.join " "
#puts groups.to_s
#puts "##{groups.size}"

source_rgroups = []
rgroups = []
source_groups.each { |i| source_rgroups << i.first[1] }
groups.each { |i| rgroups << i.first[1] }

phrase_align = []
source_rgroups.each { |i|
  phrase_align << []
  rgroups.each_with_index { |j,k|
    if i==j
      phrase_align.last << k
    end
  }
}

h = {}
h[:phrase_alignment] =  phrase_align
h[:source_groups] = source_groups.map { |a| a.map { |i| i.first }.join " " }
h[:target_groups] = groups.map { |a| a.map { |i| i.first }.join " " }

return h.to_json
end

puts proc_deriv STDIN.gets.strip

