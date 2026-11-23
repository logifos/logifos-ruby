# frozen_string_literal: true

require "logifos"

RSpec.describe Logifos::Response, :aggregate_failures do
  ["{", "\xFF".b.force_encoding(Encoding::UTF_8), "[]", '{"abi_version":2,"schema_version":1,"ok":true,"result":{}}',
   '{"abi_version":1.0,"schema_version":1,"ok":true,"result":{}}',
   '{"abi_version":1,"schema_version":1,"ok":true,"result":{},"error":{}}',
   '{"abi_version":1,"schema_version":1,"ok":false,"error":{}}'].each do |bytes|
    it "rejects malformed or incompatible response #{bytes}" do
      expect { described_class.decode(bytes) }.to raise_error(Logifos::Error)
    end
  end
end
