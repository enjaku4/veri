require_relative "lib/veri/version"

Gem::Specification.new do |spec|
  spec.name = "veri"
  spec.version = Veri::VERSION
  spec.authors = ["enjaku4"]
  spec.homepage = "https://github.com/brownboxdev/veri"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.summary = "TODO"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2", "< 3.5"

  spec.files = [
    "veri.gemspec", "README.md", "CHANGELOG.md", "LICENSE.txt"
  ] + Dir.glob("lib/**/*")

  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.1", "< 8.1"
end
