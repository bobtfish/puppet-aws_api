require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'puppet_x', 'bobtfish', 'list_of_hashes.rb'))

Puppet::Type.newtype(:aws_security_group) do
  @doc = "Manage AWS Security Groups"
  newparam(:name)
  ensurable
  newproperty(:description)
  newproperty(:vpc)
  autorequire(:aws_vpc) do
    self[:vpc]
  end
  newproperty(:tags)
  newproperty(:authorize_ingress, :parent => Puppet_X::Bobtfish::ListOfHashesProperty)
  newproperty(:authorize_egress, :parent => Puppet_X::Bobtfish::ListOfHashesProperty)
end

