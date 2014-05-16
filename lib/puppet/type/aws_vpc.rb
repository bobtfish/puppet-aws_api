Puppet::Type.newtype(:aws_vpc) do
  @doc = "Manage AWS vpcs"
  newparam(:name)
  ensurable
  newproperty(:id)
  newproperty(:region)
  newproperty(:cidr)
  newproperty(:dhcp_options)
  autorequire(:aws_dopts) do
    self[:dhcp_options]
  end
  newproperty(:instance_tenancy)
  newproperty(:tags)
  autorequire(:aws_credentials) do
    requires = []
    res = catalog.resources.find_all do |r|
      r.is_a?(Puppet::Type.type(:aws_credential))
    end
    res.each { |r| requires << r[:name] }
  end
  newproperty:account
  def self.instances(*args)
    self.provider(:api).instances(*args).collect do |instance|
      result = new(:name => instance.name, :provider => instance)
      properties.each { |name| result.newattr(name) }
      result
    end.flatten
  end
end

