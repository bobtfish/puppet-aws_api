require 'rubygems'
require 'puppet'

module Puppet_X
  module Bobtfish
  end
end

class Puppet_X::Bobtfish::Ec2_api < Puppet::Provider
  HAVE_AWS_SDK = begin; require 'aws-sdk'; true; rescue Exception; false; end

  confine :true => HAVE_AWS_SDK

  desc "Helper for Providers which use the EC2 API"
  self.initvars

  def self.instances
    raise NotImplementedError
  end

  def self.prefetch(resources)
    all_instances = if method(:instances).arity > 0
      # This is so hacky, I am so sorry
      instances(resources)
    else
      instances
    end
    all_instances.each do |provider|
      if resource = resources[provider.name] then
        resource.provider = provider
      end
    end
  end

  def self.name_or_id(item)
    return unless item
    item.tags.to_h['Name'] || item.id
  end
  def name_or_id(item)
    self.class.name_or_id(item)
  end

  def wait_until_status(item, status)
    sleep 1 until item.status == status
  end

  def wait_until_state(item, state)
    sleep 1 until item.state == state
  end

  def tag_with_name(item, name)
    item.add_tag 'Name', :value => name
  end

  def get_creds
    self.class.default_creds
  end

  def self.default_creds
    {
      :access_key_id => (ENV['AWS_ACCESS_KEY_ID']||ENV['AWS_ACCESS_KEY']), 
      :secret_access_key => (ENV['AWS_SECRET_ACCESS_KEY']||ENV['AWS_SECRET_KEY'])
    }
  end

  def self.amazon_thing(which)
    which.new
  end

  def self.iam()
    amazon_thing(AWS::IAM)
  end
  def iam
    self.class.iam()
  end

  def self.ec2()
    amazon_thing(AWS::EC2)
  end
  def ec2
    self.class.ec2()
  end

  def self.regions
    @@regions ||= begin
      if HAVE_AWS_SDK
        ec2.regions.collect { |r| r.name }
      else
        []
      end
    end
  end

  def regions
    self.class.regions()
  end

  def tags=(newtags)
    newtags.each { |k,v| @property_hash[:aws_item].add_tag(k, :value => v) }
    @property_hash[:tags] = newtags
  end

  def self.find_dhopts_item_by_name(name)
    @@dhoptions ||= begin
      regions.collect do |region_name|
        ec2.regions[region_name].dhcp_options.to_a
      end.flatten
    end
    @@dhoptions.find do |dopt|
      dopt_name = dopt.tags.to_h['Name'] || dopt.id
      dopt_name == name || dopt.id == name
    end
  end

  def find_dhopts_item_by_name(name)
    self.class.find_dhopts_item_by_name(name)
  end

  def find_vpc_item_by_name(name)
    @@vpcs ||= begin
      regions.collect do |region_name|
        ec2.regions[region_name].vpcs.to_a
      end.flatten
    end
    @@vpcs.find do |vpc|
      vpc_name = vpc.tags.to_h['Name'] || vpc.vpc_id
      vpc_name == name
    end
  end

  def find_region_name_for_vpc_name(name)
    self.class.find_region_name_for_vpc_name(name)
  end
  def self.find_region_name_for_vpc_name(name)
    regions.find do |region_name|
      ec2.regions[region_name].vpcs.find do |vpc|
        vpc_name = vpc.tags.to_h['Name'] || vpc.vpc_id
        vpc_name == name
      end
    end
  end

  def flush
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def vpc=(vpc_name)
    vpc = find_vpc_item_by_name(vpc_name)
    if vpc.nil?
      fail("Cannot find vpc #{vpc_name}")
    end
    @property_hash[:aws_item].attach(vpc)
    @property_hash[:vpc] = vpc_name
  end

  def self.array_to_puppet(arr)
    if arr == nil
      return nil
    elsif arr.size == 1
      arr[0]
    else
      arr
    end
  end

  def self.array_from_puppet(arr)
    if arr.is_a? Array
      arr
    elsif arr == nil
      []
    else
      [arr]
    end
  end

  def array_to_puppet(arr)
    self.class.array_to_puppet(arr)
  end

  def array_from_puppet(arr)
    self.class.array_from_puppet(arr)
  end

end

