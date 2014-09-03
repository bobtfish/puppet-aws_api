require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_rrset).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do

  flushing_resource_methods :read_only => [:zone]

  find_region_from nil

  primary_api :r53

  ensure_from_state(
    true => :present,
    false => :absent,
    &:exists?
  )

  def self.aws_items_for_region(region)
    r53.hosted_zones.collect { |zone| zone.rrsets.to_a}.flatten
  end

  def init_property_hash
    super
    map_init(
      :ttl,
    )
    init :zone, r53.hosted_zones[aws_item.hosted_zone_id].name
    init :name, "#{record_type} #{record_name}"
    init :value, aws_item.resource_records.collect {|r| r[:value]} # match targets?
  end

  def record_type
    aws_item.type
  end

  def record_name
    aws_item.name
  end

  def flush_when_ready
    flushing :ensure => :absent do
      aws_item.delete
      return
    end

    flushing :ensure => :present do
      zone = lookup(:aws_hosted_zone, resource[:zone]).aws_item

      # Now create
      zone.rrsets.create(
        resource.record_name,
        resource.record_type,
        :ttl => resource[:ttl].to_i,
        :resource_records => self.subbed_record_values_for_aws,
      )
    end

    flushing :value do |value|
      aws_item.resource_records = self.subbed_record_values_for_aws
      aws_item.update()
    end

    flushing :ttl do |ttl|
      aws_item.ttl = ttl
      aws_item.update()
    end
  end
  def split_name
    @split_name ||= @property_hash[:name].split(' ')
  end

  def subbed_record_values_for_aws
    subbed_record_values.collect do |record|
      {:value => record}
    end
  end

  def subbed_record_values
    targets = resource[:targets]
    targets = [targets]  unless targets.is_a? Array
    record_values = resource[:value]
    record_values = [record_values]  unless targets.is_a? Array
    if targets.nil? or targets.empty?
      # nothing to fill with, we're not doing substitutions
      return record_values
    end
    record_values.each_with_index.map do |record, i|
      target = targets[i]
      type_name = target.type.downcase.to_sym
      provider = lookup(type_name, target.title)
      provider.class.induce_prefetch(resource.catalog, type_name)

      provider = lookup(type_name, target.title)

      record % provider.substitutions
    end

  end


end

