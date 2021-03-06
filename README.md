# ListMatcher

For creating compact, non-backtracking regular expressions from a list of strings.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'list_matcher'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install list_matcher

## Synopsis

```ruby
require 'list_matcher'

m = List::Matcher.new
puts m.pattern %w( cat dog )                               # (?:cat|dog)
puts m.pattern %w( cat rat )                               # (?:[cr]at)
puts m.pattern %w( cat camel )                             # (?:ca(?:mel|t))
puts m.pattern %w( cat flat sprat )                        # (?:(?:c|fl|spr)at)
puts m.pattern %w( catttttttttt )                          # (?:cat{10})
puts m.pattern %w( cat-t-t-t-t-t-t-t-t-t )                 # (?:ca(?:t-){9}t)
puts m.pattern %w( catttttttttt batttttttttt )             # (?:[bc]at{10})
puts m.pattern %w( cad bad dad )                           # (?:[b-d]ad)
puts m.pattern %w( cat catalog )                           # (?:cat(?:alog)?)
puts m.pattern (1..31).to_a                                # (?:[4-9]|1\d?|2\d?|3[01]?)
```

## Usage

One provides a list of expressions to match and perhaps some options and receives in turn either a
compiled `Regexp` or a string from which such a regex can be compiled. The `rx` method provides a compiled
regex and `pattern`, a string. The latter is chiefly useful when composing a larger regex out of smaller
pieces.

The options one may provide to `List::Matcher` are all validated. Any errors cause it to raise a
`List::Matcher::Error` exception.

## Description

`List::Matcher` facilitates generating efficient regexen programmatically. This is useful, for example, when looking for
occurrences of particular words or phrases in free-form text. `List::Matcher` will automatically generate regular expressions
that minimize backtracking, so they tend to be as fast as one could hope a regular expression to be. (The general strategy is
to represent the items in the list as a trie.)

`List::Matcher` has many options and the initialization of a matcher for pattern generation is somewhat complex, so various methods
are provided to minimize initializations and the number of times you specify options. For one-off patterns, you may as well call
class methods, either `pattern` which generates a string, or `rx`, which returns a `Regexp` object:

```ruby
List::Matcher.pattern %w( cat dog )   # "(?:cat|dog)"
List::Matcher.rx      %w( cat dog )   # /(?:cat|dog)/
```

If you plan to generate multiple regexen, or have complicated options which you always use, you should generate a configured
instance first:

```ruby
m = List::Matcher.new normalize_whitespace: true, bound: true, case_insensitive: true, multiline: true, atomic: false, symbols: { num: '\d++' }
m.pattern method_that_gets_a_long_list
m.rx      method_that_gets_a_long_list
...
```

If you have a basic set of options and you need to modify these in particular cases, you can:

```ruby
m.pattern list, case_insensitive: false
```

You can also generate a prototype list matcher with a particular variation and bud off children with their own properties:

```ruby
m  = List::Matcher.new normalize_whitespace: true, bound: true, case_insensitive: true, multiline: true, atomic: false, symbols: { num: '\d++' }
m2 = m.bud case_insensitive: false
```

Basically, you can mix in options in whatever way suits you. Constructing configured instances gives you a tiny bit of efficiency, but
mostly it saves you from specifying these options in multiple places.

## Options

The one can provide to `new`, `bud`, `pattern`, or `rx` are all the same. These are

### atomic 

```ruby
default: true
```

If true, the returned expression is always wrapped in some grouping expression -- `(?:...)`, `(?>...)`, `(?i:...)`, etc.; whatever
is appropriate given the other options and defaults -- so it can receive a quantification suffix.

```ruby
List::Matcher.pattern %w(cat dog), atomic: false   # "cat|dog"
List::Matcher.pattern %w(cat dog), atomic: true    # "(?:cat|dog)"
```

### backtracking 

```ruby
default: true
```

If true, the default non-capturing grouping expression is `(?:...)` rather than `(?>...)`, and the optional quantifier is
`?` rather than `?+`.

```ruby
List::Matcher.pattern %w( cat dog )                        # "(?:cat|dog)"
List::Matcher.pattern %w( cat dog ), backtracking: false   # "(?>cat|dog)"
```

### bound 

```ruby
default: false
```

Whether boundary expressions should be attached to the margins of every expression in the list (but see note below). If this value is simply true, this means
each item's marginal characters, the first and the last, are tested to see whether they are word characters and if so the word
boundary symbol, `\b`, is appended to them where appropriate. There are several variants on this, however:

```ruby
bound: :word
```

This is the same as `bound: true`.

```ruby
List::Matcher.pattern %w(cat), bound: :word   # "(?:\\bcat\\b)"
List::Matcher.pattern %w(cat), bound: true    # "(?:\\bcat\\b)"
```

```ruby
bound: :line
```

Each item should take up an entire line, so the boundary symbols are `^` and `$`.

```ruby
List::Matcher.pattern %w(cat), bound: :line   # "(?:^cat$)"
```

```ruby
bound: :string
```

Each item should match the entire string compared against, so the boundary symbols are `\A` and `\z`.

```ruby
List::Matcher.pattern %w(cat), bound: :string   # "(?:\\Acat\\z)"
```

**NOTE** for each of these variants, `:word`, `:line`, and `:string` there are `left` and `right` subvarieties that
only append their boundary marker to that side of the word:

```ruby
List::Matcher.pattern %w(cat), bound: :word_left     # "(?:\\bcat)"
List::Matcher.pattern %w(cat), bound: :string_left   # "(?:\\Acat)"
List::Matcher.pattern %w(cat), bound: :line_right    # "(?:cat$)"
```

Note also that `List::Matcher` will only append the boundary marker when it is appropriate according to
the test, so items for which the test fails will not receive a boundary marker of any sort:

```ruby
List::Matcher.pattern %w( cat #@% ), bound: :word   # "(?:\\#@%|\\bcat\\b)"
```

```ruby
bound: { test: /\d/, left: '(?<!\d)', right: '(?!\d)'}
```

If you have an ad hoc boundary definition -- here it is a digit/non-digit boundary -- you may specify it so. The test parameter
identifies marginal characters that require the boundary tests and the `:left` and `:right` symbols identify the boundary conditions.

```ruby
List::Matcher.pattern (1...1000).to_a, bound: { test: /\d/, left: '(?<!\d)', right: '(?!\d)'}
# "(?:(?<!\\d)[1-9](?:\\d\\d?)?(?!\\d))"
```

As with the predefined boundaries -- `:word_left`, `:line_right`, `:string_left`, etc. -- you can bound items only at one
margin, in this case by providing only the `left:` or `right:` key-value pair.

### strip 

```ruby
default: false
```

Strip whitespace off the margins of items in the list.

```ruby
List::Matcher.pattern ['     cat     ']                # "(?:(?:\\ ){5}cat(?:\\ ){5})"
List::Matcher.pattern ['     cat     '], strip: true   # "(?:cat)"
```

### case_insensitive 

```ruby
default: false
```

Generate a case-insensitive regular expression.

```ruby
List::Matcher.pattern %w( Cat cat CAT )                           # "(?:C(?:AT|at)|cat)"
List::Matcher.pattern %w( Cat cat CAT ), case_insensitive: true   # "(?i:cat)"
```

### multiline 

```ruby
default: false
```

Generate a multi-line regex.

```ruby
List::Matcher.pattern %w(cat), multiline: true   # "(?m:cat)"
```

The special feature of a multi-line regular expression is that `.` can grab newline characters. Because `List::Matcher`
never produces `.` on its own, this option is only useful in conjunction with the `symbols` option, which lets one
inject snippets of regex into the one generated.

### normalize_whitespace 

```ruby
default: false
```

This strips whitespace from items in the list and treats all internal whitespace as equivalent.

```ruby
List::Matcher.pattern [ ' cat  walker ', '  dog walker', 'camel  walker' ]
# "(?:\\ (?:\\ dog\\ walker|cat\\ \\ walker\\ )|camel\\ \\ walker)"
List::Matcher.pattern [ ' cat  walker ', '  dog walker', 'camel  walker' ], normalize_whitespace: true
# "(?:(?:ca(?:mel|t)|dog)\\s++walker)"
```

### symbols

You can tell `List::Matcher` that certain character sequences should be regarded as "symbols". It will then leave
these unmolested, replacing them in the generated regex with whatever you map the symbol sequences to. The keys in
the symbol hash are expected to be strings, symbols, or `Regexps`. Symbol keys are converted to their
sequence by stringification. `Regexp` keys convert any sequence they match.

```ruby
List::Matcher.pattern [ 'Catch 22', '1984', 'Fahrenheit 451' ], symbols: { /\d+/ => '\d++' }
# "(?:(?:(?:Catch|Fahrenheit)\\ )?\\d++)"
List::Matcher.pattern [ 'Catch foo', 'foo', 'Fahrenheit foo' ], symbols: { 'foo' => '\d++' }
# "(?:(?:(?:Catch|Fahrenheit)\\ )?\\d++)"
List::Matcher.pattern [ 'Catch foo', 'foo', 'Fahrenheit foo' ], symbols: { foo: '\d++' }
# "(?:(?:(?:Catch|Fahrenheit)\\ )?\\d++)"
```

Because it is possible for symbol sequences to overlap, sequences with string or symbol keys are evaluated before `Regexps`, and longer keys are
evaluated before shorter ones.

`List::Matcher` doesn't parse regex strings to determine whether they need to be grouped before any iteration suffix
can be added or to determine whether it is sensible to add boundary sequences before or after them. By default it assumes
that they need grouping if they repeat and that boundary markers don't make sense. You can override this behavior, however.
You specify the characteristics of the pattern as a hash with the following keys:

**`:pattern`**

The value is the pattern to substitute for the symbol.

**`:atomic`**

The pattern needs no grouping if the value is true.

**`:left`**

A character to test for the left boundary condition.

**`:right`**

A character to test for the right boundary condition.

For example:

```ruby
List::Matcher.pattern %w(dddd ddddddd), 
  bound: :word, 
  symbols: { d: { pattern: '\d', atomic: true, left: '0', right: '0' } },   # <-- this
  atomic: false

# \b\d{4}(?:\d{3})?\b
```

### name

If you assign your pattern a name, it will be constructed with a named group such that you can extract
the substring matched.

```ruby
List::Matcher.pattern %w(cat), name: :cat   # "(?<cat>cat)"
```

This is mostly useful if you are using `List::Matcher` to compose complex regexen incrementally. E.g., from the examples directory,

```ruby
require 'list_matcher'

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
  bound:  true,
  symbols: {
    year: { pattern: year, atomic: true, left: '1', right: '1' },
    mday: { pattern: mday, atomic: true, left: '1', right: '1' },
    wday: { pattern: wday, atomic: true, left: 'a', right: 'a' },
    mo:   { pattern: mo,   atomic: true, left: 'a', right: 'a' }
  }
)

[
  'Friday',
  'August 27',
  'May 6, 1969',
  '1 Jan 2000',
  'this is not actually a date'
].each do |candidate|
  if m = date_20th_century.match(candidate)
    puts "candidate: #{candidate}; year: #{m[:year]}; month: #{m[:mo]}; weekday: #{m[:wday]}; day of the month: #{m[:mday]}"
  else
    puts "#{candidate} does not look like a plausible date in the 20th century"
  end
end
```

### vet

```ruby
default: false
```

If true, all patterns associated with symbols will be tested upon initialization to make sure they will
create legitimate regular expressions. If you are prone to doing this, for example:

```ruby
List::Matcher.new symbols: { aw_nuts: '+++' }
```

then you may want to vet your symbols. Vetting is not done by default because one assumes you've worked out
your substitutions on your own time and we need not waste runtime checking them.

### not_extended

```ruby
default: false
```

Under normal circumstances `List::Matcher` will escape simple space characters and `#` lest the pattern
generated be included in an *extended* regular expression where these are meta-characters. If you find this
makes the expressions unreadable or otherwise annoying, you can tell `List::Matcher` to explicitly generate
a non-extended regular expression. This may safely be included in any sort of regular expression, but it will
be wrapped with the modifier expression `(?-x:...)`.

```ruby
List::Matcher.pattern [ 'cat and dog', '# is sometimes called the pound symbol' ]
# "(?:\\#\\ is\\ sometimes\\ called\\ the\\ pound\\ symbol|cat\\ and\\ dog)"
List::Matcher.pattern [ 'cat and dog', '# is sometimes called the pound symbol' ], not_extended: true
# "(?-x:cat and dog|# is sometimes called the pound symbol)"
```

Note that `List::Matcher` will continue to quote other white space characters.

### encoding

```ruby
default: Encoding::UTF_8
```

`List::Matcher` converts characters into integers during the construction of character classes and then
must convert the integers back into characters. In order to do this with characters whose code point is
above 255 we must give `chr` a character encoding. This is all that this is. Most likely you will never
need to change this default, but if it causes you trouble this parameters is provided so you can fix
it without having to fork the code.

## Benchmarks

Efficiency isn't the principle purpose of List::Matcher, but in almost all cases List::Matcher
regular expressions are more efficient than a regular expression generated by simply joining alternates
with `|`. The following results were extracted from the output of the benchmark script included with this
distribution. Sets are provided as a baseline for comparison, though there are many things one can do
with a regular expression that one cannot do with a set.

```
RANDOM WORDS, VARIABLE LENGTH

number of words: 100

            set good:    53360.1 i/s
  List::Matcher good:    22211.7 i/s - 2.40x slower
      simple rx good:    13086.6 i/s - 4.08x slower
           list good:     4748.0 i/s - 11.24x slower

             set bad:    57387.1 i/s
   List::Matcher bad:    14398.7 i/s - 3.99x slower
       simple rx bad:     7347.1 i/s - 7.81x slower
            list bad:     2583.1 i/s - 22.22x slower


number of words: 1000

            set good:     5380.5 i/s
  List::Matcher good:     1665.3 i/s - 3.23x slower
      simple rx good:      166.7 i/s - 32.27x slower
           list good:       52.8 i/s - 101.98x slower

             set bad:     5294.8 i/s
   List::Matcher bad:     1061.1 i/s - 4.99x slower
       simple rx bad:       81.0 i/s - 65.34x slower
            list bad:       26.1 i/s - 202.51x slower


number of words: 10000

            set good:      361.3 i/s
  List::Matcher good:      146.4 i/s - 2.47x slower
      simple rx good:        1.7 i/s - 210.46x slower
           list good:        0.4 i/s - 1027.74x slower

             set bad:      370.3 i/s
   List::Matcher bad:       82.2 i/s - 4.51x slower
       simple rx bad:        0.8 i/s - 447.85x slower
            list bad:        0.2 i/s - 1882.35x slower


FIXED LENGTH, FULL RANGE

number of words: 10; List::Matcher rx: (?-mix:\A\d\z)

            set good:   520144.5 i/s
  List::Matcher good:   382968.0 i/s - 1.36x slower
           list good:   323052.6 i/s - 1.61x slower
      simple rx good:   316058.3 i/s - 1.65x slower

             set bad:   624424.8 i/s
   List::Matcher bad:   270882.3 i/s - 2.31x slower
       simple rx bad:   266277.3 i/s - 2.35x slower
            list bad:   175058.3 i/s - 3.57x slower


number of words: 100; List::Matcher rx: (?-mix:\A\d\d\z)

        set creation:       20.3 i/s
  simple rx creation:       15.9 i/s - 1.28x slower
List::Matcher creation:       15.9 i/s - 1.28x slower

            set good:    52058.4 i/s
  List::Matcher good:    41841.7 i/s - 1.24x slower
      simple rx good:    15095.6 i/s - 3.45x slower
           list good:     4350.1 i/s - 11.97x slower

             set bad:    59315.4 i/s
       simple rx bad:    28063.6 i/s - 2.11x slower
   List::Matcher bad:    27823.9 i/s - 2.13x slower
            list bad:     2083.9 i/s - 28.46x slower


number of words: 1000; List::Matcher rx: (?-mix:\A\d{3}\z)

        set creation:        2.1 i/s
List::Matcher creation:        1.5 i/s - 1.40x slower
  simple rx creation:        1.5 i/s - 1.41x slower

            set good:     4664.2 i/s
  List::Matcher good:     3514.1 i/s - 1.33x slower
      simple rx good:      225.6 i/s - 20.67x slower
           list good:       44.2 i/s - 105.57x slower

             set bad:     5830.5 i/s
       simple rx bad:     2802.5 i/s - 2.08x slower
   List::Matcher bad:     2717.0 i/s - 2.15x slower
            list bad:       20.0 i/s - 291.10x slower


number of words: 10000; List::Matcher rx: (?-mix:\A\d{4}\z)

        set creation:        0.2 i/s
  simple rx creation:        0.1 i/s - 1.21x slower
List::Matcher creation:        0.1 i/s - 1.31x slower

            set good:      369.4 i/s
  List::Matcher good:      326.2 i/s - 1.13x slower
      simple rx good:        2.3 i/s - 159.07x slower
           list good:        0.4 i/s - 966.48x slower

             set bad:      426.6 i/s
       simple rx bad:      285.6 i/s - 1.49x slower
   List::Matcher bad:      277.1 i/s - 1.54x slower
            list bad:        0.2 i/s - 2236.24x slower

```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/list_matcher/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
