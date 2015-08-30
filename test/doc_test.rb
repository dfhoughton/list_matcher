require "minitest/autorun"

require "list_matcher"

# test to make sure all the examples in the documentation work
class DocTest < Minitest::Test
  def test_all
    m = List::Matcher.new
    assert_equal '(?:cat|dog)', (m.pattern %w( cat dog ))
    assert_equal '(?:[cr]at)', (m.pattern %w( cat rat ))
    assert_equal '(?:ca(?:mel|t))', (m.pattern %w( cat camel ))
    assert_equal '(?:(?:c|fl|spr)at)', (m.pattern %w( cat flat sprat ))
    assert_equal '(?:cat{10})', (m.pattern %w( catttttttttt ))
    assert_equal '(?:ca(?:t-){9}t)', (m.pattern %w( cat-t-t-t-t-t-t-t-t-t ))
    assert_equal '(?:[bc]at{10})', (m.pattern %w( catttttttttt batttttttttt ))
    assert_equal '(?:[b-d]ad)', (m.pattern %w( cad bad dad ))
    assert_equal '(?:cat(?:alog)?)', (m.pattern %w( cat catalog ))
    assert_equal '(?:[4-9]|1\d?|2\d?|3[01]?)', (m.pattern (1..31).to_a)
    assert_equal "(?:cat|dog)", (List::Matcher.pattern %w( cat dog ))
    assert_equal /(?:cat|dog)/, (List::Matcher.rx      %w( cat dog ))
    m = List::Matcher.new normalize_whitespace: true, bound: true, case_insensitive: true, multiline: true, atomic: false, symbols: { num: '\d++' }
    m2 = m.bud case_insensitive: false
    assert !m2.case_insensitive
    assert_equal "cat|dog", (List::Matcher.pattern %w(cat dog), atomic: false)
    assert_equal "(?:cat|dog)", (List::Matcher.pattern %w(cat dog), atomic: true)
    assert_equal "(?:cat|dog)", (List::Matcher.pattern %w( cat dog ))
    assert_equal "(?>cat|dog)", (List::Matcher.pattern %w( cat dog ), backtracking: false)
    assert_equal "(?:\\bcat\\b)", (List::Matcher.pattern %w(cat), bound: :word)
    assert_equal "(?:\\bcat\\b)", (List::Matcher.pattern %w(cat), bound: true)
    assert_equal "(?:^cat$)", (List::Matcher.pattern %w(cat), bound: :line)
    assert_equal "(?:\\Acat\\z)", (List::Matcher.pattern %w(cat), bound: :string)
    assert_equal "(?:(?<!\\d)[1-9](?:\\d\\d?)?(?!\\d))", (List::Matcher.pattern (1...1000).to_a, bound: { test: /\d/, left: '(?<!\d)', right: '(?!\d)'})
    assert_equal "(?:(?:\\ ){5}cat(?:\\ ){5})", (List::Matcher.pattern ['     cat     '])
    assert_equal "(?:cat)", (List::Matcher.pattern ['     cat     '], strip: true)
    assert_equal "(?:C(?:AT|at)|cat)", (List::Matcher.pattern %w( Cat cat CAT ))
    assert_equal "(?i:cat)", (List::Matcher.pattern %w( Cat cat CAT ), case_insensitive: true)
    assert_equal "(?m:cat)", (List::Matcher.pattern %w(cat), multiline: true)
    assert_equal "(?:\\ (?:\\ dog\\ walker|cat\\ \\ walker\\ )|camel\\ \\ walker)", (List::Matcher.pattern [ ' cat  walker ', '  dog walker', 'camel  walker' ])
    assert_equal "(?:(?:ca(?:mel|t)|dog)\\s++walker)", (List::Matcher.pattern [ ' cat  walker ', '  dog walker', 'camel  walker' ], normalize_whitespace: true)
    assert_equal "(?:(?:(?:Catch|Fahrenheit)\\ )?\\d++)", (List::Matcher.pattern [ 'Catch 22', '1984', 'Fahrenheit 451' ], symbols: { /\d+/ => '\d++' })
    assert_equal "(?:(?:(?:Catch|Fahrenheit)\\ )?\\d++)", (List::Matcher.pattern [ 'Catch foo', 'foo', 'Fahrenheit foo' ], symbols: { 'foo' => '\d++' })
    assert_equal "(?:(?:(?:Catch|Fahrenheit)\\ )?\\d++)", (List::Matcher.pattern [ 'Catch foo', 'foo', 'Fahrenheit foo' ], symbols: { foo: '\d++' })
    assert_equal "(?<cat>cat)", (List::Matcher.pattern %w(cat), name: :cat)

    m = List::Matcher.new atomic: false, bound: true

    year      = m.pattern( (1901..2000).to_a, name: :year )
    mday      = m.pattern( (1..31).to_a, name: :mday )
    weekdays  = %w( Monday Tuesday Wednesday Thursday Friday Saturday Sunday )
    weekdays += weekdays.map{ |w| w[0...3] }
    wday      = m.pattern weekdays, case_insensitive: true, name: :wday
    months    = %w( January February March April May June July August September October November December )
    months   += months.map{ |w| w[0...3] }
    mo        = m.pattern months, case_insensitive: true, name: :mo

    date_20th_century = m.rx(
      [
        'wday, mo mday',
        'wday, mo mday year',
        'mo mday, year',
        'mo year',
        'mday mo year',
        'wday',
        'year',
        'mday mo',
        'mo mday',
        'mo mday year'
      ],
      normalize_whitespace: true,
      atomic: true,
      symbols: {
        year: year,
        mday: mday,
        wday: wday,
        mo:   mo
      }
    )

    assert m = date_20th_century.match('Friday')
    assert_equal 'Friday', m[:wday]
    assert_nil m[:year]
    assert_nil m[:mo]
    assert_nil m[:mday]
    assert m = date_20th_century.match('August 27')
    assert_equal 'August', m[:mo]
    assert_equal '27', m[:mday]
    assert_nil m[:year]
    assert_nil m[:wday]
    assert m = date_20th_century.match('May 6, 1969')
    assert_equal 'May', m[:mo]
    assert_equal '6', m[:mday]
    assert_equal '1969', m[:year]
    assert_nil m[:wday]
    assert m = date_20th_century.match('1 Jan 2000')
    assert_equal '1', m[:mday]
    assert_equal 'Jan', m[:mo]
    assert_equal '2000', m[:year]
    assert_nil m[:wday]
    assert_nil date_20th_century.match('this is not actually a date')
    assert_equal "(?:\\#\\ is\\ sometimes\\ called\\ the\\ pound\\ symbol|cat\\ and\\ dog)", (List::Matcher.pattern [ 'cat and dog', '# is sometimes called the pound symbol' ])
    assert_equal "(?-x:cat and dog|# is sometimes called the pound symbol)", (List::Matcher.pattern [ 'cat and dog', '# is sometimes called the pound symbol' ], not_extended: true)
    assert_equal "(?:\\bcat)", List::Matcher.pattern( %w(cat), bound: :word_left )
    assert_equal "(?:\\Acat)", List::Matcher.pattern( %w(cat), bound: :string_left )
    assert_equal "(?:cat$)", List::Matcher.pattern( %w(cat), bound: :line_right )
    assert_equal "(?:\\#@%|\\bcat\\b)", List::Matcher.pattern( %w( cat #@% ), bound: :word )
  end

end
