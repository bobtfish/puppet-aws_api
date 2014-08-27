require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'aws_api.rb'))


Puppet::Type.type(:aws_hosted_zone).provide(:api, :parent => Puppet_X::Bobtfish::Aws_api) do
  mk_resource_methods

  find_region_from nil

  primary_api :r53, :collection => :hosted_zones

  def self.instance_from_aws_item(region, item)
    new(
      :aws_item         => item,
      :name             => item.name,
      :ensure           => :present,
    )
  end

  def create
    unless resource[:name].end_with? '.'
      raise "Hosted zone name must terminate with a dot - e.g. 'example.com.', not 'example.com' "
    end
    r53.hosted_zones.create(resource[:name])
  end
  def destroy
    aws_item.delete
    @property_hash[:ensure] = :absent
  end

  def purge
    aws_item.rrsets.each do |rrset|
      # can't delete NS/SOA to self
      unless %w(NS SOA).include?(rrset.type)  and rrset.name == aws_item.name
        rrset.delete
      end
    end
    aws_item.delete
    @property_hash[:ensure] = :purged
  end

end

