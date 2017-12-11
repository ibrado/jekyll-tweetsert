
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "jekyll/tweetsert/version"

Gem::Specification.new do |spec|
  spec.name          = "jekyll-tweetsert"
  spec.version       = Jekyll::Tweetsert::VERSION
  spec.authors       = ["Alex Ibrado"]
  spec.email         = ["alex@ibrado.org"]

  spec.summary       = %q{Tweet Retriever and Post Generator for Jekyll}
  spec.description   = %q{This plugin retrieves tweets from a Twitter timeline and creates new posts with a default layout of 'tweet'. These are dated according to the original tweet timestamp and may be rendered differently in the homepage.}
  spec.homepage      = "https://github.com/ibrado/jekyll-tweetsert"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"

  spec.add_runtime_dependency "api_cache", "~> 0.3"
  spec.add_runtime_dependency "moneta", "~> 1.0"
end
