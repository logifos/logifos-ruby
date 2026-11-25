# frozen_string_literal: true

require "logifos"

RSpec.describe Logifos::NativeRuntime do
  let(:library_path) do
    ENV.fetch("LOGIFOS_LIBRARY_PATH") do
      committed = File.expand_path("../../lib/logifos/native/#{Gem::Platform.local}/logifos.dylib", __dir__)
      committed if File.file?(committed)
    end
  end
  let(:font_path) do
    ENV.fetch("LOGIFOS_FONT") do
      sibling = File.expand_path("../../../logifos-rs/corpus/fonts/stix-two-math/STIXTwoMath-Regular.ttf", __dir__)
      sibling if File.file?(sibling)
    end
  end

  before do
    skip "no logifos native library available (set LOGIFOS_LIBRARY_PATH)" unless library_path
    skip "no grading font available (set LOGIFOS_FONT)" unless font_path
  end

  it "requires font bytes to be a String" do
    expect { described_class.font(id: "stix", bytes: 42) }.to raise_error(ArgumentError, /String/)
  end

  it "renders a MathML document end to end with the caller's fonts" do
    runtime = described_class.new(library_path: library_path)
    fonts = [described_class.font(id: "stix", bytes: File.binread(font_path))]
    result = runtime.render_mathml("<math><mi>x</mi></math>", fonts: fonts)

    expect(result).to include("svg" => a_string_including("<svg", "viewBox"))
  end

  it "raises the typed core refusal when the MathML is invalid" do
    runtime = described_class.new(library_path: library_path)
    fonts = [described_class.font(id: "stix", bytes: File.binread(font_path))]

    expect { runtime.render_mathml("<math><mi>x</mi>", fonts: fonts) }
      .to raise_error(Logifos::EngineError)
  end
end
