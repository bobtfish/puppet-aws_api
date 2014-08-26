require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'aws_api.rb'))
module Puppet::Parser::Functions
  newfunction(:aws_azs) do |region_name|
    Puppet_X::Bobtfish::Aws_api.ec2.regions[region_name.first].availability_zones.collect(&:name)
  end
end
