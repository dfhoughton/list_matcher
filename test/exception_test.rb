require "minitest/autorun"

require "list_matcher"

class ExceptionTest < Minitest::Test

  def test_bad_symbol
    e = assert_raises List::Matcher::Error do
      List::Matcher.pattern %w(cat), symbols: { foo: nil }
    end
    assert_equal 'symbol foo requires a pattern', e.message
  end

  def test_bad_name
    e = assert_raises List::Matcher::Error do
      List::Matcher.pattern %w(cat), name: []
    end
    assert_equal 'name must be a string or symbol', e.message
  end

  def test_bad_bound_symbol
    e = assert_raises List::Matcher::Error do
      List::Matcher.pattern %w(cat), bound: :foo
    end
    assert_equal 'unfamiliar value for :bound option: :foo', e.message
  end

  def test_bad_bound_no_test
    e = assert_raises List::Matcher::Error do
      List::Matcher.pattern %w(cat), bound: { left: '.' }
    end
    assert_equal 'no boundary test provided', e.message
  end

  def test_bad_bound_neither
    e = assert_raises List::Matcher::Error do
      List::Matcher.pattern %w(cat), bound: { test: '.' }
    end
    assert_equal 'neither bound provided', e.message
  end

  def test_bad_bound_strange_test
    e = assert_raises List::Matcher::Error do
      List::Matcher.pattern %w(cat), bound: { test: [], left: '.' }
    end
    assert_equal 'test must be Regexp or String', e.message
  end

  def test_bad_bound_not_string
    e = assert_raises List::Matcher::Error do
      List::Matcher.pattern %w(cat), bound: { test: /./, left: [] }
    end
    assert_equal 'bounds must be strings', e.message
  end

  def test_bad_symbol_no_pattern
    e = assert_raises List::Matcher::Error do
      List::Matcher.pattern %w(cat), symbols: { foo: {} }
    end
    assert_equal 'symbol foo requires a pattern', e.message
  end

  def test_bad_group_name
    e = assert_raises List::Matcher::Error do
      List::Matcher.pattern %w(cat), name: '3'
    end
    assert_equal '3 does not work as the name of a named group', e.message
  end

  def test_bad_symbol_key
    e = assert_raises List::Matcher::Error do
      List::Matcher.pattern %w(cat), symbols: { [] => 'foo' }
    end
    assert_equal 'symbols variable [] is neither a string, a symbol, nor a regex', e.message
  end

  def test_vetting
    e = assert_raises List::Matcher::Error do
      List::Matcher.pattern %w(cat), symbols: { foo: '++' }, vet: true
    end
    assert_equal 'the symbol foo has an ill-formed pattern: ++', e.message
  end
end
