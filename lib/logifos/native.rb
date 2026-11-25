# frozen_string_literal: true

require "fiddle"
require "rbconfig"

module Logifos
  module Native
    # Platform suffixes for the packaged engine artifact.
    SUFFIXES = { "darwin" => "dylib", "linux" => "so", "mingw" => "dll" }.freeze

    # The ABI this binding speaks. The packaged artifact must report the same
    # value through logifos_abi_version before any call is bound.
    REQUIRED_ABI_VERSION = 1

    module_function

    def load
      Library.new
    end

    def packaged_library_path
      platform = Gem::Platform.local
      suffix = SUFFIXES.fetch(platform.os)
      File.join(File.realpath(__dir__), "native", platform.to_s, "logifos.#{suffix}")
    end

    # Opens only the packaged engine artifact and binds the versioned request
    # surface. Loading never probes system libraries or network resources.
    class Library
      attr_reader :abi_version, :schema_version, :features, :engine_version

      def initialize
        path = Native.packaged_library_path
        raise UnsupportedPlatformError, "no packaged logifos engine at #{path}" unless File.file?(path)

        @handle = Fiddle::Handle.new(path, Fiddle::RTLD_NOW)
        @abi_version = symbol("logifos_abi_version", [], Fiddle::TYPE_INT).call
        unless @abi_version == REQUIRED_ABI_VERSION
          raise AbiMismatchError,
                "packaged engine reports ABI #{@abi_version}, binding requires #{REQUIRED_ABI_VERSION}"
        end
        @schema_version = symbol("logifos_schema_version", [], Fiddle::TYPE_INT).call
        @features = symbol("logifos_features", [], Fiddle::TYPE_LONG_LONG).call
        @engine_version = string_symbol("logifos_engine_version").call
        @request = symbol(
          "logifos_request_json",
          [Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T],
          Fiddle::TYPE_VOIDP,
        )
        @string_free = symbol("logifos_string_free", [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
      end

      # Sends one JSON request and returns the JSON reply as UTF-8. The reply
      # is the versioned envelope: ok with result, or error with a code.
      def request_json(request)
        bytes = +request.b
        pointer = Fiddle::Pointer[bytes]
        reply = @request.call(pointer.to_i, bytes.bytesize)
        raise EngineError, "the engine returned a null reply" if reply.null?

        begin
          Fiddle::Pointer.new(reply).to_s
        ensure
          @string_free.call(reply)
        end
      end

      private

      def symbol(name, arguments, returns)
        Fiddle::Function.new(@handle[name.to_s], arguments, returns)
      end

      def string_symbol(name)
        Fiddle::Function.new(@handle[name.to_s], [], Fiddle::TYPE_VOIDP)
      end
    end
  end
end
