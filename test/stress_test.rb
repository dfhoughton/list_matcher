require "minitest/autorun"

require "list_matcher"

class StressTest < Minitest::Test
  def test_simple
    (1..10).each{ basic_test 5000, 97..122, 4..8 }
  end

  def test_fixed_size
    (1..10).each{ basic_test 5000, 97..122, 8..8 }
  end

  def test_really_big
    basic_test 50000, 97..122, 4..8
  end

  def basic_test(n, range, max)
    words = words n, range, max
    good = words[0...n/10]
    bad = words[n/10..-1]
    rx = Regexp.new List::Matcher.pattern( good, bound: true )
    puts good.inspect unless good.all?{ |w| rx === w }
    good.each do |w|
      assert rx === w, "#{w} is good for #{rx}"
    end
    bad.each do |w|
      assert !( rx === w ), "#{w} is bad for #{rx}"
    end
  end

  def words(n, range, max)
    words = []
    while words.size < n
      words += (1..n/10).map{ random_word range, max }
      words.uniq!
    end
    words[0...n]
  end

  def random_word(range, max)
    (1..rand(max)).map{ rand(range).chr }.join
  end
end