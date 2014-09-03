require 'puppetx/bobtfish/type_helpers'

Puppet::Type.newtype(:aws_cache_cluster) do
  @doc = "Manage an AWS ElastiCache cache cluster"
  # TODO much validations
  newparam(:name) do
    validate do |value|
      unless value =~ /^[-a-z0-9]{1,20}$/i
        raise ArgumentError, "Cache cluster name must contain from 1 to 20 alphanumeric characters or hyphens."
      end
      unless value =~ /^[a-z]/i
        raise ArgumentError, "Cache cluster name first character must be a letter."
      end
      if value =~ /-$/ || value =~ /--/
        raise ArgumentError, "Cache cluster name cannot end with a hyphen or contain two consecutive hyphens."
      end
    end
  end
  ensurable
  newproperty(:cache_node_type) do
    include Puppetx::Bobtfish::RequiredValue
    newvalues /^cache\.t\d\.\w+$/
  end
  newproperty(:engine) do
    include Puppetx::Bobtfish::RequiredValue
    newvalue 'redis'
  end
  newproperty(:engine_version)
  newproperty(:security_groups) do
    include Puppetx::Bobtfish::SortedDeepCompare
    defaultto []
  end
  autorequire(:aws_security_group) do
    self[:security_groups]
  end

  newproperty(:subnets) do
    include Puppetx::Bobtfish::SortedDeepCompare
    include Puppetx::Bobtfish::RequiredValue
    # (making this optional would require an alternate mechanism for dealing with regions)
  end

  autorequire(:aws_subnet) do
    self[:subnets]
  end
  newproperty(:auto_minor_version_upgrade, :boolean=>true)
  newproperty(:endpoint) do
    include Puppetx::Bobtfish::ReadOnlyProperty
    desc "Read-only: endpoint thingy"
  end
end

