require 'puppetx/bobtfish/type_helpers'
Puppet::Type.newtype(:aws_rrset) do
  @doc = "Manage AWS Route 54 resource record sets"

  # Populated by name param during validation
  attr_accessor :record_name, :record_type

  newparam(:name) do
    desc "Record type followed by name, space sparated (e.g. 'CNAME foo.example.com.')"
    validate do |value|
       if value =~ /^([A-Z]+)\s+([-_a-z0-9\.]+\.)$/
        resource.record_type = $1
        resource.record_name = $2
       else
        raise ArgumentError, "Aws_rrset names must be in the form of 'CNAME foo.example.com.'"
       end
    end

  end
  ensurable


  newproperty(:zone) do
      desc "An aws_hosted_zone name (required)"
      include Puppetx::Bobtfish::RequiredValue
  end
  autorequire(:aws_hosted_zone) do
    self[:zone]
  end

  newproperty(:value, :array_matching => :all) do
    defaultto []
    desc "The record value string (array of strings for multiple lines)"
    # TODO: validation, document placeholders
    def insync?(is)
      subbed_should == is
    end
    def subbed_should
      self.resource.provider.subbed_record_values
    end
  end

  VALID_TARGET_TYPES = [
    :aws_ec2_instance,
    :aws_elb,
    :aws_cache_cluster,
    :aws_s3_bucket,
    :aws_rds_instance,
  ]

  VALID_TARGET_TYPES.each do|type|
    autorequire(type) do
      filter_targets(type.to_s.capitalize).collect(&:title).uniq
    end
  end

  newparam(:targets, :array_matching => :all) do
    defaultto []
    desc "An array of other AWS resources which will be used to fill out  placeholders in their corresponding value lines."
    validate do |value|
      # When passed array values puppet always calls validate (and munge) separately for
      # each array value.
      # This cannot be turned off.
      # And is RIDICULOUS.
      value = @shouldorig if @shouldorig
      if !value.nil? and value.any? and value.size != resource[:value].size
        raise ArgumentError, "You most provide a target for each RRSET value! (You have #{resource[:value].size} record value(s) but #{value.size} target(s)...)"
      end
      value.each do |target|
        unless target.is_a? Puppet::Resource
          raise ArgumentError, "Aws_rrset targets must be direct references to another valid AWS resource."
        end
        unless VALID_TARGET_TYPES.include?(target.type.downcase.to_sym)
          raise ArgumentError, "Only the following resources are valid targets for Aws_rrset: #{VALID_TARGET_TYPES.join(', ')}"
        end
      end
    end
  end

  newproperty(:ttl) do
    desc "TTL in seconds"
    include Puppetx::Bobtfish::EnsureIntValue
  end



  private

  def filter_targets(type_name)
    targets = self[:targets]
    targets = [targets]  unless targets.is_a? Array
    targets.find_all do |target|
      target.type  == type_name
    end
  end

end

