require 'puppetx/bobtfish/aws_api'

Facter.add(:aws_endpoints) do
  setcode do
    Hash[Puppetx::Bobtfish::Aws_api.ec2.regions.map {|region|
      [region.name, region.endpoint]
    }]
  end
end
