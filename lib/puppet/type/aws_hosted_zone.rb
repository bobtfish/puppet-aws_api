require 'puppetx/bobtfish/type_helpers'
Puppet::Type.newtype(:aws_hosted_zone) do
  @doc = "Manage AWS Route 53 hosted zone"
  newparam(:name) do
    desc "Domain name"
    validate do |value|
      unless value.end_with? '.'
        raise ArgumentError, "Hosted zone name must terminate with a dot - e.g. 'example.com.', not 'example.com' "
      end
    end
  end
  ensurable do
    include Puppetx::Bobtfish::Purgable
  end
end

