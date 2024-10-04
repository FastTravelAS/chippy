require_relative "lib/chippy/version"

Gem::Specification.new do |s|
  s.name = "chippy"
  s.version = Chippy::VERSION
  s.authors = ["Martin Ulleberg"]
  s.email = ["martin@rubynor.com"]
  s.summary = "Chippy is a library designed to consume and process the events from Chippy devices."
  s.homepage = "https://github.com/rubynor/chippy"

  s.required_ruby_version = ">= 3.2.0"
  s.add_dependency "activesupport", ">= 6.0.0"
  s.add_dependency "redis", ">= 4.2", "< 6"
  s.add_dependency "sentry-ruby", ">= 5.8", "< 6"
  s.add_development_dependency "rspec", "~> 3.0"
  s.add_development_dependency "rubocop", "~> 1.44"
  s.add_development_dependency "standard", "~> 1.24"
  s.add_development_dependency "brakeman", "~> 5.4"
  s.add_development_dependency "rubocop-rspec", "~> 2.18"
  s.add_development_dependency "rubocop-performance", "~> 1.15"
  s.add_development_dependency "rubocop-rake", "~> 0.6.0"
  s.add_development_dependency "timecop", "~> 0.9.6"
  s.add_development_dependency "mock_redis", "~> 0.45.0"
  s.files = Dir["lib/**/*", "README.md", "CHANGELOG.md", "chippy.png"]
end
