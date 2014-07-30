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

  def lookup(type, name)
    # Lookup aws objects from prefetched catalog
    # TODO: we can probably replace most find by name lookups with this?
    resource.catalog.resource("#{type.capitalize}[#{name}]").provider.aws_item
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

  def self.r53
    amazon_thing(AWS::Route53)
  end

  def r53
    self.class.r53
  end

  def self.elb
    amazon_thing(AWS::ELB)
  end

  def elb
    self.class.elb
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

  def self.find_hosted_zone_by_name(name)
    r53.hosted_zones.find{|zone| zone.name == name }
  end

  def self.find_instance_profile_by_id(id)
    # No there really isn't a direct ID lookup API call, go figure
    iam.client.list_instance_profiles[:instance_profiles].find do |profile| 
      profile[:instance_profile_id] == id
    end
  end

  def flush
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def aws_item
    @property_hash[:aws_item]
  end

  def vpc=(vpc_name)
    vpc = find_vpc_item_by_name(vpc_name)
    if vpc.nil?
      fail("Cannot find vpc #{vpc_name}")
    end
    @property_hash[:aws_item].attach(vpc)
    @property_hash[:vpc] = vpc_name
  end


end

