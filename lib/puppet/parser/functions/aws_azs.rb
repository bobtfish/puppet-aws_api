require 'puppetx/bobtfish/aws_api'
module Puppet::Parser::Functions
  newfunction(:aws_azs) do |region_name|
    Puppetx::Bobtfish::Aws_api.ec2.regions[region_name.first].availability_zones.collect(&:name)
  end
end
