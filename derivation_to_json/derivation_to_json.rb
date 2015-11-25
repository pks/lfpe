#!/usr/bin/env ruby

require 'zipf'
require 'stringio'

class RuleAndSpan
  attr_accessor :span, :symbol, :source, :target, :subspans, :done, :id, :trule

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

  def match_with_rule r
    if @source.join(" ").gsub(/\[\d+\]/, "[X]")==r.f \
    && @target.join(" ").gsub(/\[\d+\]/, "[X]")==r.e
      return true
    end

    return false
  end
end

class Rule
  attr_accessor :nt, :f, :e, :v, :a, :ha, :source_groups, :target_groups, :raw_rule_str

  def initialize s
    @raw_rule_str = s.strip
    splitpipe(s).each_with_index { |i,j|
      i = i.strip.lstrip
      if j == 0 # NT
        @nt = i
      elsif j == 1 # french
        @f = i.gsub(/\[\d+\]/, "[X]")
        @fa = @f.split
        @source_groups = @f.split("[X]").map{|i|i.strip.lstrip}
        @source_groups.reject! { |i| i=="" }
      elsif j == 2 # english
        @e = i.gsub(/\[\d+\]/, "[X]")
        @ea = @e.split
        @target_groups = @e.split("[X]").map{|i|i.strip.lstrip}
        @target_groups.reject! { |i| i=="" }
      elsif j == 3 # vector
        @v = i
      elsif j == 4 # alignment
        @a = i
        @ha = {}
        @a.split.each { |i|
          x,y = i.split("-")
          x = x.to_i
          y = y.to_i
          rx = 0
          (0).upto(x-1) { |k|
            if @fa[k].match /\[X\]/
              rx += 1
            end
          }
          ry = 0
          (0).upto(y-1) { |k|
            if @ea[k].match /\[X\]/
              ry += 1
            end
          }
          x -= rx
          y -= ry
          if @ha[x]
            @ha[x] << y
          else
            @ha[x] = [y]
          end
        }
      else # error
      end
    }
  end

  def group_has_link ngroup_source, ngroup_target
    offset_source = 0
    (0).upto(ngroup_source-1) { |i|
      offset_source += @source_groups[i].split.size
    }
    offset_target = 0
    (0).upto(ngroup_target-1) { |i|
      offset_target += @target_groups[i].split.size
    }
    (offset_source).upto(-1+offset_source+@source_groups[ngroup_source].split.size) { |i|
      next if !@ha[i]
      @ha[i].each { |k|
        if (offset_target..(-1+offset_target+@target_groups[ngroup_target].split.size)).include? k
          return true
        end
      }
    }

    return false
  end

  def to_s
    #"#{@nt} ||| #{@f} ||| #{@e} ||| #{@v} ||| #{@a}\n"
    "#{raw_rule_str}"
  end
end

def conv_cdec_show_deriv s
  rules = []
  xx = StringIO.new s
  d_s = xx.gets
  while line = xx.gets
    r = Rule.new(line)
    rules << r
  end

  a = d_s.split("}").map { |i|
    i.gsub /^[()\s]*/, ""
  }.reject { |i|
    i.size==0 }.map { |i|
      i.gsub /^\{/, ""
  }

  return a, rules
end

def derive span, by_span, o, groups, source
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
      _ = derive by_span[span.subspans[idx]], by_span, o, groups, source
      (k+1).upto(a.size-1) { |i|
        if !a[i].match(/\[(\d+)\]/) && groups.last.size>0
          groups << []
        end
      }
    else
      groups.last << ["#{w}", span.id, span.trule]
      o << w
    end
  }
  span.done = true
end

def proc_deriv s
  a, rules = conv_cdec_show_deriv s

  by_span = {}
  spans = []
  id = 0
  a.each { |line|
    rs = RuleAndSpan.new line, id
    rules.each { |r|
      if rs.match_with_rule r
        rs.trule = r
      end
    }
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

  so = []
  source_groups = []
  spans.each { |span|
    next if by_span[span].done
    derive by_span[span], by_span, so, source_groups, true
  }

  spans.each { |s| by_span[s].done = false }

  o = []
  groups = []
  spans.each { |span|
    next if by_span[span].done
    derive by_span[span], by_span, o, groups, false
  }

  source_rgroups = []
  rgroups = []
  source_groups.each { |i| source_rgroups << i.first[1] }
  groups.each { |i| rgroups << i.first[1] }
  rules_by_span_id = {}
  source_groups.each { |i|
    rules_by_span_id[i.first[1]] = i.first[2]
  }

  # make/fake phrase alignment
  phrase_align = []
  count_source = {}
  count_target = {}
  count_source.default = 0
  count_target.default = 0
  source_rgroups.each_with_index { |i|
    phrase_align << []
    rgroups.each_with_index { |j,k|
      if i==j
        if rules_by_span_id[i].group_has_link count_source[i], count_target[j]
          phrase_align.last << k
        end
        count_target[j] += 1
      end
    }
    count_source[i] += 1
    count_target.clear
  }

  # find non-aligned target
  rgroups.each_with_index { |i,j|
    if !phrase_align.flatten.index(j)
      add_to = []
      phrase_align.each_with_index { |a,k|
        a.each { |q|
          if rgroups[q]==i
            add_to << k
          end
        }
      }
      add_to.each { |k|
        phrase_align[k] << j
      }
    end
  }

  # find non-aligned source
  phrase_align.each_with_index { |i,j|
    add = []
    if i.size == 0
      x = source_rgroups[j]
      rgroups.each_with_index { |j,k|
        if j==x
          add << k
        end
      }
    end
    add.each { |k|
      phrase_align[j] << k
    }
  }

  # span info
  span_info = {}
  span2id = {}
  by_span.each { |k,v|
    span_info[v.id] = [k, v.subspans]
    span2id[k] = v.id
  }

  # final object
  h = {}
  h[:phrase_alignment] =  phrase_align
  h[:source_rgroups] = source_rgroups
  h[:target_rgroups] = rgroups
  h[:rules_by_span_id] = rules_by_span_id
  h[:source_groups] = source_groups.map { |a| a.map { |i| i.first }.join " " }
  h[:target_groups] = groups.map { |a| a.map { |i| i.first }.join " " }
  h[:span_info] = span_info
  h[:span2id] = span2id

  return h.to_json
end

if __FILE__ == $0
  s = ""
  while line = STDIN.gets
    s += line
  end
  json = proc_deriv(s)
  obj = JSON.parse(json)
  STDERR.write "#{json}\n"
  puts obj["source_groups"].join " "
  puts obj["target_groups"].join " "
end

