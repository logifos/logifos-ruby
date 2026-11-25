# frozen_string_literal: true

module Logifos
  # The packaged engine artifact is missing for this platform.
  class UnsupportedPlatformError < StandardError; end

  # The packaged engine reports a different ABI than this binding speaks.
  class AbiMismatchError < StandardError; end

  # The engine returned a malformed transport reply.
  class EngineError < StandardError; end
end
