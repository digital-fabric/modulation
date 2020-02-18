# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake"
require 'rake/testtask'

task :default => :test
task :test do
  Dir.glob('./test/test_*.rb').each { |file| require file }
end
