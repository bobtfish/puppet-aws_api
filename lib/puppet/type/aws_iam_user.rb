Puppet::Type.newtype(:aws_iam_user) do
  @doc = "Manage AWS IAM users"
  newparam(:name)
  ensurable
  newproperty(:path) do
    defaultto '/'
    validate do |v|
      fail("path must start and end with a /, not #{v}") unless v =~ /^\// and v =~ /\/$/
    end
  end
  newproperty(:arn)
  newproperty(:groups, :array_matching => :all)
  autorequire(:aws_credentials) do
    requires = []
    res = catalog.resources.find_all do |r|
      r.is_a?(Puppet::Type.type(:aws_credential))
    end
    res.each { |r| requires << r[:name] }
  end
  newproperty(:account)
  def self.instances(*args)
    self.provider(:api).instances(*args).collect do |instance|
      result = new(:name => instance.name, :provider => instance)
      properties.each { |name| result.newattr(name) }
      result
    end.flatten
  end
end

