require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'puppet_x', 'bobtfish', 'list_of_hashes.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'puppet_x', 'bobtfish', 'read_only_prop.rb'))
Puppet::Type.newtype(:aws_ec2_instance) do
  @doc = "Manage AWS EC2 instances"
  newparam(:name)
  ensurable
  newproperty(:image_id)
  newproperty(:instance_type)
  newproperty(:iam_role)
  newproperty(:region)
  newproperty(:subnet)
  newproperty(:key_name)
  newproperty(:tags)
  newparam(:associate_public_ip_address)
  newproperty(:elastic_ip)
  newproperty(:block_device_mappings, :parent => Puppet_X::Bobtfish::ListOfHashesProperty)
  newproperty(:security_groups, :array_matching => :all) do
    defaultto []
  end

  autorequire(:aws_subnet) do
    self[:subnet]
  end
  autorequire(:aws_iam_role) do
    self[:iam_role]
  end
  autorequire(:aws_security_group) do
    self[:security_groups]
  end

  newproperty(:public_ip_address, :parent => Puppet_X::Bobtfish::ReadOnlyProperty) do
    desc "Read-only: public ip of machine"
  end
end

