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
puts m.pattern %w( cat dog )                     # (?>cat|dog)
puts m.pattern %w( cat rat )                     # (?>[cr]at)
puts m.pattern %w( cat camel )                   # (?>ca(?>mel|t))
puts m.pattern %w( catttttttttt )                # (?>cat{10})
puts m.pattern %w( cat-t-t-t-t-t-t-t-t-t )       # (?>ca(?>t-){9}t)
puts m.pattern %w( catttttttttt batttttttttt )   # (?>[bc]at{10})
puts m.pattern %w( cad bad dad )                 # (?>[b-d]ad)
puts m.pattern %w( cat catalog )                 # (?>cat(?>alog)?+)
puts m.pattern (1..31).to_a                      # (?>[4-9]|1\d?+|2\d?+|3[01]?+)

# alternatively, if you aren't making a lot of regexen

puts List::Matcher.pattern %w( cat dog )         # (?>cat|dog)
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/list_matcher/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
