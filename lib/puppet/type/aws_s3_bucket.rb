Puppet::Type.newtype(:aws_s3_bucket) do
  @doc = "An S3 file bucket"
  newparam(:name)
  ensurable do
    self.defaultvalues
    newvalue :purged
  end
  newproperty(:region)
end

