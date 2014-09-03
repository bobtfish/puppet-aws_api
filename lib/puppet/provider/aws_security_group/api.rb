require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_security_group).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do
  include Puppetx::Bobtfish::TaggableProvider

  flushing_resource_methods :read_only => [
    :description, :vpc]

  def self.find_region(type)
    vpc = catalog_lookup(type.catalog, :aws_vpc, type.vpc_name)
    vpc.class.find_region(vpc.resource)
  end

  primary_api :ec2, :collection => :security_groups

  ensure_from_state(
    true => :present,
    false => :absent,
    &:exists?
  )

  def init_property_hash
    super
    map_init(:description)
    if aws_item.vpc?
      vpc_name = aws_item.vpc.tags['Name'] || aws_item.vpc_id
      init :vpc, vpc_name
      init :name, "#{vpc_name}:#{aws_item.name}"
    end
    init :authorize_ingress, unmunge_rules(aws_item.ingress_ip_permissions)
    init :authorize_egress, unmunge_rules(aws_item.egress_ip_permissions)
  end

  def flush_when_ready
    flushing :ensure => :absent do
      aws_item.delete
      return
    end

    flushing :ensure => :present do
      also_flush :authorize_ingress, :authorize_egress
      collection.create(resource[:name],
        :description => resource[:description],
        :vpc => lookup(:aws_vpc, resource[:vpc]).aws_item
      )
    end

    flushing :authorize_ingress do |rules|
      aws_item.ingress_ip_permissions.each(&:revoke)
      rules.each do |rule|
        ports, protocol, sources = munge_rule(rule)
        aws_item.authorize_ingress protocol, ports, *sources
      end
    end

    flushing :authorize_egress do |rules|
      aws_item.egress_ip_permissions.each(&:revoke)
      rules.each do |rule|
        ports, protocol, sources = munge_rule(rule)
        aws_item.authorize_egress *sources, :protocol => protocol, :ports => ports
      end
    end
    super
  end


  private

  def unmunge_rules(rules)
    merge_sources(rules.map(&method(:unmunge_rule)))
  end

  def unmunge_rule(perm)
   if perm.port_range
      ports = [perm.port_range.first, perm.port_range.last].map(&:to_s)
      ports = ports[0] if ports[0] == ports[1]
    else
      ports = []
    end
    return {
      'protocol' => perm.protocol.to_s,
      'ports' => ports,
      'sources' => perm.ip_ranges + perm.groups.map {|s|
        if s.vpc?
          "#{s.vpc.tags['Name'] || s.vpc.vpc_id}:#{s.name}"
        else
          s.name
        end
      },
    }
  end

  def merge_sources(rules)
    merged = {}
    rules.each do |perm|
      if merged[[perm['protocol'], perm['ports']]]
        merged[[perm['protocol'], perm['ports']]]['sources'] += perm['sources']
      else
        merged[[perm['protocol'], perm['ports']]] = perm
      end
    end
    merged.values
  end


  def munge_rule(rule)
    protocol = rule['protocol'].to_sym
    sources = rule['sources'].map do |source|
      if source =~ Puppetx::Bobtfish::CIDRValidation::PATTERN
        # CIDRs go in as-is
        source
      else
        # must be another SG, grab reference
        lookup(:aws_security_group, source).aws_item
      end
    end
    return rule['ports'], protocol, sources
  end

end

