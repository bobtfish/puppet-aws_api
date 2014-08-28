#require 'puppetlabs_spec_helper/rake_tasks'
require 'rspec/core/rake_task'
require 'puppet-lint/tasks/puppet-lint'
require 'puppet-syntax/tasks/puppet-syntax'

# These two gems aren't always present, for instance
# on Travis with --without development
begin
  require 'puppet_blacksmith/rake_tasks'
rescue LoadError
end

PuppetLint.configuration.send("disable_80chars")
PuppetLint.configuration.log_format = "%{path}:%{linenumber}:%{check}:%{KIND}:%{message}"
PuppetLint.configuration.fail_on_warnings = true

# Forsake support for Puppet 2.6.2 for the benefit of cleaner code.
# http://puppet-lint.com/checks/class_parameter_defaults/
PuppetLint.configuration.send('disable_class_parameter_defaults')
# http://puppet-lint.com/checks/class_inherits_from_params_class/
PuppetLint.configuration.send('disable_class_inherits_from_params_class')

exclude_paths = [
  "pkg/**/*",
  "vendor/**/*",
  "spec/**/*",
]
PuppetLint.configuration.ignore_paths = exclude_paths
PuppetSyntax.exclude_paths = exclude_paths

desc "Run acceptance tests"
RSpec::Core::RakeTask.new(:acceptance) do |t|
  t.pattern = 'spec/acceptance'
end
RSpec::Core::RakeTask.new(:spec)

desc "Run syntax, lint, and spec tests."
task :test => [
  :syntax,
  :lint,
  :spec,
  'test:smoke',
]

task :default => :test

namespace :test do
  smoke_tests = FileList['tests/*.pp'].map do |source|
    task "smoke:#{File.basename(source, '.*')}" do
      opts = %w(--noop --modulepath=..)
      unless verbose.nil?
        opts << '--test'
      end
      if verbose
        opts << '--debug'
      end
      sh "puppet apply #{opts.join(' ')}  #{source}"
    end
  end

  desc "Execute the smoke tests"
  task :smoke => smoke_tests
end

