# frozen_string_literal: true

require "logifos"

RSpec.describe Logifos do
  it "requires an explicit library and external contract" do
    expect { described_class.render({}) }.to raise_error(ArgumentError, /library_path/)
  end
end
