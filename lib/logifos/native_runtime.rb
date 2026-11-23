# frozen_string_literal: true

require "digest"
require "json"
require_relative "native_library"
require_relative "response"

module Logifos
  # A per-library context for the versioned JSON facade; it owns no font state.
  class NativeRuntime
    BUFFER_V1 = 1
    JSON_V1 = 2
    RENDER = 4

    attr_reader :library

    def initialize(library_path:, required_features: BUFFER_V1 | JSON_V1)
      required = required_features | BUFFER_V1 | JSON_V1
      @library = NativeLibrary.new(library_path: library_path, required_features: required)
    end

    def request(message)
      request_bytes(JSON.generate(message))
    end

    def request_bytes(bytes)
      Response.decode(library.exchange(bytes))
    end

    def negotiate(options: {})
      request(envelope("negotiate", options))
    end

    def render(formula_model, formula_contract:, format: :svg, options: {})
      request(envelope("render", options).merge(
                formula: formula_model, formula_contract: formula_contract, output: format.to_s
              ))
    end

    # Encodes supplied bytes without loading a font or asserting its validity.
    def self.font(id:, bytes:, face_index: 0)
      raise ArgumentError, "font bytes must be a String" unless bytes.is_a?(String)

      bytes = bytes.b
      { id: id, sha256: Digest::SHA256.hexdigest(bytes), bytes_base64: [bytes].pack("m0"), face_index: face_index }
    end

    private

    def envelope(operation, options)
      { abi_version: 1, schema_version: 1, op: operation, options: options }
    end
  end
end
