require 'puppetx/bobtfish/aws_api'


Puppet::Type.type(:aws_hosted_zone).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do

  flushing_resource_methods

  find_region_from nil

  primary_api :r53, :collection => :hosted_zones

  ensure_from_state(
    true => :present,
    false => :absent,
    &:exists?
  )

  def init_property_hash
    super
    map_init(:name)
  end

  def flush_when_ready

    flushing :ensure => :purged do
      aws_item.rrsets.each do |rrset|
        # can't delete NS/SOA to self
        unless %w(NS SOA).include?(rrset.type)  and rrset.name == aws_item.name
          rrset.delete
        end
      end
      aws_item.delete
      return
    end

    flushing :ensure => :absent do
      aws_item.delete
      return
    end

    flushing :ensure => :present do
      collection.create(resource[:name])
    end
  end
end

