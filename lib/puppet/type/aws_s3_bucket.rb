Puppet::Type.newtype(:aws_s3_bucket) do
  @doc = "An S3 file bucket"
  newparam(:name)
  ensurable do
    self.defaultvalues
    newvalue(:purged) do
      # Recursively purge
      @resource.provider.purge
    end
  end
  newproperty(:region)
end

