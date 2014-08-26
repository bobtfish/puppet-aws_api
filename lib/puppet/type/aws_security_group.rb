require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'puppet_x', 'bobtfish', 'unordered_list_prop.rb'))

Puppet::Type.newtype(:aws_security_group) do
  @doc = "Manage AWS Security Groups"
  newparam(:name)
  ensurable
  newproperty(:description)

  autorequire(:aws_vpc) do
    self.vpc_name
  end
  newproperty(:tags)
  newproperty(:authorize_ingress, :parent => Puppet_X::Bobtfish::UnorderedValueListProperty)
  newproperty(:authorize_egress, :parent => Puppet_X::Bobtfish::UnorderedValueListProperty)

  def vpc_name
    self[:name].split(':').first
  end

  def sg_name
    self[:name].split(':').last
  end
end
