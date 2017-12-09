# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'list_matcher/version'

Gem::Specification.new do |spec|
  spec.name                  = "list_matcher"
  spec.version               = ListMatcher::VERSION
  spec.authors               = ["dfhoughton"]
  spec.email                 = ["dfhoughton@gmail.com"]
  spec.summary               = %q{List::Matcher automates the generation of efficient regular expressions.}
  spec.description           = <<-END
    List::Matcher automates the creation of regular expressions from lists, including lists of other regular
    expressions. The expressions it generates from lists of strings are non-backtracking and compact.
  END
  spec.homepage              = "https://github.com/dfhoughton/list_matcher"
  spec.license               = "MIT"

  spec.files                 = `git ls-files -z`.split("\x0")
  spec.executables           = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files            = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths         = ["lib"]
  spec.required_ruby_version = '>= 2.0'

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5"
end
