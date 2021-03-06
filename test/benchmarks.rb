require 'list_matcher'
require 'benchmark/ips'
require 'set'

size = 100
magnitudes = 3
creation_iterations = 1000

def words(n, char_range, size_range, avoid=Set.new)
  set = Set.new
  while set.size < n do
    w = (1..rand(size_range)).map{ rand(char_range).chr }.join
    next if avoid.include? w
    set << w
  end
  set.to_a
end

def simple_rx(words)
  rx = words.join "|"
  Regexp.new "\\A(?>#{rx})\\z"
end

def list_rx(words)
  List::Matcher.rx words, bound: :string
end

puts "RANDOM WORDS, VARIABLE LENGTH\n"

magnitudes.times do
  good = words size, 97..122, 10..15
  bad  = words size, 97..122, 10..15, good
  set = Set[*good]
  rx  = simple_rx good
  lrx = list_rx good
  puts "\nnumber of words: #{size}"
  Benchmark.ips do |bm|
    bm.report('simple rx good') do
      good.each{ |w| rx === w }
    end
    bm.report('List::Matcher good') do
      good.each{ |w| lrx === w }
    end
    bm.report('set good') do
      good.each{ |w| set.include? w }
    end
    bm.report('list good') do
      good.each{ |w| good.include? w }
    end
    bm.compare!
  end
  Benchmark.ips do |bm|
    bm.report('simple rx bad') do
      bad.each{ |w| rx === w }
    end
    bm.report('List::Matcher bad') do
      bad.each{ |w| lrx === w }
    end
    bm.report('set bad') do
      bad.each{ |w| set.include? w }
    end
    bm.report('list bad') do
      bad.each{ |w| good.include? w }
    end
    bm.compare!
  end
  size *= 10
end

def nums(length)
  variants length, 0..9
end

def alphas(length)
  variants length, 'a'..'j'
end

def variants(length, range)
  out = []
  range = range.to_a
  tumblers = Array.new length, 0
  (range.size ** length).times do
    out << tumblers.map{ |t| range[t] }.join
    tumblers[0] += 1
    tumblers[0] %= range.size
    (0...length-1).each do |i|
      if tumblers[i] == 0
        tumblers[i + 1] += 1
        tumblers[i + 1] %= range.size
      else
        break
      end
    end
  end
  out
end

puts "\nFIXED LENGTH, FULL RANGE\n"

(1..4).each do |i|
  good = nums i
  bad  = alphas i
  lrx = list_rx good
  set = Set[*good]
  rx  = simple_rx good
  puts "\nnumber of words: #{10 ** i}; List::Matcher rx: #{lrx}"
  Benchmark.ips do |bm|
    bm.report('simple rx creation') do
      creation_iterations.times{ simple_rx good }
    end
    bm.report('List::Matcher creation') do
      creation_iterations.times{ simple_rx good }
    end
    bm.report('set creation') do
      creation_iterations.times{ Set[*good] }
    end
    bm.compare!
  end
  Benchmark.ips do |bm|
    bm.report('simple rx good') do
      good.each{ |w| rx === w }
    end
    bm.report('List::Matcher good') do
      good.each{ |w| lrx === w }
    end
    bm.report('set good') do
      good.each{ |w| set.include? w }
    end
    bm.report('list good') do
      good.each{ |w| good.include? w }
    end
    bm.compare!
  end
  Benchmark.ips do |bm|
    bm.report('simple rx bad') do
      bad.each{ |w| rx === w }
    end
    bm.report('List::Matcher bad') do
      bad.each{ |w| lrx === w }
    end
    bm.report('set bad') do
      bad.each{ |w| set.include? w }
    end
    bm.report('list bad') do
      bad.each{ |w| good.include? w }
    end
    bm.compare!
  end
  size *= 10
end
