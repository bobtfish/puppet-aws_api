require 'puppetx/bobtfish/type_helpers'

Puppet::Type.newtype(:aws_security_group) do
  @doc = "Manage AWS Security Groups"
  newparam(:name)
  ensurable
  newproperty(:description)

  autorequire(:aws_vpc) do
    self.vpc_name
  end

  newproperty(:tags) do
    include Puppetx::Bobtfish::EnsureHashValue
  end

  newproperty(:authorize_ingress) do
    include Puppetx::Bobtfish::SortedDeepCompare
    include Puppetx::Bobtfish::PermissionCollection
  end

  newproperty(:authorize_egress) do
    include Puppetx::Bobtfish::SortedDeepCompare
    include Puppetx::Bobtfish::PermissionCollection
  end

  def vpc_name
    self[:name].split(':').first
  end

  def sg_name
    self[:name].split(':').last
  end
end
