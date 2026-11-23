# frozen_string_literal: true

require "digest"
require "fileutils"
require "open3"
require "rbconfig"
require "rubygems/package"
require "tmpdir"

RSpec.describe "the installed bootstrap gem" do
  PACKAGE_FILES = %w[
    LICENSE.txt README.md lib/logifos.rb lib/logifos/version.rb
  ].freeze
  LICENSE_SHA256 =
    "2d0f8a412f45f64d0e2bba4f9592907371613f219fe01f2e7a88c0381a672d07"

  def run_ruby(*arguments, directory:, gem_home:)
    environment = {
      "PATH" => ENV.fetch("PATH"),
      "TMPDIR" => @scratch,
      "GEM_HOME" => gem_home,
      "GEM_PATH" => gem_home
    }
    output, error, status = Open3.capture3(
      environment, RbConfig.ruby, *arguments,
      chdir: directory, unsetenv_others: true
    )
    raise "Ruby command failed (#{status.exitstatus}): #{output}#{error}" unless status.success?

    output
  end

  before(:context) do
    @checkout = File.expand_path("..", __dir__)
    @scratch = Dir.mktmpdir("logifos-package-", ENV.fetch("TMPDIR", Dir.tmpdir))
    @gem_home = File.join(@scratch, "gems")
    @consumer = File.join(@scratch, "consumer")
    @artifact = File.join(@scratch, "logifos.gem")
    FileUtils.mkdir_p([@gem_home, @consumer])
    raise "consumer directory must be outside the checkout" if @consumer.start_with?("#{@checkout}/")

    gem_command = File.join(RbConfig::CONFIG.fetch("bindir"), "gem")
    run_ruby(gem_command, "build", "logifos.gemspec", "--output", @artifact,
             directory: @checkout, gem_home: @gem_home)
    run_ruby(gem_command, "install", "--local", @artifact, "--no-document",
             "--install-dir", @gem_home,
             directory: @consumer, gem_home: @gem_home)
    @package = Gem::Package.new(@artifact)
    @specification = @package.spec
    @installed = File.join(@gem_home, "gems", @specification.full_name)
  end

  after(:context) do
    FileUtils.remove_entry(@scratch) if @scratch && File.directory?(@scratch)
  end

  it "ships exactly the public Ruby files and notices" do
    expect(@package.contents.sort).to eq(PACKAGE_FILES.sort)
  end

  it "retains the package identity, Ruby minimum and pure Ruby boundary" do
    expect(@specification.name).to eq("logifos")
    expect(@specification.version.to_s).to eq("0.1.0")
    expect(@specification.required_ruby_version.to_s).to eq(">= 3.2.0")
    expect(@specification.licenses).to eq(["MIT"])
    expect(@specification.extensions).to be_empty
    expect(@specification.runtime_dependencies).to be_empty
  end

  it "installs the unchanged MIT notice" do
    expect(Digest::SHA256.file(File.join(@installed, "LICENSE.txt")).hexdigest)
      .to eq(LICENSE_SHA256)
  end

  it "loads by gem name outside the checkout with the packaged version" do
    output = run_ruby("-e", <<~'RUBY', directory: @consumer, gem_home: @gem_home)
      require "logifos"
      specification = Gem.loaded_specs.fetch("logifos")
      expected = File.join(ENV.fetch("GEM_HOME"), "gems", specification.full_name)
      abort "loaded a different gem" unless specification.full_gem_path == expected
      loaded = $LOADED_FEATURES.find { |path| path.end_with?("/lib/logifos.rb") }
      abort "loaded source outside the installed gem" unless loaded == File.join(expected, "lib/logifos.rb")
      abort "version mismatch" unless Logifos::VERSION == specification.version.to_s
      puts Logifos::VERSION
    RUBY
    expect(output.strip).to eq("0.1.0")
  end

  [:default, :svg, :png].each do |format|
    call = format == :default ? "Logifos.render({})" : "Logifos.render({}, format: :#{format})"
    expected_format = format == :default ? :svg : format
    it "explicitly refuses #{format} rendering from the installed gem" do
      output = run_ruby("-e", <<~RUBY, directory: @consumer, gem_home: @gem_home)
        require "logifos"
        begin
          #{call}
        rescue NotImplementedError => error
          abort "unexpected refusal" unless error.message ==
            'the logifos engine boundary lands in P4 (got :#{expected_format})'
          puts "refused #{format}"
        else
          abort "bootstrap unexpectedly rendered"
        end
      RUBY
      expect(output.strip).to eq("refused #{format}")
    end
  end
end
