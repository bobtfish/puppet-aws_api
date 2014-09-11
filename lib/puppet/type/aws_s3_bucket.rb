require 'puppetx/bobtfish/type_helpers'
Puppet::Type.newtype(:aws_s3_bucket) do
  @doc = "An S3 file bucket"
  newparam(:name) do
    validate do |value|
      unless (6..63).include? value.size
        raise ArgumentError, "Bucket names must be at least 3 and no more than 63 characters long."
      end
      value.split('.').each do |label|
        unless label =~ /^[a-z0-9][-_a-z0-9]*[a-z0-9]$/
          raise ArgumentError, "Bucket names must be a series of one or more labels. Adjacent labels are separated by a single period (.). Bucket names can contain lowercase letters, numbers, and hyphens. Each label must start and end with a lowercase letter or a number, and must not be formatted as an IP address (e.g., 192.168.5.4)."
        end
        if label.include? '_'
          warn "#{value.inspect}: Bucket labels containing underscores are not officially supported and may not work consistently!"
        end
      end
    end
  end
  ensurable do
    include Puppetx::Bobtfish::Purgable
  end
  newproperty(:region) do
    def insync?(is)
      if is.nil? or is == 'us-east-1'
        should.nil? or should == 'us-east-1'
      else
        super
      end
    end
  end
end

