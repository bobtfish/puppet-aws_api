require 'rubygems'
require 'puppet'

module Puppet_X
  module Bobtfish
  end
end

class Puppet_X::Bobtfish::Aws_api < Puppet::Provider
  HAVE_AWS_SDK = begin; require 'aws-sdk'; true; rescue Exception; false; end

  confine :true => HAVE_AWS_SDK

  desc "Helper for Providers which use the AWS APIs"



  def self.aws_items_for_region(region)
    raise NotImplementedError
  end

  def self.instance_from_aws_item(aws_item)
    raise NotImplementedError
  end

  def self.find_region(type)
    raise NotImplementedError
  end

  def self.instances
    puts "WHAT ARE YOU DOING HERE??"
    regions.map do |region|
      aws_items_for_region(region).map do |aws_item|
        instance_from_aws_item(aws_item)
      end
    end.flatten
  end

  def self.prefetch(resources)
    puts "PREFETCHING FOR #{self}..."
    resources.values.map {|type|
      type.class.defaultprovider.find_region(type)
    }.uniq.each do |region|
      aws_items_for_region(region).each do |aws_item|
        provider = instance_from_aws_item(aws_item)
        if resource = resources[provider.name] then
          resource.provider = provider
        end
      end
    end
  end

  # Lookup a `type_name` by the value of `property` in type
  def self.lookup(type_name, type, property)
    self.catalog_lookup(type.catalog, type_name, type[property])
  end

  def self.lookup_first(type_name, type, property)
    self.catalog_lookup(type.catalog, type_name, type[property].first)
  end

  # Lookup a `type_name` by given `resource_name`
  def lookup(type_name, resource_name)
    self.class(resource.catalog, type_name, resource_name)
  end

  def self.catalog_lookup(catalog, type_name, resource_name)
    if not resource_name or resource_name =~ /^\s+$/
      raise "Can't lookup #{type_name} with blank lookup-name"
    end
    found = resource.catalog.resource("#{type_name.capitalize}[#{resource_name}]")
    unless found
      # Perhaps the referenced type was not yet prefetched?
      puts "ATTEMPT PREFETCH #{type_name}"
      self.prefetch(self.resources_by_provider(catalog, type_name))
    end
    found = resource.catalog.resource("#{type_name.capitalize}[#{resource_name}]")
    if found
      return found.provider
    else
      raise "Lookup failed: #{type_name.capitalize}[#{name}] not found"
    end
  end

  def self.read_only(*methods)
    methods.each do |ro_method|
      define_method("#{ro_method}=") do |v|
        fail "Can't change '#{ro_method}' for '#{name}' - property is read-only once #{resource.type} resource is created."
      end
    end
  end

  def self.find_region_from(type_name, property_name=nil)
    if type_name.nil?
      # this resources explicitly lacks a region
      define_singleton_method :find_region do |type|
        nil
      end
    elsif property_name.nil?
      # region is directly available!
      property_name = type_name
      define_singleton_method :find_region do |type|
        type[property_name]
      end
    else
      # delegate to provider of related type
      define_singleton_method :find_region do |type|
        provider = lookup_first(type_name, type, property_name)
        provider.class.find_region(provider.resource)
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

  @@apis = {}
  def self.make_api(name, api_class)
    define_method name do |*args|
      self.class.send(name, *args)
    end
    define_singleton_method name do |*args|
      region = args.first if args.any?
      @@apis[name] ||= api_class.new(:region=>region)
    end
  end

  make_api :iam,  AWS::IAM
  make_api :ec2,  AWS::EC2
  make_api :r53,  AWS::Route53
  make_api :elb,  AWS::ELB
  make_api :rds,  AWS::RDS
  make_api :elcc, AWS::ElastiCache
  make_api :s3,   AWS::S3



  def self.regions
    @@regions ||= begin
      if ENV['AWS_REGIONS'] and not ENV['AWS_REGIONS'].empty?
        ENV['AWS_REGIONS'].split(',')
      elsif HAVE_AWS_SDK
        ec2.regions.collect { |r| r.name }
      else
        []
      end
    end
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


  # ruby <1.8 shim
  if not self.respond_to? :define_singleton_method
    def self.define_singleton_method(name, &block)
      (class << self; self; end).send(:define_method, name, &block)
    end
  end


  private

  # Implementation copied Puppet::Transaction.resources_by_provider
  # so we can call prefetch ourselves during the prefetch cycle
  @@resources_by_provider = Hash.new { |h, k| h[k] = {} }
  def self.resources_by_provider(catalog, type_name)
    catalog.vertices.each do |resource|
      if resource.class.attrclass(:provider)
        @@resources_by_provider[resource.type][resource.name] = resource
      end
    end
    @@resources_by_provider[type_name] || {}
  end


end

