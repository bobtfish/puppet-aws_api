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

  def tags=(newtags)
    newtags.each { |k,v| @property_hash[:aws_item].add_tag(k, :value => v) }
    @property_hash[:tags] = newtags
  end

  def find_vpc_item_by_name(name)
    regions.map do |region_name|
      ec2.regions[region_name].vpcs.find do |vpc|
        vpc_name = vpc.tags.to_h['Name'] || vpc.vpc_id
        vpc_name == name
      end
    end.reject { |i| i.nil? }[0]
  end

  def find_region_name_for_vpc_name(name)
    regions.find do |region_name|
      ec2.regions[region_name].vpcs.find do |vpc|
        vpc_name = vpc.tags.to_h['Name'] || vpc.vpc_id
        vpc_name == name
      end
    end
  end

  def flush
  end
end

