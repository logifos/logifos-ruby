# frozen_string_literal: true

require_relative "logifos/version"
require_relative "logifos/errors"
require_relative "logifos/native_runtime"

module Logifos
  # Uses only the explicitly selected native library and caller's contract.
  def self.render(formula_model, library_path:, formula_contract:, format: :svg, options: {})
    NativeRuntime.new(library_path: library_path).render(
      formula_model, formula_contract: formula_contract, format: format, options: options
    )
  end
end
