Puppet::Type.newtype(:aws_vpn) do
  @doc = "Manage AWS internet gateways"
  newparam(:name)
  ensurable
  newproperty(:vgw) do
  end
  autorequire(:aws_vgw) do
    self[:vgw]
  end
  newproperty(:cgw) do
  end
  autorequire(:aws_cgw) do
    self[:cgw]
  end
  validate do
  #  fail('vpc_id is required') if self[:vpc_id].nil?
  #  fail('vgw_id is required') if self[:vgw_id].nil?
  end
  newproperty(:type)
  newproperty(:routing)
  newproperty(:static_routes)
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

