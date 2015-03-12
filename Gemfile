source "http://rubygems.org"

gem 'nokogiri', '~> 1.5.11'
gem 'aws-sdk', '1.55.0'

group :test do
  gem "rake"
  gem "puppet", ENV['PUPPET_VERSION'] || '~> 3.6.2'
  gem "puppet-lint"
  gem "rspec-puppet", :git => 'https://github.com/rodjek/rspec-puppet.git'
  gem "puppet-syntax"
  gem "puppetlabs_spec_helper"
end

group :development do
  gem "travis"
#  gem "travis-lint"
#  gem "vagrant-wrapper"
  gem "puppet-blacksmith"
#  gem "guard-rake"
end

