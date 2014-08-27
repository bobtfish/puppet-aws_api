require 'puppetx/bobtfish/type_helpers'

Puppet::Type.newtype(:aws_cache_cluster) do
  @doc = "Manage an AWS ElastiCache cache cluster"
  newparam(:name)
  ensurable
  newproperty(:cache_node_type)
  newproperty(:engine) do
    newvalue 'redis'
  end
  newproperty(:engine_version)
  newproperty(:security_groups, :parent => Puppetx::Bobtfish::UnorderedValueListProperty) do
    defaultto []
  end
  autorequire(:aws_security_group) do
    self[:security_groups]
  end
  newproperty(:subnets, :parent => Puppetx::Bobtfish::UnorderedValueListProperty) do
    defaultto []
  end
  autorequire(:aws_subnet) do
    self[:subnets]
  end
  newproperty(:auto_minor_version_upgrade)
  newproperty(:endpoint, :parent => Puppetx::Bobtfish::ReadOnlyProperty) do
    desc "Read-only: endpoint thingy"
  end
end

