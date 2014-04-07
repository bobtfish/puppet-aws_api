Puppet::Type.newtype(:aws_credential) do
  @doc = "Manage AWS credentials"
  newparam(:name)
  newparam(:access_key) do
    defaultto { raise ArgumentError "access_key is mandatory" }
  end
  newparam(:secret_key) do
    defaultto { raise ArgumentError "secret_key is mandatory" }
  end
end

