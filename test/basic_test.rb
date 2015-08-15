require "minitest/autorun"

require "list_matcher"

class BasicTest < Minitest::Test

  def test_simple
    words = %w(cat dog camel)
    rx = List::Matcher.pattern words
    rx = Regexp.new rx
    words.each do |w|
      assert rx === w
    end
  end

  def test_word_chars
    word = (1..255).map(&:chr).select{ |c| /\w/ === c }
    chars = word + ['+']
    rx = List::Matcher.pattern chars
    assert_equal '[+\w]', rx
    rx = Regexp.new rx
    chars.each do |c|
      assert rx === c
    end
    chars = word + ['@']
    rx = List::Matcher.pattern chars
    assert_equal '[@\w]', rx
    rx = Regexp.new rx
    chars.each do |c|
      assert rx === c
    end
  end

  def test_word_chars_case_insensitive
    word = (1..255).map(&:chr).select{ |c| /\w/ === c }
    chars = word + ['+']
    rx = List::Matcher.pattern chars, case_insensitive: true
    assert_equal '(?i:[+\w])', rx
    rx = Regexp.new rx
    chars.each do |c|
      assert rx === c
    end
  end

  def test_num_chars
    words = (0..9).map(&:to_s)
    rx = List::Matcher.pattern words
    assert_equal '\d', rx
    rx = Regexp.new rx
    words.each do |w|
      assert rx === w
    end
  end

  def test_space_chars
    words = (1..255).map(&:chr).select{ |c| c =~ /\s/ }
    rx = List::Matcher.pattern words
    assert_equal '\s', rx
    rx = Regexp.new rx
    words.each do |w|
      assert rx === w
    end
  end

  def test_bounds
    words = %w(cat dog)
    rx = List::Matcher.pattern words, bound: true
    assert_equal '(?:\b(?:cat|dog)\b)', rx
    rx = Regexp.new rx
    words.each do |w|
      assert rx === w
    end
  end

  def test_repeats
    rx = List::Matcher.pattern %w(aaaaaaaaaa)
    assert_equal '(?:a{10})', rx
    rx = List::Matcher.pattern %w(bbbaaaaaaaaaabbbaaaaaaaaaa)
    assert_equal '(?:(?:bbba{10}){2})', rx
  end

  def test_opt_suffix
    words = %w(the them)
    rx = List::Matcher.pattern words
    assert_equal '(?:them?)', rx
    rx = Regexp.new rx
    words.each do |w|
      assert rx === w
    end
  end

  def test_opt_prefix
    words = %w(at cat)
    rx = List::Matcher.pattern words
    assert_equal '(?:c?at)', rx
    rx = Regexp.new rx
    words.each do |w|
      assert rx === w
    end
  end

  def test_symbols_string
    words = ['cat dog']
    rx = List::Matcher.pattern words, symbols: { ' ' => '\s++' }
    assert_equal '(?:cat\s++dog)', rx
    rx = Regexp.new rx
    words.each do |w|
      assert rx === w
    end
  end

  def test_symbols_rx
    words = %w(year year2000 year1999)
    rx = List::Matcher.pattern words, symbols: { /(?<!\d)\d{4}(?!\d)/ => nil }
    assert_equal '(?:year(?-mix:(?<!\d)\d{4}(?!\d))?)', rx
    rx = Regexp.new rx
    words.each do |w|
      assert rx === w
    end
  end

  def test_fancy_rx
    words = ['   cat   dog  ']
    good = ['the cat  dog is an odd beast']
    bad = ['the catdog is an odd beast', 'the cat doggy is an odd beast', 'the scat dog is an odd beast']
    rx = List::Matcher.pattern words, bound: true, normalize_whitespace: true
    assert_equal '(?:\bcat\s++dog\b)', rx
    rx = Regexp.new rx
    assert good.all?{ |w| rx === w }, 'not bothered by odd space'
    assert bad.none?{ |w| rx === w }, 'needs interior space and boundaries'
  end

  def test_symbols_borders
    words = (1..31).to_a
    rx = List::Matcher.pattern words, bound: { test: /\d/, left: '(?<!\d)', right: '(?!\d)' }
    rx = Regexp.new rx
    good = words.map{ |n| "a#{n}b" }
    bad = words.map{ |n| "0#{n}0" }
    assert good.all?{ |w| rx === w }
    assert bad.none?{ |w| rx === w }
  end

  def test_string_bound
    rx = List::Matcher.pattern ['cat'], bound: :string
    assert_equal '(?:\Acat\z)', rx
    rx = Regexp.new rx
    assert rx === 'cat', 'matches whole string'
    assert "cat\ndog" !~ rx, 'line breaks do not suffice'
    assert ' cat ' !~ rx, 'word boundaries do not suffice'
  end

  def test_line_bound
    rx = List::Matcher.pattern ['cat'], bound: :line
    assert_equal '(?:^cat$)', rx
    rx = Regexp.new rx
    assert rx === 'cat', 'matches whole string'
    assert rx === "cat\ndog", 'line breaks suffice'
    assert ' cat ' !~ rx, 'word boundaries do not suffice'
  end

  def test_dup_atomic
    m = List::Matcher.new atomic: true
    rx = m.pattern %w( cat dog ), atomic: false
    assert_equal "cat|dog", rx
  end

  def test_dup_backtracking
    m = List::Matcher.new backtracking: true
    rx = m.pattern %w( cat dog ), backtracking: false
    assert_equal "(?>cat|dog)", rx
  end

  def test_dup_bound
    m = List::Matcher.new bound: false, atomic: false
    rx = m.pattern %w( cat dog ), bound: true
    assert_equal '\b(?:cat|dog)\b', rx
  end

  def test_dup_bound_string
    m = List::Matcher.new bound: false, atomic: false
    rx = m.pattern %w( cat dog ), bound: :string
    assert_equal '\A(?:cat|dog)\z', rx
  end

  def test_dup_bound_line
    m = List::Matcher.new bound: false, atomic: false
    rx = m.pattern %w( cat dog ), bound: :line
    assert_equal '^(?:cat|dog)$', rx
  end

  def test_dup_bound_fancy
    m = List::Matcher.new bound: false, atomic: false
    rx = m.pattern %w( 1 2 ), bound: { test: /\d/, left: '(?<!\d)', right: '(?!\d)' }
    assert_equal '(?<!\d)[12](?!\d)', rx
  end

  def test_dup_trim
    m = List::Matcher.new atomic: false
    rx = m.pattern [%( cat )], trim: true
    assert_equal 'cat', rx
  end

  def test_dup_case_insensitive
    m = List::Matcher.new
    rx = m.pattern %w(cat), case_insensitive: true
    assert_equal '(?i:cat)', rx
  end

  def test_dup_normalize_whitespace
    m = List::Matcher.new atomic: false
    rx = m.pattern ['  cat     dog  '], normalize_whitespace: true
    assert_equal 'cat\s++dog', rx
  end

  def test_dup_symbols
    m = List::Matcher.new atomic: false
    rx = m.pattern ['cat dog'], symbols: { ' ' => '\s++' }
    assert_equal 'cat\s++dog', rx
  end

  def test_multiline
    rx = List::Matcher.pattern %w( cat dog ), multiline: true
    assert_equal '(?m:cat|dog)', rx
  end

  def test_dup_multiline
    m = List::Matcher.new atomic: false
    rx = m.pattern %w( cat dog ), multiline: true
    assert_equal '(?m:cat|dog)', rx
  end

  def test_name
    m = List::Matcher.new name: :foo
    rx = m.pattern %w( cat dog )
    assert_equal '(?<foo>cat|dog)', rx
  end
end
