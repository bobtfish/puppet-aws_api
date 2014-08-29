require 'rubygems'
require 'puppet'

module Puppetx
  module Bobtfish
    module TaggableProvider
      def init_property_hash
        tags = aws_item.tags.to_h
        init :name, tags.delete('Name') || fallback_name
        init :tags, tags
        super
      end

      def preventable_flush
        super
        flushing? :tags do |tags|
          aws_item.clear_tags
          tags.each do |key, value|
            aws_item.tags[key] = value
          end
        end
        aws_item.tags['Name'] = resource[:name]
      end
    end
  end
end

class Puppetx::Bobtfish::Aws_api < Puppet::Provider
  HAVE_AWS_SDK = begin; require 'aws-sdk'; true; rescue Exception; false; end

  confine :true => HAVE_AWS_SDK

  desc "Helper for Providers which use the AWS APIs"

  # For subclasses to implement:

  def self.aws_items_for_region(region)
    if @collection
      api(region).send(@collection.to_sym)
    else
      raise NotImplementedError
    end
  end

  def self.find_region(type)
    raise NotImplementedError
  end

  def self.instance_from_aws_item(region, aws_item)
    # Default implementation is to populate aws_item and region and then call init_property_hash
    instance = new(:region=>region, :aws_item=>aws_item, :ensure=>get_ensure_state(aws_item))
    instance.init_property_hash
    instance
  end

  def get_ensure_state(aws_item)
    raise NotImplementedError
  end

  def destroy
    if aws_item.respond_to? :delete
      self.prevent_flush!
      aws_item.delete
      self.ensure = :absent
    else
      raise NotImplementedError
    end
  end

  def fallback_name
    if aws_item.respond_to? :id
      aws_item.id
    else
      raise NotImplementedError
    end
  end


  def initialize(*args)
    super(*args)
    @property_flush = {}
    @prevent_flush = false
  end

  # Called after aws_item and region have already been populated
  def init_property_hash
    # just so super is always safe
  end

  # Called during flush unless `prevent_flush!` was used
  def preventable_flush
  end

  # Don't run the preventable_flush during the next flush cycle
  def prevent_flush!
    @prevent_flush = true
  end

  # Are any of the given properties being flushed?
  # If given a block, will execute that block conditionally, passing in the
  # the flush values
  def flushing?(*properties)
    properties.collect!(&:to_sym)
    did_flush = (@property_flush.keys & properties).any?
    if block_given? and did_flush
      yield *properties.collect {|p| @property_flush[p]}
    end
    did_flush
  end

  # Shared core functionality:


  def self.instances
    regions.map do |region|
      aws_items_for_region(region).map do |aws_item|
        instance_from_aws_item(region, aws_item)
      end
    end.flatten
  end

  def self.prefetch(resources)
    resources.values.map {|type|
      type.class.defaultprovider.find_region(type)
    }.uniq.each do |region|
      debug "AWS_API: Prefetching with #{@primary_api} api in region #{region}..."
      aws_items_for_region(region).each do |aws_item|
        provider = instance_from_aws_item(region, aws_item)
        if resource = resources[provider.name] then
          resource.provider = provider
        end
      end
    end
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
    self.ensure == :present
  end

  def flush
    unless @prevent_flush
      preventable_flush
    end
    @prevent_flush = false
  end

  # Used by wait_until_ready
  def ready?
    self.ensure == :present
  end

  def wait_until_ready(timeout=60, cycle=1)
    wait_until(timeout, cycle, &method(:ready?))
  end

  # Wait until arbitrary block becomes true
  def wait_until(timeout=60, cycle=1, &block)
    waited = 0
    until waited > timeout or block.call
      debug "Waiting for resource..."
      sleep cycle
      waited += cycle
    end
  end

  def aws_item
    @property_hash[:aws_item]
  end

  def create
    self.ensure = :present
  end

  # Are we currently flushing to a create state?
  # If given a block, it will be called condtionally and the returned value will be used to
  # assign the new aws_item. Will also wait until resource is ready after block is ran.
  def creating?
    is_creating = (@property_flush[:ensure] == :present)
    if block_given? and is_creating
      @property_hash[:aws_item] = yield
      wait_until_ready
    end
    is_creating
  end

  # Some convenience:


  # Init @property_hash based on properties of aws_item. Array arguments use the same
  # property name on oth sides, the Hash argument maps a  puppet resource property name
  # to a aws_item property name
  def map_init(*properties)
    mapped_properties = {}
    if properties.last.is_a?(Hash)
      mapped_properties = properties.pop
    end

    properties.each do |prop|
      @property_hash[prop] = aws_item.send(prop)
    end

    mapped_properties.each do |puppet_prop, aws_prop|
      @property_hash[puppet_prop] = aws_item.send(aws_prop)
    end
  end

  # Convenience setter for (the somewhat verbosely) @property_hash
  def init(prop, value)
    @property_hash[prop] = value
  end

  # Lookup system

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
    self.class.catalog_lookup(resource.catalog, type_name, resource_name)
  end

  def self.catalog_lookup(catalog, type_name, resource_name)
    if not resource_name or resource_name =~ /^\s+$/
      raise "Can't lookup #{type_name} with blank lookup-name"
    end
    found = catalog.resource("#{type_name.capitalize}[#{resource_name}]")
    unless found
      # Perhaps the referenced type was not yet prefetched?
      debug "AWS_API: Catalog lookup triggered prefetch for #{type_name}"
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

  # Dynamic helpers

  # Based on mk_resource_methods, but handles @property_flush behaviour and
  # can implement certain properties as read_only
  def self.flushing_resource_methods(opts)
    read_only = opts[:read_only].collect(&:to_sym)
    [resource_type.validproperties, resource_type.parameters].flatten.each do |attr|
      attr = attr.intern
      next if attr == :name
      define_method(attr) do
        if @property_hash[attr].nil?
          :absent
        else
          @property_hash[attr]
        end
      end
      unless read_only.include?(attr)
        define_method(attr.to_s + "=") do |val|
          @property_hash[attr] = val
          @property_flush[attr] = val
        end
      end
    end
  end


  # Automatically set up find_region method
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
      # delegate region finding to provider of related type
      define_singleton_method :find_region do |type|
        provider = lookup_first(type_name, type, property_name)
        provider.class.find_region(provider.resource)
      end
    end


    # Also set up region accessor (unless we explicitly don't have a region)
    unless type_name.nil?
      define_method :region do
        @property_hash[:region]
      end
    end

  end

  # Configure how to map the aws resource state to an ensure value
  # Note: For best results with wait_until_ready, allow transitional states
  # to pass through as-is (i.e. don't map :pending => :present)
  def self.ensure_from_state(state_method, state_mapping={})
    define_singleton_method :get_ensure_state do |aws_item|
      # First, check if existance check is available, and failed:
      if aws_item.respond_to?(:exists?) and not aws_item.exists?
        :absent
      # If we have no better state method than `exists?` (and it didn't
      # already fail), we're done
      elsif state_method == :exists?
        :present
      # For everything else, apply the `state_mapping` (or fall back to
      # the raw state string)
      else
        state = aws_item.send(state_method).to_sym
        state_mapping[state] or state
      end
    end
  end


  @@apis = Hash.new { |hash, key| hash[key] = {} }
  def self.make_api(name, api_class)
    define_method name do |*args|
      region = args.first if args.any?
      region = self.region if region.nil? and self.respond_to? :region
      self.class.send(name, region)
    end
    define_singleton_method name do |*args|
      region = args.first if args.any?
      @@apis[name][region] ||= api_class.new(:region=>region)
    end
  end

  # API setup

  make_api :iam,  AWS::IAM
  make_api :ec2,  AWS::EC2
  make_api :r53,  AWS::Route53
  make_api :elb,  AWS::ELB
  make_api :rds,  AWS::RDS
  make_api :elcc, AWS::ElastiCache
  make_api :s3,   AWS::S3


  class << self
    # Annoying special case for EC2 region handling
    # (connection config :region is not enough to constrain it to that region)
    alias_method :generated_ec2, :ec2
    def ec2(region=nil)
      if region.nil?
        generated_ec2
      else
        generated_ec2.regions[region]
      end
    end
  end


  # Configures which API to return when calling self.api()
  # Optionally the :collection option provides a default
  # implementation for `aws_items_for_region` and adds a
  # `collection` convenience method
  def self.primary_api(api_name, opts={})
    @primary_api = api_name
    _collection = @collection = opts[:collection]
    if _collection
      define_method :collection do
        api.send(_collection)
      end
    end
  end

  def self.api(region=nil)
    self.send(@primary_api, region)
  end

  def api
    self.class.api(self.class.find_region(resource))
  end

  # ruby <1.8 shim
  if not self.respond_to? :define_singleton_method
    def self.define_singleton_method(name, &block)
      (class << self; self; end).send(:define_method, name, &block)
    end
  end

  # Shared caches

  # Clearable cache of instance profiles
  # (needed to efficiently work around lack of direct lookup in aws-api)
  @@instance_profiles = {}
  def self.instance_profiles
    if @@instance_profiles.empty?
      iam.client.list_instance_profiles[:instance_profiles].each do |profile|
        @@instance_profiles[profile[:instance_profile_id]] = profile
      end
    end
    @@instance_profiles
  end


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

