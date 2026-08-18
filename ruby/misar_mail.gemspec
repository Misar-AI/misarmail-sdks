Gem::Specification.new do |spec|
  spec.name          = "misarmail"
  spec.version       = "1.0.0"
  spec.authors       = ["Misar AI"]
  spec.email         = ["hello@misar.io"]
  spec.summary       = "Official Ruby SDK for MisarMail — transactional email, campaigns, leads, CRM"
  spec.description   = "Full-featured Ruby SDK for the MisarMail API (misarmail.com). Covers all 24 resource groups and 101 methods."
  spec.homepage      = "https://misarmail.com/docs/sdks/ruby"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata = {
    "homepage_uri"    => spec.homepage,
    "source_code_uri" => "https://github.com/Misar-AI/misarmail-sdks",
    "changelog_uri"   => "https://github.com/Misar-AI/misarmail-sdks/blob/main/ruby/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/Misar-AI/misarmail-sdks/issues"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE", "CHANGELOG.md"]
  spec.require_paths = ["lib"]
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.23"
  spec.add_development_dependency "simplecov", "~> 0.22"
end
