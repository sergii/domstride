require_relative "lib/domstride/version"

Gem::Specification.new do |spec|
  spec.name = "domstride"
  spec.version = Domstride::VERSION
  spec.authors = ["Domstride contributors"]
  spec.summary = "Experimental browserless interaction testing for Ruby"
  spec.homepage = "https://github.com/sergii/domstride"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"
  spec.files = Dir["lib/**/*", "runtime/**/*", "README.md", "LICENSE", "package.json"]
  spec.require_paths = ["lib"]
end
