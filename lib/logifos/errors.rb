# frozen_string_literal: true

module Logifos
  # Base for recoverable runtime failures.
  class Error < StandardError; end

  # The explicitly requested library could not be loaded.
  class LibraryError < Error; end

  # The library does not support the required wire versions or features.
  class CompatibilityError < LibraryError; end

  # A library returned an invalid response envelope.
  class ProtocolError < Error; end

  # A native call failed before producing a JSON response.
  class TransportError < Error
    CODES = { 1 => "INVALID_REQUEST", 2 => "ALLOCATION_FAILED", 3 => "INTERNAL_ERROR" }.freeze

    attr_reader :status, :code

    def initialize(status)
      @status = status
      @code = CODES.fetch(status, "UNKNOWN_TRANSPORT_STATUS")
      super("native transport failed: #{@code} (#{status})")
    end
  end

  # A typed refusal returned by the core; diagnostic text is not a stable API.
  class EngineError < Error
    attr_reader :code, :path, :stage

    def initialize(code:, message:, path:, stage:)
      @code = code
      @path = path
      @stage = stage
      super(message)
    end
  end
end
