Gem::Specification.new do |spec|
  spec.name          = "misarmail"
  spec.version       = "5.0.0"
  spec.authors       = ["Misar AI"]
  spec.email         = ["hello@misar.io"]
  spec.summary       = "Ruby client for MisarMail: transactional send, campaigns, contacts, templates, automations, deliverability and analytics in one API"
  spec.description   = "Ruby client for MisarMail's transactional and marketing email API " \
                       "(misarmail.com): send mail, run campaigns and A/B tests, manage " \
                       "contacts, segments, templates and automations, verify domains and " \
                       "DMARC, validate addresses, track revenue and read analytics. " \
                       "33 resource groups on one client, plus retries with backoff, typed " \
                       "plan-limit errors, SSE streaming, and constant-time webhook " \
                       "signature verification. No runtime dependencies beyond the stdlib."
  spec.homepage      = "https://www.misarmail.com"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata = {
    "homepage_uri"      => spec.homepage,
    "documentation_uri" => "https://docs.misar.io/mail",
    "source_code_uri"   => "https://github.com/Misar-AI/misarmail-sdks/tree/main/ruby",
    "changelog_uri"     => "https://github.com/Misar-AI/misarmail-sdks/blob/main/ruby/CHANGELOG.md",
    "bug_tracker_uri"   => "https://github.com/Misar-AI/misarmail-sdks/issues"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE", "CHANGELOG.md"]
  spec.require_paths = ["lib"]
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.23"
  spec.add_development_dependency "simplecov", "~> 0.22"
end
