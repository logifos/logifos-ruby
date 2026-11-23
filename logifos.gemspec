# frozen_string_literal: true

require_relative "lib/logifos/version"

Gem::Specification.new do |spec|
  spec.name = "logifos"
  spec.version = Logifos::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]
  spec.summary = "Math formula rendering through the logifos engine."
  spec.description = <<~DESC
    Renders math formulas to deterministic SVG through the logifos Rust
    engine: syntax models transform into the central Formula model, which
    lays out to a box tree and emits SVG. PNG rides claricle/svgpng.
  DESC
  spec.homepage = "https://github.com/logifos/logifos-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.2.0")
  spec.files = %w[
    HISTORY.txt
    LICENSE.txt
    README.md
    lib/logifos.rb
    lib/logifos/errors.rb
    lib/logifos/native_library.rb
    lib/logifos/native_runtime.rb
    lib/logifos/response.rb
    lib/logifos/version.rb
  ]
  spec.require_paths = ["lib"]
  spec.add_dependency "ffi", "~> 1.17"
  spec.add_dependency "json", "~> 2.6"
  spec.metadata["rubygems_mfa_required"] = "true"
end
