# frozen_string_literal: true

require_relative "logifos/version"

module Logifos
  # The render boundary: formula models in (the plurimath common model),
  # SVG or PNG bytes out, through the logifos engine. P0 carries the
  # contract; the engine call lands with P4.
  def self.render(formula_model, format: :svg)
    raise NotImplementedError,
          "the logifos engine boundary lands in P4 (got #{format.inspect})"
  end
end
