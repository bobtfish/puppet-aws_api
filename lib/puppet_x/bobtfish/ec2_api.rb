require 'rubygems'
require 'aws'

module Puppet_X
  module Bobtfish
  end
end

class Puppet_X::Bobtfish::Ec2_api < Puppet::Provider
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

  def wait_until_state(item, state)
    sleep 1 until item.state == state
  end

  def tag_with_name(item, name)
    item.add_tag 'Name', :value => name
  end

  def self.ec2
    AWS::EC2.new('access_key_id' => (ENV['AWS_ACCESS_KEY_ID']||ENV['AWS_ACCESS_KEY']), 'secret_access_key' => (ENV['AWS_SECRET_ACCESS_KEY']||ENV['AWS_SECRET_KEY']))
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

