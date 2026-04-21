Gem::Specification.new do |spec|
  spec.name          = "misarmail"
  spec.version       = "1.0.0"
  spec.authors       = ["Misar AI"]
  spec.email         = ["hello@misar.io"]
  spec.summary       = "Official Ruby SDK for MisarMail — transactional email, campaigns, leads, CRM"
  spec.description   = "Full-featured Ruby SDK for the MisarMail API (mail.misar.io). Covers all 24 resource groups and 101 methods."
  spec.homepage      = "https://mail.misar.io/docs/sdks/ruby"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata = {
    "homepage_uri"    => spec.homepage,
    "source_code_uri" => "https://git.misar.io/misaradmin/misarmail-ruby-sdk",
    "changelog_uri"   => "https://git.misar.io/misaradmin/misarmail-ruby-sdk/releases"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", ">= 2.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.23"
  spec.add_development_dependency "simplecov", "~> 0.22"
end
