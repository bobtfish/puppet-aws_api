require File.expand_path(File.join(File.dirname(__FILE__), '..', 'puppet_x', 'bobtfish', 'aws_api.rb'))
puts "AWS_PROFILE is #{ENV['AWS_PROFILE']}"

Facter.add(:aws_endpoints) do
  setcode do
    Hash[Puppet_X::Bobtfish::Aws_api.ec2.regions.map {|region|
      [region.name, region.endpoint]
    }]
  end
end
