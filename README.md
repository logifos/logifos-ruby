# logifos-ruby

logifos-ruby is the Ruby entry point for a planned math formula renderer.
It is currently an unreleased bootstrap, not a working renderer.

## Current status

The gem can be built, installed and loaded with `require "logifos"`. It exposes
`Logifos::VERSION`, currently `0.1.0`, and a `Logifos.render` entry point. Ruby
3.2 or later is required. The package has no runtime dependencies or native
extension.

Every call to `Logifos.render` raises `NotImplementedError`, including calls
requesting SVG or PNG. Formula input handling, layout, SVG output, font loading
and PNG conversion are not implemented. The current tests check the refusal to
render and the installed package's contents, metadata, license and load path;
they do not establish rendering correctness.

## Planned runtimes

The intended input is a formula model from Plurimath, with SVG or PNG bytes as
the eventual output from the logifos Rust engine.

The native Ruby extension is planned as the main route to that engine. A
portable shared-library runtime is planned as an alternative where the native
extension cannot be used. Both are intended to use the same Rust rendering
engine. Neither runtime, its loader nor the engine integration is included in
this bootstrap. Runtime selection and platform support are still future work.

## Install for development

There is no released gem to install. Work from this checkout, with Ruby 3.2 or
later and Bundler:

```sh
bundle install
```

This installs development dependencies and makes the local gem available through
Bundler. It does not install a rendering engine or compile a native extension.

## Tests and documentation checks

Run the source spec, installed-package smoke specs and documentation whitespace
check:

```sh
bundle exec rspec spec/render_spec.rb
bundle exec rspec spec/package_smoke_spec.rb
bundle exec rake docs:lint
```

The package smoke specs build the gem, install it into a temporary gem directory
and load it from outside the checkout. They also check that installed rendering
calls fail explicitly. Temporary package files are removed after the checks.

Bundler creates a local `Gemfile.lock`. Do not commit it.

## Releases and migrations

No version has been released. The `0.1.0` version constant identifies the
bootstrap; it is not a release announcement. Changes are recorded under
Unreleased in [HISTORY.txt](HISTORY.txt).

There are no release-to-release migrations yet, so there is no migration guide.
When a released API changes incompatibly, document the affected versions and
upgrade steps alongside the release history.

## License

MIT; see [LICENSE.txt](LICENSE.txt).
