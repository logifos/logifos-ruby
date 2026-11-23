# frozen_string_literal: true

require "json"
require_relative "errors"

module Logifos
  # Checks the wire envelope before exposing a result or typed core refusal.
  module Response
    def self.decode(bytes)
      raise ProtocolError, "native response is not UTF-8" unless bytes.valid_encoding?

      envelope = JSON.parse(bytes)
      validate_envelope(envelope)
      return envelope.fetch("result") if envelope["ok"]

      error = envelope.fetch("error")
      raise EngineError.new(**error.transform_keys(&:to_sym))
    rescue JSON::ParserError
      raise ProtocolError, "native response is not valid JSON"
    end

    def self.validate_envelope(envelope)
      validate_versions(envelope)
      field = if envelope["ok"] == true && envelope["result"].is_a?(Hash)
                "result"
              elsif envelope["ok"] == false && valid_error?(envelope["error"])
                "error"
              end
      return if field && envelope.keys.sort == ["abi_version", "schema_version", "ok", field].sort

      raise ProtocolError, "native response has an invalid envelope"
    end

    def self.validate_versions(envelope)
      return if envelope.is_a?(Hash) && envelope.values_at("abi_version", "schema_version").all? { |v| v.eql?(1) }

      raise CompatibilityError, "native response has incompatible versions"
    end

    def self.valid_error?(error)
      fields = %w[code message path stage]
      error.is_a?(Hash) && error.keys.sort == fields && error.values.all?(String)
    end
    private_class_method :validate_envelope, :validate_versions, :valid_error?
  end
end
