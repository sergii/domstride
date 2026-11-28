require_relative "lib/domstride/version"

Gem::Specification.new do |spec|
  spec.name = "domstride"
  spec.version = Domstride::VERSION
  spec.authors = ["Domstride contributors"]
  spec.summary = "Experimental browserless interaction testing for Ruby"
  spec.homepage = "https://github.com/sergii/domstride"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"
  spec.files = Dir["lib/**/*", "runtime/**/*", "README.md", "LICENSE", "package.json", "exe/*", "protocol/**/*", "adapters/**/*.cjs"]
  spec.require_paths = ["lib"]
  spec.bindir = "exe"
  spec.executables = ["domstride", "specdrive"]
  spec.add_dependency "base64", ">= 0.2", "< 1"
  spec.add_dependency "mini_mime", "~> 1.1"
  spec.add_dependency "rack-test", "~> 2.2"
  spec.add_dependency "capybara", "~> 3.40"
end
