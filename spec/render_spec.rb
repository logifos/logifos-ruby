# frozen_string_literal: true

require "logifos"

RSpec.describe Logifos do
  it "refuses to render until the engine boundary lands" do
    expect { described_class.render({}) }
      .to raise_error(NotImplementedError, /engine boundary lands in P4/)
  end
end
