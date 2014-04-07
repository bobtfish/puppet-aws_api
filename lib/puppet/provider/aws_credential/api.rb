Puppet::Type.type(:aws_credential).provide(:api) do
  mk_resource_methods

  def self.instances
    []
  end

end
