# frozen_string_literal: true

require_relative "logifos/version"
require_relative "logifos/errors"
require_relative "logifos/native"
require "json"

module Logifos
  # The render boundary: MathML in, deterministic SVG out, through the
  # packaged logifos engine. Every call sends one versioned request over the
  # C ABI and returns the parsed reply envelope.
  ABI_VERSION = 1
  SCHEMA_VERSION = 1

  class << self
    # The engine's capability reply: implemented operations, outputs, the
    # pinned formula contract, and the request limits.
    def capabilities
      exchange(op: "negotiate")["result"]
    end

    # Parses MathML into the wire formula model (a reply envelope Hash).
    def parse(mathml)
      exchange(op: "parse", format: "mathml", source: mathml.to_str)
    end

    # Renders MathML to deterministic SVG through a packaged font. The
    # formula contract comes from this engine's own negotiate reply, so the
    # client and the packaged artifact always agree on the pinned model.
    def render_svg(mathml, font:)
      parsed = parse(mathml)
      reply = exchange(
        op: "render", formula: parsed["result"]["model"],
        formula_contract: parsed["result"]["formula_contract"],
        output: "svg",
        options: { fonts: [font] },
      )
      reply["result"]["svg"]
    end

    # The engine's advertised capability bitmask, decoded per CONTRACT.md.
    def features
      engine.features
    end

    private

    # One request/reply exchange. A reply envelope with ok: false raises a
    # RequestError carrying the reply's code and message.
    def exchange(**request)
      request[:abi_version] = ABI_VERSION
      request[:schema_version] = SCHEMA_VERSION
      reply = JSON.parse(engine.request_json(JSON.generate(request)))
      return reply if reply["ok"] == true

      raise RequestError.new(reply.dig("error", "code") || "UNKNOWN",
                             reply.dig("error", "message"))
    end

    def engine
      @engine ||= Native.load
    end
  end

  # The reply envelope refused the request (a typed error code from the
  # engine's contract vocabulary).
  class RequestError < StandardError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message ? "#{code}: #{message}" : code.to_s)
    end
  end
end
