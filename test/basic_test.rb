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
    assert_equal '(?>\b(?>cat|dog)\b)', rx
    rx = Regexp.new rx
    words.each do |w|
      assert rx === w
    end
  end

  def test_repeats
    rx = List::Matcher.pattern %w(aaaaaaaaaa)
    assert_equal '(?>a{10})', rx
    rx = List::Matcher.pattern %w(bbbaaaaaaaaaabbbaaaaaaaaaa)
    assert_equal '(?>(?>bbba{10}){2})', rx
  end

  def test_opt_suffix
    words = %w(the them)
    rx = List::Matcher.pattern words
    assert_equal '(?>them?+)', rx
    rx = Regexp.new rx
    words.each do |w|
      rx === w
    end
  end

  def test_opt_prefix
    words = %w(at cat)
    rx = List::Matcher.pattern words
    assert_equal '(?>c?+at)', rx
    rx = Regexp.new rx
    words.each do |w|
      rx === w
    end
  end
end
