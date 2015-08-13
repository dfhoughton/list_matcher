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

## Usage

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
puts m.pattern %w( cat catalog )                           # (?:cat(?:alog)?+)
puts m.pattern (1..31).to_a                                # (?:[4-9]|1\d?+|2\d?+|3[01]?+)

# alternatively, if you aren't making a lot of regexen

puts List::Matcher.pattern %w( cat dog ), compile: false   # (?:cat|dog)
```

There are two methods that one should use with either `List::Matcher` or a `List::Matcher` object: `rx` and `pattern`. These
are identical except that `rx` produces a `Regexp` object and `pattern` produces the string from which one can compose the
return value of `rx`. The `pattern` method is more useful if one is interested in composing a larger regular expression out of
smaller pieces.

If one wants to construct multiple regexen with the same set of options, one would do well to construct a `List::Matcher` instance
with the options in question and then call its `rx` or `pattern` methods with simple lists. Otherwise, one might as well call the
class methods.

## Description

`List::Matcher` facilitates generating efficient regexen programmatically. This is useful, for example, when looking for
occurrences of particular words or phrases in freeform text. `List::Matcher` will automatically generate regular expressions
that minimize backtracking -- the revisiting of earlier decisions.

## Options

The `rx` and `pattern` methods take the same options. These are

### atomic 

    default: true

If true, the returned expression is wrapped in a non-capturing grouping expression, either `(?:...)` or `(?>...)`,
so it can receive a quantification suffix.

### backtracking 

    default: true

If true, the default non-capturing grouping expression is `(?:...)` rather than `(?>...)`, and the optional quantifier is
`?` rather than `?+`.

### bound 

    default: false

Whether boundary expressions should be attached to the margins of every expression in the list.

### trim 

    default: false

### case_insensitive 

    default: false

### normalize_whitespace 

    default: false

### special


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
