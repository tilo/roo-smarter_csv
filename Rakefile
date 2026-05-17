# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "shellwords"

RSpec::Core::RakeTask.new(:spec)

RUBOCOP_ARGS = begin
  rubocop_index = ARGV.index("rubocop")
  rubocop_index ? ARGV[(rubocop_index + 1)..] || [] : []
end

RUBOCOP_ARGS.each do |arg|
  task arg do
  end
end

desc "Run RuboCop; extra args after 'rubocop' are passed through"
task :rubocop do
  sh(["bundle", "exec", "rubocop", *RUBOCOP_ARGS].shelljoin)
end

task default: %i[spec]
