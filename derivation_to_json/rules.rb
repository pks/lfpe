#!/usr/bin/env ruby

require 'zipf'

src = ['Synergistische', 'pharmazeutische Zusammensetzung enthaltend', 'ein Peptid', 'mit 2 bis 5', 'Aminosaeuren']
target = ["A", "synergistic", "pharmaceutical composition containing", "a peptide", "with 2 to 5", "amino acis"]
align = [[1], [2], [0,3], [4], [5]]


def single_nt a
  r = []
  r << a
  max_sz = a.size-2
  if max_sz<0
    return r
  end
  a.each_index { |i|
    b = Array.new a
    b[i] = "[X]"
    r << b
    c = Array.new b
    (1).upto(a.size-(i+1)) { |k|
      c = Array.new c
      c.delete_at(i+1)
      break if c.size<2
      r << c
    }
  }

  return r
end

src.each_with_index { |i,j|
  src[j..src.size-1].each_with_index { |k,l|
    sub = src[j..(j+l)]
    r = single_nt sub
    r.each { |i|
      puts i.to_s
    }
  }
}

