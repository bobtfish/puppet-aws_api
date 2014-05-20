Puppet::Type.newtype(:aws_test_creds) do
  @doc = "Run tests against credential backend :)"
  newparam(:name)
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

