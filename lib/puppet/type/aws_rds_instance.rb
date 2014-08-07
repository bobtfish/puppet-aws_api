require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'puppet_x', 'bobtfish', 'unordered_list_prop.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'puppet_x', 'bobtfish', 'read_only_prop.rb'))
Puppet::Type.newtype(:aws_rds_instance) do
  @doc = "Manage AWS RDS instances"
  newparam(:name)
  ensurable
  newproperty(:allocated_storage)
  newproperty(:db_instance_class)
  newproperty(:engine)
  newproperty(:engine_version)
  newproperty(:region)
  newproperty(:master_username)
  newparam(:master_user_password)
  newproperty(:multi_az)
  newparam(:publicly_accessible)

  newproperty(:subnets, :parent => Puppet_X::Bobtfish::UnorderedValueListProperty)
  autorequire(:aws_subnet) do
    self[:subnets]
  end

  newproperty(:security_groups, :parent => Puppet_X::Bobtfish::UnorderedValueListProperty) do
    defaultto []
  end
  autorequire(:aws_security_group) do
    self[:security_groups]
  end

  newproperty(:endpoint, :parent => Puppet_X::Bobtfish::ReadOnlyProperty) do
    desc "Read-only: endpoint DNS name for this DB"
  end
end

