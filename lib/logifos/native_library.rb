# frozen_string_literal: true

require "ffi"
require_relative "errors"

module Logifos
  # The ABI's owned, length-delimited response. Only its allocator may free it.
  class NativeBuffer < FFI::Struct
    layout :ptr, :pointer, :len, :size_t
  end

  # One loaded library owns both the allocation and free function for each call.
  class NativeLibrary
    QUERY_TYPES = { abi_version: :uint32, schema_version: :uint32, features: :uint64, engine_version: :string }.freeze

    attr_reader :library_path, :abi_version, :schema_version, :engine_version, :features

    def initialize(library_path:, required_features:)
      validate_path(library_path)
      @library_path = library_path.dup.freeze
      @api = bind_library
      @abi_version = @api.logifos_abi_version
      @schema_version = @api.logifos_schema_version
      @engine_version = @api.logifos_engine_version.dup.freeze
      @features = @api.logifos_features
      check_compatibility(required_features)
    rescue LoadError, FFI::NotFoundError => e
      raise LibraryError, "cannot load requested native library: #{e.message}"
    end

    def exchange(bytes)
      raise ArgumentError, "request bytes must be a String" unless bytes.is_a?(String)

      bytes = bytes.b
      input = FFI::MemoryPointer.new(:uint8, [bytes.bytesize, 1].max)
      input.put_bytes(0, bytes)
      exchange_buffer(input, bytes.bytesize)
    ensure
      input&.free
    end

    private

    def validate_path(path)
      return if path.is_a?(String) && File.absolute_path(path) == path && File.file?(path) && File.readable?(path)

      raise LibraryError, "library_path must name a readable library by absolute path"
    end

    def bind_library
      path = library_path
      Module.new do
        extend FFI::Library

        ffi_lib path
        QUERY_TYPES.each do |name, type|
          attach_function :"logifos_#{name}", [], type
        end
        attach_function :logifos_request_v1, %i[pointer size_t pointer], :uint32
        attach_function :logifos_buffer_free_v1, [NativeBuffer.by_value], :void
      end
    end

    def check_compatibility(required)
      raise CompatibilityError, "unsupported ABI version: #{abi_version}" unless abi_version == 1
      raise CompatibilityError, "unsupported schema version: #{schema_version}" unless schema_version == 1
      return if features & required == required

      raise CompatibilityError, "native library lacks required features: #{required}"
    end

    def release(buffer)
      @api.logifos_buffer_free_v1(buffer)
      buffer[:ptr] = FFI::Pointer::NULL
      buffer[:len] = 0
    end

    def exchange_buffer(input, length)
      buffer = NativeBuffer.new
      begin
        status = @api.logifos_request_v1(input, length, buffer)
        raise TransportError, status unless status.zero?
        raise ProtocolError, "native library returned a null response" if buffer[:ptr].null?

        buffer[:ptr].read_string(buffer[:len]).force_encoding(Encoding::UTF_8)
      ensure
        release(buffer)
      end
    end
  end
end
