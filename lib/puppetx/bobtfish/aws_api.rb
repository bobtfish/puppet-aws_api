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

      def flush_when_ready
        super
        flushing :tags do |tags|
          aws_item.clear_tags
          tags.each do |key, value|
            aws_item.tags[key] = value
          end
        end
        aws_item.tags['Name'] = resource[:name]
      end

      # Some identifier to use if tag lookup fails
      def fallback_name
        if aws_item.respond_to? :id
          aws_item.id
        else
          raise NotImplementedError
        end
      end

    end
  end
end

class Puppetx::Bobtfish::Aws_api < Puppet::Provider
  HAVE_AWS_SDK = begin; require 'aws-sdk'; true; rescue Exception; false; end

  confine :true => HAVE_AWS_SDK

  desc "Helper for Providers which use the AWS APIs"

  # For subclasses to implement:

  # Return AWS item instances for given region.
  # Can use `primary_api :collection` configuration if provided.
  def self.aws_items_for_region(region)
    if @collection
      api(region).send(@collection.to_sym)
    else
      raise NotImplementedError
    end
  end

  # Return region name given resource type instance.
  # Can be implemented by `find_region_from`.
  def self.find_region(type)
    raise NotImplementedError
  end

  # Return an ensure state to for the given `aws_item`.
  # Can be implemented by `ensure_form_state`.
  def self.get_ensure_state(aws_item)
    raise NotImplementedError
  end

  # Wait for any state transitions in AWS to finish applying.
  # Can be implemented by `ensure_form_state`.
  def wait_for_state_transitions
    # don't wait for anything unless told otherwise
  end


  # Called after aws_item and region have already been populated.
  # See  `init` and `map_init` for some helpful implementation sugar.
  def init_property_hash
    # make super()-safe so we can make liberal use of mixins
  end

  # Called after `wait_for_state_transitions`, works the same as the standard
  # puppet flush.
  # Best to implement using the `flushing` helper.
  def flush_when_ready
    # make super()-safe so we can make liberal use of mixins
  end



  # Shared core functionality:

  def initialize(*args)
    super(*args)
    @property_flush = {}
  end

  def self.instance_from_aws_item(region, aws_item)
    # Default implementation is to populate aws_item and region and then call init_property_hash
    instance = new(:region=>region, :aws_item=>aws_item, :ensure=>get_ensure_state(aws_item))
    instance.init_property_hash
    instance
  end



  def self.instances
    regions.map do |region|
      aws_items_for_region(region).map do |aws_item|
        instance_from_aws_item(region, aws_item)
      end
    end.flatten
  end

  @@prefetched = {}
  def self.prefetch(resources)
    if @@prefetched[self]
      debug "AWS_API: Skipping redundant prefetch..."
      return
    end
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
    @@prefetched[self] = true
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

  # Delegate to flush_when_ready to handle wonky AWS states
  def flush
    self.wait_for_state_transitions
    self.flush_when_ready
    @property_flush = {}
  end

  # We rely on flush, but make sure we still set ensure with the default ensurable behaviour
  def create
    self.ensure = :present
  end
  def destroy
    self.ensure = :absent
  end

  def exists?
    self.ensure == :present
  end

  class WaitTimeoutError < Exception
  end
  @@default_timeout = 60
  # Wait until arbitrary block becomes true
  def wait_until(timeout=@@default_timeout, cycle=1, fatigue=1.2, &block)
    waited = 0
    until block.call
      debug "#{self} is waiting for resource (%5.2f/%2ds +%5.2f)..."% [waited, timeout, cycle]
      sleep cycle
      waited += cycle
      cycle *= fatigue
      if waited > timeout
        raise WaitTimeoutError, "Waiting for aws resources timed out after #{waited} seconds!"
      end
    end
  end

  def aws_item
    @property_hash[:aws_item]
  end


  # Init helpers:


  # Init @property_hash based on properties of aws_item. Array arguments use the same
  # property name on both sides, while the Hash argument maps a puppet resource property name
  # to a aws_item property name
  def map_init(*properties)
    mapped_properties = {}
    if properties.last.is_a?(Hash)
      mapped_properties = properties.pop
    end

    properties.each do |prop|
      @property_hash[prop] = if aws_item.is_a? Hash
        # sometimes we use the "raw" API and only have hash responses to work with
        aws_item[prop]
      else
        aws_item.send(prop)
      end
    end

    mapped_properties.each do |puppet_prop, aws_prop|
      @property_hash[puppet_prop] = aws_item.send(aws_prop)
    end
  end

  # Convenience setter for (the somewhat verbosely) @property_hash
  def init(prop, value)
    @property_hash[prop] = value
  end

  # Flush helpers:

  # Executes the given block if any of the given names of `properties` have pending changes
  # to flush. The block will be executed with the requested values of each given property as
  # arguments (in the same order as the `properties` names).
  #
  # If the last  hash argument is a hash, its keys correspond to property names as above, but
  # the block will only be executed when the property's flush value matches the given value.
  # These values are *not* added to the block's argument list.
  #
  # Flushing `:ensure` triggers some additional special behaviour:  After the block is executed
  # state transitions are allowed to finalized using  `get_ensure_state` and
  # `wait_for_state_transitions`. When using `:ensure => :present` specifically, the block's
  # return value is used to populate `aws_item` if not already present.
  def flushing(*properties, &block)
    match_values = {}
    match_values = properties.pop if properties.last.is_a? Hash

    # IF BOTH:
    #   1) EITHER there are no properties to match -OR-, if there are
    #      they should have at least one item in common with the actual @property_flush set
    #   2) all hash property matches matches the actual flush value
    if ((
            properties.empty? || (@property_flush.keys & properties).any?
      ) &&  match_values.all? {|p, v| @property_flush[p] == v })
      return_value = block.call(*properties.collect {|p| @property_flush[p]})

      if match_values[:ensure]
        goal = match_values[:ensure]
        if goal == :present and aws_item.nil?
          @property_hash[:aws_item] = return_value
        end
        wait_until do
          self.class.get_ensure_state(aws_item) == goal
        end
        self.wait_for_state_transitions
      end
    end
  end

  # Set the given properties to flush.
  # Normally useful inside `flushing :ensure => :present` block for setting up dependent
  # items (by default properties are not set to flush from their absent state).
  def also_flush(*properties)
    properties.each do |prop|
      @property_flush[prop] = resource[prop]
    end
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

  class LookupNotFound < Exception
  end

  def self.catalog_lookup(catalog, type_name, resource_name)
    if not resource_name or resource_name =~ /^\s+$/
      raise "Can't lookup #{type_name} with blank lookup-name"
    end
    found = catalog.resource("#{type_name.capitalize}[#{resource_name}]")
    unless found
      # Perhaps the referenced type was not yet prefetched?
      debug "AWS_API: Catalog lookup triggered prefetch for #{type_name}"
      self.induce_prefetch(catalog, type_name)
    end
    found = catalog.resource("#{type_name.capitalize}[#{resource_name}]")
    if found
      return found.provider
    else
      raise LookupNotFound, "Lookup failed: #{type_name.capitalize}[#{resource_name}] not found"
    end
  end

  def self.induce_prefetch(catalog, type_name)
     type = Puppet::Type.type(type_name)
     type.defaultprovider.prefetch(self.resources_by_provider(catalog, type_name))
  end

  # Dynamic helpers

  # Based on mk_resource_methods, but handles @property_flush behaviour and
  # can implement certain properties as read_only
  def self.flushing_resource_methods(opts={})
    read_only = (opts[:read_only] or []).collect(&:to_sym)
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
      if read_only.include?(attr)
        define_method(attr.to_s + "=") do |val|
          fail "Can't change #{attr} property for #{self} - it is read-only once #{resource.type} resource is created."
        end
      else
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
      # We should also avoid iterating over regions for this
      # provider:
      define_singleton_method :regions do
        [nil]
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
        # don't just check nil in case something set the region specifically to nil
        if @property_hash.has_key? :region
          @property_hash[:region]
        else
          self.class.find_region(self.resource)
        end
      end
    end

  end

  # Configure how to map the AWS resource state to an ensure value.
  #
  # A block must be provided that takes a given `aws_item` and returns its state. (Note that
  # Symbol#to_proc will usually suffice for this purpose.)
  #
  # `state_mapping` is the hash mapping from possible state values (strings will always be
  # symbolized) to either a) the value to use for ensure (e.g. `:available => :present`), or
  # b) another state,  which indicate this is a transitional states (e.g.
  # `:pending => :available`).
  #
  # Encountering an unmapped state value will raise an exception.
  #
  # If the `aws_item` has a method called `exists?` it will always be called before the
  # `state_mapping` is applied and immediately resolve to `:absent` if false.
  def self.ensure_from_state(state_mapping, &block)

    get_terminus_state = lambda do |state|
      target = state_mapping[state]
      if state_mapping[target].nil? || state == target
        # If the target state is not also a key OR it is a key, but it simply points to itself
        # this must be the terminal state
        return target
      else
        # not a terminal state, keep looking
        return get_terminus_state.call(target)
      end
    end
    terminus_states = {}
    transitional_states = {}
    state_mapping.each do |k, v|
      term = get_terminus_state.call(k)
      terminus_states[k] = term
      if v != term
        transitional_states[k] = v
      end
    end

    define_singleton_method :get_ensure_state do |aws_item|

      # First, check if existance check is available, and failed:
      if aws_item.respond_to?(:exists?) and not aws_item.exists?
        :absent
      # For everything else, apply the `state_mapping` (or fall back to
      # the raw state string)
      else
        state = block.call(aws_item)
        state = state.to_sym if state.respond_to? :to_sym
        terminus = terminus_states[state]
        if terminus.nil?
          raise "Unknown ensure state for #{aws_item}: #{state}"
        end
        terminus
      end
    end

    if transitional_states.any?
      define_method :wait_for_state_transitions do
        if aws_item
          wait_until do
            state = block.call(aws_item)
            state = state.to_sym if state.respond_to? :to_sym
            # wait until state is no longer transitional
            !transitional_states[state]
          end

        end
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

