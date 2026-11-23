# frozen_string_literal: true

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

namespace :docs do
  desc "Check documentation for trailing whitespace and final newlines"
  task :lint do
    files = FileList["*.md", "*.txt", "docs/**/*.{md,txt,adoc}"]
    errors = files.flat_map do |path|
      content = File.read(path)
      issues = content.lines.each_with_index.filter_map do |line, index|
        "#{path}:#{index + 1}: trailing whitespace" if line.chomp.match?(/[\t ]$/)
      end
      issues << "#{path}: missing final newline" unless content.empty? || content.end_with?("\n")
      issues
    end
    abort errors.join("\n") unless errors.empty?
  end
end

task default: :spec
