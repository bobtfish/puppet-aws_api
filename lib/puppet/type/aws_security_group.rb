require 'puppetx/bobtfish/type_helpers'

Puppet::Type.newtype(:aws_security_group) do
  @doc = "Manage AWS Security Groups"
  newparam(:name)
  ensurable
  newproperty(:description)

  autorequire(:aws_vpc) do
    self.vpc_name
  end
  newproperty(:tags)
  newproperty(:authorize_ingress, :parent => Puppetx::Bobtfish::UnorderedValueListProperty)
  newproperty(:authorize_egress, :parent => Puppetx::Bobtfish::UnorderedValueListProperty)

  def vpc_name
    self[:name].split(':').first
  end

  def sg_name
    self[:name].split(':').last
  end
end
