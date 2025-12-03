require_relative "lib/veri/version"

Gem::Specification.new do |spec|
  spec.name = "veri"
  spec.version = Veri::VERSION
  spec.authors = ["enjaku4"]
  spec.email = ["contact@brownbox.dev"]
  spec.homepage = "https://github.com/enjaku4/veri"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["documentation_uri"] = "#{spec.homepage}/blob/main/README.md"
  spec.metadata["mailing_list_uri"] = "#{spec.homepage}/discussions"
  spec.metadata["funding_uri"] = "https://github.com/sponsors/enjaku4"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.summary = "Minimal cookie-based authentication library for Ruby on Rails"
  spec.description = "Minimal cookie-based authentication for Rails applications with multi-tenancy support and granular session management"
  spec.license = "MIT"
  # TODO: support new ruby
  spec.required_ruby_version = ">= 3.2", "< 3.6"

  spec.files = [
    "veri.gemspec", "README.md", "CHANGELOG.md", "LICENSE.txt"
  ] + Dir.glob("lib/**/*")

  spec.require_paths = ["lib"]

  spec.add_dependency "argon2", "~> 2.0"
  spec.add_dependency "bcrypt", "~> 3.0"
  spec.add_dependency "dry-configurable", "~> 1.1"
  spec.add_dependency "dry-types", "~> 1.7"
  spec.add_dependency "rails", ">= 7.2", "< 8.2"
  spec.add_dependency "scrypt", "~> 3.0"
  spec.add_dependency "user_agent_parser", "~> 2.0"
end
