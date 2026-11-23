# logifos-ruby

logifos-ruby connects Ruby to the Logifos Rust engine through its portable native
ABI. It is unreleased. Native transport and negotiation work; layout, SVG
rendering and PNG conversion remain unavailable.

## Native runtime

Ruby 3.2 or later, the `ffi` and `json` gems, and an explicitly selected matching
shared library are required. The gem does not bundle, download or discover an
engine. No alternative rendering engine or automatic fallback is provided.

```ruby
require "logifos"

runtime = Logifos::NativeRuntime.new(
  library_path: ENV.fetch("LOGIFOS_LIBRARY_PATH")
)
capabilities = runtime.negotiate
puts capabilities.fetch("implemented_operations") # Currently empty.
puts runtime.library.engine_version
```

`library_path` must be an absolute path to a readable library. Each runtime binds
its own library context and checks ABI 1, schema 1, and the buffer/JSON feature
bits before requests. Unknown feature bits are ignored. The package version is
independent of these wire versions. Set `required_features:` to demand additional
feature bits, such as `Logifos::NativeRuntime::RENDER`; the current core refuses
that requirement because it does not advertise rendering.

`runtime.request(hash)` serializes an explicit wire request;
`runtime.request_bytes(string)` sends exactly the supplied JSON bytes, including
embedded NULs and invalid UTF-8, for core validation. Both return the response's
`result` hash on success. Responses are copied using their exact lengths and
freed once through the library that allocated them, before Ruby decodes JSON.
No native buffer escapes to the caller.

## Rendering and per-call fonts

`runtime.render(formula, formula_contract:, format: :svg, options: {})` sends a
render request to the same core. The contract identity must come from the
caller's pinned Formula schema; the wrapper does not invent one. The current
core returns a typed `NOT_IMPLEMENTED` refusal for a well-formed SVG request.
It returns `UNSUPPORTED_OUTPUT` for PNG. No successful SVG bytes or metrics are
available yet. A MathML parse request likewise receives `NOT_IMPLEMENTED`.

`Logifos.render` accepts the same arguments plus the required `library_path:`
keyword. Retain a `NativeRuntime` for repeated calls.

Fonts and options belong to each call. To encode caller-owned bytes:

```ruby
font = Logifos::NativeRuntime.font(id: "Primary", bytes: supplied_bytes, face_index: 0)
options = { fonts: [font], fallback_order: ["Primary"], font_size_px: 18 }
```

The helper computes SHA-256 and canonical base64 without validating font data.
Pass the options to `render(..., options: options)` or another wire request.
The current core refuses nonempty font resources with `NOT_IMPLEMENTED` at
`/options/fonts`; it does not yet validate fonts. No host fonts, resource paths,
global font mutation or implicit defaults are used by the wrapper. Caller
options are serialized without mutation and do not affect later calls.

Core refusals raise `Logifos::EngineError`, preserving `code`, `path`, `stage`
and the diagnostic message. Library loading raises `LibraryError`; version or
feature mismatches raise `CompatibilityError`. Transport failures raise
`TransportError` with numeric `status` and symbolic `code`. Malformed response
envelopes raise `ProtocolError`. These all inherit from `Logifos::Error` and can
be rescued normally. Diagnostic messages are not stable API strings.

## Development and focused checks

```sh
bundle install
bundle exec rspec spec/render_spec.rb spec/logifos spec/package_smoke_spec.rb
bundle exec rubocop
bundle exec rake docs:lint
```

Set `LOGIFOS_LIBRARY_PATH` to the absolute path of a matching native candidate to
run native integration cases. Without it, those cases are explicitly skipped;
unit and package checks still run. The package checks build and install a gem
in temporary storage, load it outside the checkout, and repeat the native cases
against the installed package when a library is supplied. Development dependencies
must already be installed; package installation is offline and reuses them.
The native cases cover negotiation, UTF-8 byte limits, binary font transport,
bad input, typed refusals, independent contexts and repeated allocation/free.
They establish transport behavior, not rendering correctness or platform support.

Bundler creates a local `Gemfile.lock`. Do not commit it. The gem builds no native
extension, and there is no publishing automation.

## Releases and migrations

No version has been released. `Logifos::VERSION` is `0.1.0`; it is not a release
announcement. Changes are recorded under Unreleased in [HISTORY.txt](HISTORY.txt).
The earlier placeholder render entry now requires an explicit library path and
Formula contract and raises structured runtime errors through the native ABI.
There are no release-to-release migrations yet.

## License

MIT; see [LICENSE.txt](LICENSE.txt).
