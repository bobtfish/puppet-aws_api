require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'puppet_x', 'bobtfish', 'unordered_list_prop.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'puppet_x', 'bobtfish', 'read_only_prop.rb'))
Puppet::Type.newtype(:aws_cache_cluster) do
  @doc = "Manage an AWS ElastiCache cache cluster"
  newparam(:name)
  ensurable
  newproperty(:cache_node_type)
  newproperty(:engine) do
    newvalue 'redis'
  end
  newproperty(:engine_version)
  newproperty(:security_groups, :parent => Puppet_X::Bobtfish::UnorderedValueListProperty) do
    defaultto []
  end
  autorequire(:aws_security_group) do
    self[:security_groups]
  end
  newproperty(:vpc) do
  end
  autorequire(:aws_vpc) do
    self[:vpc]
  end
  newproperty(:auto_minor_version_upgrade)
  newproperty(:endpoint, :parent => Puppet_X::Bobtfish::ReadOnlyProperty) do
    desc "Read-only: endpoint thingy"
  end
end

