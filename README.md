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
puts m.pattern %w( cat dog )    # (?>cat|dog)
puts m.pattern %w( cat rat )    # (?>[cr]at)
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/list_matcher/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
