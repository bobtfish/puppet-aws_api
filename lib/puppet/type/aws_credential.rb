Puppet::Type.newtype(:aws_credential) do
  newparam(:name)
  newparam(:user)
  newparam(:password)
end

