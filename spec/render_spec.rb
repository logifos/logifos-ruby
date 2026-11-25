# frozen_string_literal: true

require "logifos"
require "digest"
require "base64"

RSpec.describe Logifos do
  # The packaged engine artifact must be materialized at
  # lib/logifos/native/<target>/logifos.dylib for these examples.
  let(:mathml) { "<math><mi>x</mi><mo>+</mo><mn>1</mn></math>" }

  # Rendering needs a real MATH-table face; the examples below use the
  # locally installed STIX Two Math and skip where it is absent. A pinned
  # grading font ships with the packaging batch.
  has_font = File.file?(File.expand_path("~/.fontist/fonts/STIXTwoMath-Regular.otf")) ||
             ENV["LOGIFOS_FONT"]
  let(:font_path) do
    ENV.fetch("LOGIFOS_FONT") do
      File.expand_path("~/.fontist/fonts/STIXTwoMath-Regular.otf")
    end
  end

  it "negotiates capabilities through the packaged engine" do
    capabilities = described_class.capabilities
    expect(capabilities["implemented_operations"])
      .to include("negotiate", "parse", "render")
    expect(capabilities["outputs"]).to include("svg")
    expect(capabilities["formula_contract"]["origin"]).to include("plurimath-rs")
  end

  it "parses MathML into the wire formula model" do
    reply = described_class.parse(mathml)
    expect(reply["ok"]).to be(true)
    expect(reply["result"]["model"]["class"]).to eq("Math::Formula")
    expect(reply["result"]["formula_contract"]["sha256"]).to match(/\A[0-9a-f]{64}\z/)
  end

  it "raises typed request errors from the reply envelope" do
    expect { described_class.parse("") }
      .to raise_error(Logifos::RequestError, /INVALID_/)
  end

  it "raises a typed error for an unknown operation", :aggregate_failures do
    request = JSON.generate(
      abi_version: 1, schema_version: 1, op: "no-such-op",
    )
    reply = Logifos::Native.load.request_json(request)
    expect(JSON.parse(reply)["error"]["code"]).to eq("INVALID_REQUEST")
  end

  context "with a locally available MATH face",
          if: File.file?(File.expand_path("~/.fontist/fonts/STIXTwoMath-Regular.otf")) ||
            ENV["LOGIFOS_FONT"] do
    it "renders deterministic SVG through a packaged font" do
      svg = described_class.render_svg(
        mathml,
        font: {
          id: "grading",
          sha256: Digest::SHA256.hexdigest(File.binread(font_path)),
          bytes_base64: Base64.strict_encode64(File.binread(font_path)),
          face_index: 0,
        },
      )
      expect(svg).to start_with("<svg")
      expect(svg).to include("<path")
      expect(svg).to end_with("</svg>")
    end
  end
end
