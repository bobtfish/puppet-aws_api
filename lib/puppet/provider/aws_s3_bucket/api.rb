require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_s3_bucket).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do
  flushing_resource_methods :read_only => [:region]

  find_region_from :region

  primary_api :s3, :collection => :buckets

  # Oddly, S3 buckets must be fetched without a region constraint even if they do live
  # in different regions
  def self.regions
    [nil]
  end
  def self.aws_items_for_region(region)
    s3.buckets
  end

  ensure_from_state(
    true => :present,
    false => :absent,
    &:exists?
  )

  def init_property_hash
    super
    map_init(:name)
    init :region, aws_item.location_constraint
  end

  def substitutions
    {
      :url => aws_item.url
    }
  end

  def flush_when_ready
    flushing :ensure => :purged do
      aws_item.delete!
      return
    end
    flushing :ensure => :absent do
      aws_item.delete
      return
    end

    flushing :ensure => :present do
      if resource[:region] == 'us-east-1'
        # yep - this is a special problem with the S3 bucket API alone
        s3.buckets.create(resource[:name])
      else
        s3.buckets.create(resource[:name],
          :location_constraint => resource[:region]
        )
      end
    end
  end


end

