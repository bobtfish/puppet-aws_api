require 'puppetx/bobtfish/type_helpers'

Puppet::Type.newtype(:aws_rds_instance) do
  @doc = "Manage AWS RDS instances"
  newparam(:name)
  ensurable
  newproperty(:allocated_storage)
  newproperty(:db_instance_class)
  newproperty(:engine)
  newproperty(:engine_version)
  newproperty(:master_username)
  newparam(:master_user_password)
  newproperty(:multi_az)
  newparam(:publicly_accessible)

  newproperty(:subnets) do
    include Puppetx::Bobtfish::SortedDeepCompare
  end
  autorequire(:aws_subnet) do
    self[:subnets]
  end

  newproperty(:security_groups) do
    include Puppetx::Bobtfish::SortedDeepCompare
    defaultto []
  end
  autorequire(:aws_security_group) do
    self[:security_groups]
  end

  newproperty(:endpoint) do
    include Puppetx::Bobtfish::ReadOnlyProperty
    desc "Read-only: endpoint DNS name for this DB"
  end
end

