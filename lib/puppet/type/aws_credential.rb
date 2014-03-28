Puppet::Type.newtype(:aws_credential) do
  @doc = "Manage AWS credentials"
  newparam(:name)
  newproperty(:access_key)
  newproperty(:secret_key)
end

