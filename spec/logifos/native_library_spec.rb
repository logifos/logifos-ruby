# frozen_string_literal: true

require "logifos"

RSpec.describe Logifos::NativeLibrary, :aggregate_failures do
  let(:api) do
    # Query and transport methods are bound dynamically from the loaded ABI.
    # rubocop:disable-next RSpec/VerifiedDoubles
    double("ABI", logifos_abi_version: 1, logifos_schema_version: 1,
                  logifos_engine_version: "9.0.0", logifos_features: 3)
  end
  let(:library) { described_class.allocate }

  before do
    allow(library).to receive(:bind_library).and_return(api)
  end

  def initialize_library
    library.send(:initialize, library_path: File.expand_path(__FILE__), required_features: 3)
  end

  { logifos_abi_version: 2, logifos_schema_version: 2, logifos_features: 1 }.each do |query, value|
    it "rejects incompatible #{query} before calling transport" do
      allow(api).to receive(query).and_return(value)
      expect { initialize_library }.to raise_error(Logifos::CompatibilityError)
    end
  end

  it "ignores unrequested feature bits" do
    allow(api).to receive(:logifos_features).and_return(3 | (1 << 63))
    expect { initialize_library }.not_to raise_error
  end

  it "maps a load failure without another library attempt" do
    allow(library).to receive(:bind_library).and_raise(LoadError, "invalid library")
    expect { initialize_library }.to raise_error(Logifos::LibraryError, /invalid library/)
  end

  { 1 => "INVALID_REQUEST", 2 => "ALLOCATION_FAILED", 3 => "INTERNAL_ERROR",
    99 => "UNKNOWN_TRANSPORT_STATUS" }.each do |status, code|
    it "surfaces transport status #{status} without reading a response" do
      initialize_library
      allow(api).to receive(:logifos_request_v1).and_return(status)
      allow(api).to receive(:logifos_buffer_free_v1)
      expect { library.exchange("{}") }
        .to raise_error(Logifos::TransportError) { |e| expect(e).to have_attributes(status: status, code: code) }
    end
  end

  def check_input(input, length)
    raise "truncated input" unless input.read_string(length) == "α\0β".b
  end

  def supply_response
    owned = FFI::MemoryPointer.from_string("reply\0tail")
    allow(api).to receive(:logifos_request_v1) do |input, length, out|
      check_input(input, length)

      out[:ptr] = owned
      out[:len] = 10
      0
    end
    allow(api).to receive(:logifos_buffer_free_v1) do |out|
      raise "changed allocation" unless [out[:ptr], out[:len]] == [owned, 10]
    end
  end

  it "frees the response before JSON decoding can fail" do
    initialize_library
    supply_response
    expect { Logifos::Response.decode(library.exchange("α\0β")) }.to raise_error(Logifos::ProtocolError)
    expect(api).to have_received(:logifos_buffer_free_v1).once
  end

  it "copies the exact response length and frees through the allocating context once" do
    initialize_library
    supply_response
    result = library.exchange("α\0β")
    expect([result, result.encoding]).to eq(["reply\0tail", Encoding::UTF_8])
    expect(api).to have_received(:logifos_buffer_free_v1).once
  end
end
