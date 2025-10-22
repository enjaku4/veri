require_relative "lib/veri/version"

Gem::Specification.new do |spec|
  spec.name = "veri"
  spec.version = Veri::VERSION
  spec.authors = ["enjaku4"]
  spec.email = ["enjaku4@icloud.com"]
  spec.homepage = "https://github.com/enjaku4/veri"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["documentation_uri"] = "#{spec.homepage}/blob/main/README.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.summary = "Minimal cookie-based authentication library for Ruby on Rails"
  spec.description = "Veri provides cookie-based authentication for Ruby on Rails applications with secure password storage, granular session management, multi-tenancy support, and user impersonation feature, without imposing business logic"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2", "< 3.5"

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
