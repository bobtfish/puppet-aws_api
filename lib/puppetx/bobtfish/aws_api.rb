require 'rubygems'
require 'puppet'

module Puppetx
  module Bobtfish
  end
end

class Puppetx::Bobtfish::Aws_api < Puppet::Provider
  HAVE_AWS_SDK = begin; require 'aws-sdk'; true; rescue Exception; false; end

  confine :true => HAVE_AWS_SDK

  desc "Helper for Providers which use the AWS APIs"



  def self.aws_items_for_region(region)
    if @collection
      api(region).send(@collection.to_sym)
    else
      raise NotImplementedError
    end
  end


  def self.instance_from_aws_item(region, aws_item)
    raise NotImplementedError
  end

  def self.find_region(type)
    raise NotImplementedError
  end

  def self.instances
    puts "WHAT ARE YOU DOING HERE??"
    regions.map do |region|
      aws_items_for_region(region).map do |aws_item|
        instance_from_aws_item(region, aws_item)
      end
    end.flatten
  end

  def self.prefetch(resources)
    puts "PREFETCHING FOR #{self}..."
    resources.values.map {|type|
      type.class.defaultprovider.find_region(type)
    }.uniq.each do |region|
      puts "Fetching for #{@primary_api} in region #{region}..."
      aws_items_for_region(region).each do |aws_item|
        provider = instance_from_aws_item(region, aws_item)
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
    resource_name = type[property]
    resource_name = resource_name.first unless resource_name.respond_to? :to_sym
    self.catalog_lookup(type.catalog, type_name, resource_name.to_sym)
  end

  # Lookup a `type_name` by given `resource_name`
  def lookup(type_name, resource_name)
    self.class(resource.catalog, type_name, resource_name)
  end

  def self.catalog_lookup(catalog, type_name, resource_name)
    if not resource_name or resource_name =~ /^\s+$/
      raise "Can't lookup #{type_name} with blank lookup-name"
    end
    found = catalog.resource("#{type_name.capitalize}[#{resource_name}]")
    unless found
      # Perhaps the referenced type was not yet prefetched?
      puts "ATTEMPT PREFETCH #{type_name}"
      type = Puppet::Type.type(type_name)
      type.defaultprovider.prefetch(self.resources_by_provider(catalog, type_name))
    end
    found = catalog.resource("#{type_name.capitalize}[#{resource_name}]")
    if found
      return found.provider
    else
      raise "Lookup failed: #{type_name.capitalize}[#{resource_name}] not found"
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

  # Configures which API to return when calling self.api()
  # Optionally the :collection option provides a default
  # implementation for aws_items_for_region
  def self.primary_api(api_name, opts={})
    @primary_api = api_name
    @collection = opts[:collection]
  end

  def self.api(region=nil)
    self.send(@primary_api, region)
  end

  def api
    self.api(self.class.find_region(resource))
  end



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

  def exists?
    @property_hash[:ensure] == :present
  end

  def aws_item
    @property_hash[:aws_item]
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

