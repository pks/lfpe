#!/usr/bin/env ruby

require 'zipf'


module PhrasePhraseExtraction

DEBUG=true
MAX_NT=2 # chiang:2
MAX_SEED_NUM_WORDS=3 # chiang:10 words phrases!
MAX_SRC_SZ=3 # chiang:5 words phrases!
FORBID_SRC_ADJACENT_SRC_NT=true # chiang:true

class Rule
  attr_accessor :source, :target, :arity, :source_context, :target_context, :alignment

  def initialize source_range=nil, target_range=nil, source_context=nil, target_context=nil, alignment=[]
    if source_context && target_range && source_context && target_context
      @source = [source_range]
      @target = [target_range]
      @source_context = source_context
      @target_context = target_context
      @alignment = alignment
    else
      @source = []
      @target = []
      @source_context = []
      @target_context = []
      @alignment = []
    end
    @arity = 0
  end

  def <=> other_rule
  end

  def hash
    self.as_trule_string.hash
  end

  def eql? other
    self.as_trule_string == other.as_trule_string
  end

  def len_src
    src_len = 0
    @source.each { |i|
      if i.is_a? String
        src_len += 1
      else
        src_len += i.last-i.first+1
      end
    }

    return src_len
  end

  def len_tgt
    tgt_len = 0
    @target.each { |i|
      if i.is_a? String
        tgt_len += 1
      else
        tgt_len += i.last-i.first+1
      end
    }

    return tgt_len
  end

  def len
    src_len = 0
    @source.each { |i|
      if i.is_a? String
        src_len += 1
      else
        src_len += i.last-i.first+1
      end
    }
    tgt_len = 0
    @target.each { |i|
      if i.is_a? String
        tgt_len += 1
      else
        tgt_len += i.last-i.first+1
      end
    }
    return [src_len, tgt_len]
  end

  def to_s
    source_string = ""
    @source.each { |i|
      if i.is_a? Range
        source_string += @source_context[i].to_s
      else
        source_string += " #{i} "
      end
    }
    target_string = ""
    @target.each { |i|
      if i.is_a? Range
        target_string += @target_context[i].to_s
      else
        target_string += " #{i} "
      end
    }

    astr = ""
    @alignment.each { |p|
      astr += " #{p.first}-#{p.last}"
    }
    astr.strip!

    return "#{source_string.gsub(/\s+/, " ").strip} -> #{target_string.gsub(/\s+/, " ").strip} | #{astr}"
  end

  def base_alignment
    min_src = @alignment.map{|p| p.first }.min
    min_tgt = @alignment.map{|p| p.last }.min
    @alignment.each_with_index { |p,j|
      @alignment[j] = [p.first-min_src, p.last-min_tgt]
    }
  end

  def base_alignment2 correct_src, correct_tgt, start_source, start_target
    @alignment.each_with_index { |p,j|
      if p[0] > start_source
        @alignment[j][0] = [0,p.first-correct_src].max
      end
      if p[1] > start_target
        @alignment[j][1] = [0,p.last-correct_tgt].max
      end
    }
  end

  def as_trule_string
    source_string = ""
    @source.each { |i|
      if i.is_a? Range
        source_string += @source_context[i].join(" ").strip
      else
        source_string += " #{i} "
      end
    }
    target_string = ""
    @target.each { |i|
      if i.is_a? Range
        target_string += @target_context[i].join(" ").strip
      else
        target_string += " #{i} "
      end
    }
    source_string = source_string.lstrip.strip
    target_string = target_string.lstrip.strip

    astr = ""
    @alignment.each { |p|
      astr += " #{p.first}-#{p.last}"
    }
    astr.strip!

    #source_string.gsub!(/\[X,\d+\]/, "[X]")
    return "[X] ||| #{source_string} ||| #{target_string} ||| NewRule=1 ||| #{astr}"
  end

  def is_terminal?
    #return false if @source.size>1
    #return false if @target.size>1
    @source.each { |i| return false if !i.is_a? Range }
    @target.each { |i| return false if !i.is_a? Range }
    return true
  end

  # check if other_rule is a part of self
  def mergeable_with? other_rule
    return false if !other_rule.is_terminal?
    other_source_begin = other_rule.source.first.first
    other_source_end   = other_rule.source.first.last
    other_target_begin = other_rule.target.first.first
    other_target_end   = other_rule.target.first.last
    b = false
    @source.each { |i|
      next if !i.is_a? Range
      if (   other_source_begin >= i.first \
          && other_source_end   <= i.last  \
          && (!(other_source_begin==i.first && other_source_end==i.last)))
        b = true
        break
      end
    }
    return false if !b
    @target.each { |i|
      next if !i.is_a? Range
      if (   other_target_begin >= i.first \
          && other_target_end   <= i.last  \
          && (!(other_target_begin==i.first && other_target_end==i.last)))
        b = true
        break
      end
    }

    return b
  end

  def self.split a, b, index=0, p="target"
    return "[NEWX,#{index}]"if (a==b)

    aa = a.to_a
    begin_split = b.first
    end_split   = b.last

    p1 = aa[0..aa.index([begin_split-1,aa.first].max)]
    p2 = aa[aa.index([end_split+1, aa.last].min)..aa.last]

    nt = "[NEWX,#{index}]"

    ret = nil
    if begin_split > a.first && end_split < a.last
      ret = [(p1.first..p1.last), nt, (p2.first..p2.last)]
    elsif begin_split == a.first
      ret = [nt, (p2.first..p2.last)]
    elsif end_split == a.last
      ret = [(p1.first..p1.last), nt]
    end

    return ret
  end

  def self.merge r, s
    return nil if !r.mergeable_with? s
    return nil if !s.is_terminal?

    other_source_begin = s.source.first.first
    other_source_end   = s.source.first.last
    other_target_begin = s.target.first.first
    other_target_end   = s.target.first.last

    new_rule = Rule.new
    new_rule.source_context = r.source_context
    new_rule.target_context = r.target_context
    new_rule.arity = r.arity+1
    new_rule.alignment = Array.new
    r.alignment.each { |p| new_rule.alignment << Array.new(p) } # deep copy

    c = new_rule.arity
    done = false
    correct_src = 0
    r.source.each_with_index { |i,j|
      if i.is_a? Range
        if (   !done \
            && other_source_begin >= i.first \
            && other_source_end   <= i.last)
          new_rule.source << Rule.split(i, (other_source_begin..other_source_end), c, "source")
          new_rule.source.flatten!
          done = true
        else
          new_rule.source << i
        end
      else
        new_rule.source << i
      end
    }
    # relabel Xs (linear)
    switch = false
    k = 1
    new_rule.source.each_with_index { |i,j|
      if i.is_a? String
        m = i.match(/\[(X|NEWX),(\d+)\]/)
        n = m[1]
        l = m[2].to_i
        if k != l
          switch = true
        end
        new_rule.source[j] = "[#{n},#{k}]"
        k += 1
      end
    }
    puts "switch #{switch}" if DEBUG
    done = false
    correct_tgt = 0
    r.target.each_with_index { |i,j|
      if i.is_a? Range
        if (   !done \
            && other_target_begin >= i.first \
            && other_target_end   <= i.last)
          new_rule.target << Rule.split(i, (other_target_begin..other_target_end), c)
          new_rule.target.flatten!
          done = true
        else
          new_rule.target << i
        end
      else
        new_rule.target << i
        reorder = true
      end
    }

    correct_src = r.len_src-new_rule.len_src
    correct_tgt = r.len_tgt-new_rule.len_tgt
    puts "correct_src #{correct_src}"
    puts "correct_tgt #{correct_tgt}"

    start_correct_source = nil
    j = 0
    fl = []
    new_rule.source.each { |i|
      if i.is_a? Range
        fl << new_rule.source_context[i]
      else
        if i.match(/\[NEWX,\d+\]/)
          puts "j = #{j}"
          start_correct_source = j
        end
        fl << i
      end
      j += 1
    }
    fl.flatten!

    start_correct_target = nil
    j = 0
    fl.each { |i|
      if i.match(/\[NEWX,\d+\]/)
        puts "j = #{j}"
        start_correct_source = j
        break
      end
      j += 1
    }

    el = []
    new_rule.target.each { |i|
      if i.is_a? Range
        el << new_rule.target_context[i]
      else
        el << i
      end
      j += 1
    }
    el.flatten!

    start_correct_target = nil
    j = 0
    el.each { |i|
      if i.match(/\[NEWX,\d+\]/)
        puts "j = #{j}"
        start_correct_target = j
        break
      end
      j += 1
    }

    puts "start_correct_source = #{start_correct_source}"
    puts "start_correct_target = #{start_correct_target}"

    new_rule.base_alignment2 correct_src, correct_tgt, start_correct_source, start_correct_target
    puts "not uniq #{new_rule.alignment.to_s}"
    new_rule.alignment.uniq!

    puts "a before: #{new_rule.alignment.to_s}"
    puts fl.to_s
    new_rule.alignment.reject! { |p|
      !fl[p.first] || !el[p.last] || fl[p.first].match(/\[(NEWX|X),\d+\]/) || el[p.last].match(/\[(NEWX|X),\d+\]/)
    }
    puts "a after: #{new_rule.alignment.to_s}"
    puts "old len_src #{r.len_src}"
    puts "new len_src #{new_rule.len_src}"
    puts "old len_tgt #{r.len_tgt}"
    puts "new len_tgt #{new_rule.len_tgt}"

    if switch
      new_rule.target.each_with_index { |i,j|
        if i.is_a? String
          m = i.match(/\[(X|NEWX),(\d+)\]/)
          n = m[1]
          k = m[2].to_i
          l = nil
          if k == 1
            l = 2
          else # 2
            l = 1
          end
          new_rule.target[j] = "[#{n},#{l}]"
        end
      }
    end

    new_rule.source.each_with_index { |i,j|
      if i.is_a?(String) && i.match(/\[NEWX,\d\]/)
        i.gsub!(/NEWX/, "X")
      end
    }
    new_rule.target.each_with_index { |i,j|
      if i.is_a?(String) && i.match(/\[NEWX,\d\]/)
        i.gsub!(/NEWX/, "X")
      end
    }

    return new_rule
  end

  def expand_fake_alignment
    new_alignment = []
    if DEBUG
      puts @alignment.to_s
      puts @source.to_s
      puts @target.to_s
    end
    fl = @source.map { |i|
      if i.is_a? Range
        @source_context[i].map{|x|x.split}
      else
        i
      end
    }.flatten 1
    el = @target.map { |i|
      if i.is_a? Range
        @target_context[i].map{|x|x.split}
      else
        i
      end
    }.flatten 1
    if DEBUG
      puts fl.to_s
      puts el.to_s
      puts "->"
    end

    offsets_src = {}
    #offsets_src.default = 0
    o = 0
    fl.each_with_index { |i,j|
      if i.is_a? Array
        o += i.size-1
      end
      offsets_src[j] = o
    }
    offsets_tgt = {}
    #offsets_tgt.default = 0
    o = 0
    el.each_with_index { |i,j|
      if i.is_a? Array
        o += i.size-1
      end
      offsets_tgt[j] = o
    }

    @alignment.each { |p|
      if DEBUG
        puts p.to_s
        puts "#{offsets_src[p.first]} -- #{offsets_tgt[p.last]}"
      end
      new_alignment << [ p.first+offsets_src[p.first], p.last+offsets_tgt[p.last] ]
      if DEBUG
        puts new_alignment.last.to_s
        puts "---"
        puts
      end
    }
    @alignment = new_alignment
  end

end

def PhrasePhraseExtraction.has_alignment a, i, dir="src"
  index = 0
  index = 1 if dir=="tgt"
  a.each { |p|
    return true if p[index]==i
  }
  return false
end

def PhrasePhraseExtraction.extract fstart, fend, estart, eend, f, e, a, flen, elen
  a.each { |p|
    fi=p[0]; ei=p[1]
    if (fstart..fend).include? fi
      if ei<estart || ei>eend
        return []
      end
    end
    if (estart..eend).include? ei
      if fi<fstart || fi>fend
        return []
      end
    end

  }
  rules = []
  fs = fstart
  loop do
    fe = fend
    loop do
      rules << Rule.new(fs..fe, estart..eend, f, e)
      a.each { |p|
        if (fs..fe).include?(p.first)
          rules.last.alignment << p
        end
      }
      rules.last.base_alignment
      fe += 1
      break if has_alignment(a, fe, "tgt")||fe>=elen
    end
    fs -= 1
    break has_alignment(a, fs, "src")||fs<0
  end

  return rules
end

def PhrasePhraseExtraction.make_gappy_rules rules, seed_rules
  MAX_NT.times {
    new_rules = []
    rules.each { |r|
      seed_rules.each { |s|
        if r.mergeable_with? s
          new = Rule.merge r, s
          new_rules << new
          puts "#{r.to_s} <<< #{s.to_s}" if DEBUG
          puts " = #{new.to_s}\n\n" if DEBUG
        end
      }
    }
    rules += new_rules
  }

  return rules
end

def PhrasePhraseExtraction.make_seed_rules a, e, f
  rules = []
  (0..e.size-1).each { |estart|
  (estart..e.size-1).each { |eend|

    fstart = f.size-1
    fend   = 0
    a.each { |p|
      fi=p[0]; ei=p[1]
      if estart<=ei && ei<=eend
        fstart = [fi, fstart].min
        fend   = [fi, fend].max
      end
    }
    next if fstart>fend
    puts "fstart #{fstart}, fend #{fend}, estart #{estart}, eend #{eend}" if DEBUG
    new_rules = extract fstart, fend, estart, eend, f, e, a, f.size, e.size
    new_rules.each { |r|
      puts r.to_s if DEBUG
    }
    rules += new_rules
  }
  }

  return rules
end

def PhrasePhraseExtraction.test
  # 0 1 2 3
  # a b c d
  # w x y z
  # 0-0
  # 1-3
  # 2-2
  # 3-1
  ra = Rule.new
  rb = Rule.new
  ra.source = [(0..2), "[X,1]"]
  ra.target = [(0..0), "[X,1]", (2..3)]
  ra.source_context = ["a", "b", "c", "d"]
  ra.target_context = ["w", "x", "y", "z"]
  ra.alignment = [[0,0],[1,3],[2,2]]
  ra.arity = 1
  rb.source = [(1..1)]
  rb.target = [(3..3)]
  rb.source_context = ["a", "b", "c", "d"]
  rb.target_context = ["w", "x", "y", "z"]
  rb.alignment = [[0,0]]
  rb.arity = 0

  puts ra.mergeable_with? rb
  nr = Rule.merge ra, rb
  puts ra.to_s
  puts rb.to_s
  puts nr.to_s
end

def PhrasePhraseExtraction.test_phrase
  ra = Rule.new
  rb = Rule.new
  ra.source = [(0..2), "[X,1]"]
  ra.target = [(0..0), "[X,1]", (2..3)]
  ra.source_context = ["a a", "b b", "c c", "d d"]
  ra.target_context = ["w w", "x x", "y y", "z z"]
  ra.alignment = [[0,0],[1,3],[2,2]]
  #ra.expand_fake_alignment
  ra.arity = 1
  rb.source = [(1..1)]
  rb.target = [(3..3)]
  rb.source_context = ra.source_context
  rb.target_context = rb.source_context
  rb.alignment = [[0,0]]
  #rb.expand_fake_alignment
  rb.arity = 0

  puts ra.mergeable_with? rb
  nr = Rule.merge ra, rb
  puts ra.to_s
  puts rb.to_s
  nr.expand_fake_alignment
  puts nr.to_s
end

def PhrasePhraseExtraction.test_phrase2
  source_context = ["a", "b", "c", "Blechbänder", ", besteht", "der Spreizdorn im wesentlichen", "aus", "x"]
  target_context = ["w", "x", "y", "the expansion", "mandrel consists", "essentially of expansion mandrel", "z"]

  ra = Rule.new
  ra.source = ["[X,1]", (3..6)]
  ra.target = ["[X,1]", (3..5)]
  ra.source_context = source_context
  ra.target_context = target_context
  ra.alignment = [[1,1],[2,2],[3,3],[4,2]]
  ra.arity = 1

  rb = Rule.new
  rb.source = [(4..6)]
  rb.target = [(4..5)]
  rb.source_context = source_context
  rb.target_context = target_context
  rb.alignment = [[0,0],[1,1],[2,0]]
  rb.arity = 0

  puts ra.mergeable_with? rb
  nr = Rule.merge ra, rb
  puts ra.to_s
  puts rb.to_s
  nr.expand_fake_alignment
  puts nr.to_s
end

def PhrasePhraseExtraction.extract_rules f, e, as, expand=false
  a = []
  as.each { |p|
    x,y = p.split "-"
    x = x.to_i; y = y.to_i
    a << [x,y]
  }
  rules = PhrasePhraseExtraction.make_seed_rules a, e,f
  seed_rules = PhrasePhraseExtraction.remove_too_large_seed_phrases rules
  rules = PhrasePhraseExtraction.make_gappy_rules rules, seed_rules

  if PhrasePhraseExtraction::FORBID_SRC_ADJACENT_SRC_NT
    rules = PhrasePhraseExtraction.remove_adj_nt rules
  end

  rules = PhrasePhraseExtraction.remove_too_long_src_sides rules

  if expand
    rules.each { |r| r.expand_fake_alignment }
  end

  return rules.uniq
end

def PhrasePhraseExtraction.remove_too_large_seed_phrases rules
  return rules.reject { |r|
    src_len, tgt_len = r.len
    src_len>PhrasePhraseExtraction::MAX_SEED_NUM_WORDS \
    || tgt_len>PhrasePhraseExtraction::MAX_SEED_NUM_WORDS }
end

def PhrasePhraseExtraction.remove_adj_nt rules
  return rules.reject { |r|
    b = false
    prev = false
    r.source.each { |i|
      if i.is_a? String
        if prev
          b = true
          break
        end
        prev = true
      else
        prev = false
      end
    }
    b
  }
end

def PhrasePhraseExtraction.remove_too_long_src_sides rules
  return rules.reject { |r|
    r.len.first > PhrasePhraseExtraction::MAX_SRC_SZ
  }
end

end # module

def main
  file = ReadFile.new ARGV[0]

  f = file.gets.split
  e = file.gets.split
  a = []
  file.gets.split.each { |p|
    x,y = p.split "-"
    x = x.to_i; y = y.to_i
    a << [x,y]
  }
  rules = PhrasePhraseExtraction.make_seed_rules a, e, f
  seed_rules = PhrasePhraseExtraction.remove_too_large_seed_phrases rules
  rules = PhrasePhraseExtraction.make_gappy_rules rules, seed_rules

  if PhrasePhraseExtraction::FORBID_SRC_ADJACENT_SRC_NT
    rules = PhrasePhraseExtraction.remove_adj_nt rules
  end

  rules = PhrasePhraseExtraction.remove_too_long_src_sides rules

  rules.uniq!

  rules.each { |r|
    puts r.as_trule_string
  }
end
#main

def test
  #PhrasePhraseExtraction.test
  #PhrasePhraseExtraction.test_phrase
  PhrasePhraseExtraction.test_phrase2
end
test

