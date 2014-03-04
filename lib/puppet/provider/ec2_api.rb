require 'rubygems'
require 'aws'

class Puppet::Provider::Ec2_api < Puppet::Provider
  desc "Helper for Providers which use the EC2 API"
  self.initvars

  def self.instances
    raise NotImplementedError
  end

  def self.prefetch(resources)
    instances.each do |provider|
      if resource = resources[provider.name] then
        resource.provider = provider
      end
    end
  end

  def self.ec2
    ec2 = AWS::EC2.new('access_key_id' => (ENV['AWS_ACCESS_KEY_ID']||ENV['AWS_ACCESS_KEY']), 'secret_access_key' => (ENV['AWS_SECRET_ACCESS_KEY']||ENV['AWS_SECRET_KEY']))
    ec2
  end

  def ec2
    self.class.ec2
  end

  def self.regions
    ec2.regions.collect { |r| r.name }
  end

  def regions
    self.class.regions
  end

  def flush
    raise NotImplementedError
  end
end
