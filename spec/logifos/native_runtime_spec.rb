# frozen_string_literal: true

require "logifos"

RSpec.describe Logifos::NativeRuntime, :aggregate_failures do
  let(:library_path) { ENV.fetch("LOGIFOS_LIBRARY_PATH") }
  let(:runtime) { described_class.new(library_path: library_path) }
  let(:identity) do
    { origin: "urn:test:formula", revision: "a" * 40, schema_path: "formula.json", sha256: "b" * 64 }
  end

  before do
    skip "set LOGIFOS_LIBRARY_PATH to a matching native library" unless ENV["LOGIFOS_LIBRARY_PATH"]
  end

  it "queries independent engine, ABI and schema versions" do
    expect(runtime.library).to have_attributes(abi_version: 1, schema_version: 1, engine_version: "0.1.0", features: 3)
  end

  it "negotiates transport without advertising rendering" do
    expect(runtime.negotiate).to include("kind" => "capabilities", "implemented_operations" => [], "outputs" => [])
  end

  it "refuses an explicitly required render feature" do
    expect { described_class.new(library_path: library_path, required_features: described_class::RENDER) }
      .to raise_error(Logifos::CompatibilityError, /required features/)
  end

  it "does not find a replacement for a missing explicit path" do
    expect { described_class.new(library_path: "#{library_path}.missing") }.to raise_error(Logifos::LibraryError)
  end

  it "rejects relative library paths" do
    expect { described_class.new(library_path: "engine.so") }.to raise_error(Logifos::LibraryError)
  end

  it "surfaces a typed Formula render refusal from the core" do
    expect { runtime.render({ value: "β" }, formula_contract: identity) }
      .to raise_error(Logifos::EngineError) { |e| expect([e.code, e.path, e.stage]).to eq(%w[NOT_IMPLEMENTED /op contract]) }
  end

  it "uses the native boundary from the module render entry" do
    expect { Logifos.render({}, library_path: library_path, formula_contract: identity) }
      .to raise_error(Logifos::EngineError) { |e| expect(e.code).to eq("NOT_IMPLEMENTED") }
  end

  it "retains the core PNG refusal" do
    expect { runtime.render({}, formula_contract: identity, format: :png) }
      .to raise_error(Logifos::EngineError) { |e| expect([e.code, e.path]).to eq(%w[UNSUPPORTED_OUTPUT /output]) }
  end

  it "transports MathML Unicode without character truncation" do
    message = { abi_version: 1, schema_version: 1, op: "parse", format: "mathml", source: "<math>α🌙</math>" }
    expect { runtime.request(message) }
      .to raise_error(Logifos::EngineError) { |e| expect(e.code).to eq("NOT_IMPLEMENTED") }
  end

  it "counts UTF-8 source limits in bytes" do
    message = { abi_version: 1, schema_version: 1, op: "parse", format: "mathml", source: "α",
                options: { limits: { source_bytes: 1 } } }
    expect { runtime.request(message) }
      .to raise_error(Logifos::EngineError) { |e| expect([e.code, e.path]).to eq(%w[RESOURCE_LIMIT /source]) }
  end

  { "" => "INVALID_JSON", "{" => "INVALID_JSON", "\xFF".b => "INVALID_UTF8",
    "{}\0" => "INVALID_JSON", "[]" => "INVALID_REQUEST" }.each do |bytes, code|
    it "maps #{code} for #{bytes.inspect} through the byte transport" do
      expect { runtime.request_bytes(bytes) }
        .to raise_error(Logifos::EngineError) { |e| expect(e.code).to eq(code) }
    end
  end

  it "retains version refusal details on an explicit request" do
    expect { runtime.request(abi_version: 2, schema_version: 1, op: "negotiate") }
      .to raise_error(Logifos::EngineError) { |e| expect([e.code, e.path]).to eq(%w[UNSUPPORTED_ABI /abi_version]) }
  end

  it "keeps caller options unchanged and local to the call" do
    options = { limits: { request_bytes: 512 }.freeze }.freeze
    runtime.negotiate(options: options)
    expect(runtime.negotiate.fetch("limits").fetch("request_bytes")).to eq(8_388_608)
  end

  it "lets the core reject unknown options" do
    expect { runtime.negotiate(options: { unknown: true }) }
      .to raise_error(Logifos::EngineError) { |e| expect([e.code, e.path]).to eq(%w[UNKNOWN_OPTION /options]) }
  end

  it "encodes arbitrary font bytes with their complete identity" do
    font = described_class.font(id: "Primary", bytes: "\0\xFFβ".b, face_index: 2)
    expect(font).to eq(id: "Primary", bytes_base64: "AP/Osg==",
                       sha256: Digest::SHA256.hexdigest("\0\xFFβ".b), face_index: 2)
  end

  it "sends per-call font resources and preserves the core's refusal" do
    font = described_class.font(id: "Primary", bytes: "\0\xFF".b).freeze
    options = { fonts: [font].freeze, fallback_order: ["Primary"].freeze }.freeze
    expect { runtime.render({}, formula_contract: identity, options: options) }
      .to raise_error(Logifos::EngineError) { |e| expect([e.code, e.path]).to eq(%w[NOT_IMPLEMENTED /options/fonts]) }
  end

  def repeat_requests(other)
    1000.times do
      runtime.negotiate
      begin
        other.request_bytes("\xFF".b)
      rescue Logifos::EngineError => e
        raise unless e.code == "INVALID_UTF8"
      end
    end
  end

  it "reuses independent contexts after repeated success and refusal frees" do
    other = described_class.new(library_path: library_path)
    repeat_requests(other)
    expect(other.negotiate.fetch("kind")).to eq("capabilities")
  end
end
