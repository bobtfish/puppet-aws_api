require 'puppetx/bobtfish/type_helpers'

Puppet::Type.newtype(:aws_cache_cluster) do
  @doc = "Manage an AWS ElastiCache cache cluster"
  # TODO much validations
  newparam(:name)
  ensurable
  newproperty(:cache_node_type)
  newproperty(:engine) do
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
    defaultto []
  end
  autorequire(:aws_subnet) do
    self[:subnets]
  end
  newproperty(:auto_minor_version_upgrade)
  newproperty(:endpoint) do
    include Puppetx::Bobtfish::ReadOnlyProperty
    desc "Read-only: endpoint thingy"
  end
end

