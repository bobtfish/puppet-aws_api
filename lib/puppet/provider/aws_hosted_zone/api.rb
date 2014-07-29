require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))


Puppet::Type.type(:aws_hosted_zone).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  
  def self.new_from_aws(item)
    new(
      :aws_item         => item,
      :name             => item.name,
      :ensure           => :present,
    )
  end
  def self.instances
    r53.hosted_zones.collect { |item| new_from_aws(item) }
  end

  
  def create
    zone = r53.create(resource[:name])
    wait_until_ready(zone)
    zone
  end
  def destroy
    @property_hash[:aws_item].delete
  end

  def wait_until_ready(zone)
    until zone.change_info.status == 'PENDING'
      puts "Zone status is: #{zone.change_info.status}"
      sleep 1
    end
  end

end

