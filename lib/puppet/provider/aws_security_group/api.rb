require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))


Puppet::Type.type(:aws_security_group).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods
  remove_method :tags= # We want the method inherited from the parent

  def self.new_from_aws(region_name, item, tags=nil)
    tags ||= item.tags.to_h
    name = tags.delete('Name') || item.id
    if item.vpc_id
      vpc = ec2.regions[region_name].vpcs[item.vpc_id].tags['Name']
    else
      vpc = nil
    end
    get_perms = Proc.new do |perm|
      if perm.port_range
        ports = [perm.port_range.first, perm.port_range.last].map(&:to_s)
        ports = ports[0] if ports[0] == ports[1]
      else
        ports = []
      end
      {
        'protocol' => perm.protocol.to_s,
        'ports' => ports,
        'sources' => perm.ip_ranges + perm.groups.map {|s| s.tags['Name']},
      }
    end

    ingress = merge_sources(item.ingress_ip_permissions.map(&get_perms))
    egress = merge_sources(item.egress_ip_permissions.map(&get_perms))

    new(
      :aws_item         => item,
      :name             => name,
      :id               => item.id,
      :ensure           => :present,
      :description      => item.description,
      :vpc              => vpc,
      :tags             => tags,
      :authorize_ingress => ingress,
      :authorize_egress  => egress
    )
  end

  def self.instances_class; AWS::EC2::SecurityGroup; end

  read_only(:description, :vpc, :authorize_ingress, :authorize_egress)

  def authorize_ingress=(rules)
    set_rules(@property_hash[:aws_item], :authorize_ingress, rules)
  end

  def authorize_egress=(rules)
    set_rules(@property_hash[:aws_item], :authorize_egress, rules)
  end

  def create
    vpc = find_vpc_item_by_name(resource[:vpc])
    sg = vpc.security_groups.create(
      resource[:name],
      :description => resource[:description],
      :vpc => vpc
    )

    tag_with_name sg, resource[:name]
    tags = resource[:tags] || {}
    tags.each { |k,v| sg.add_tag(k, :value => v) }

    set_rules(sg, :authorize_ingress, resource[:authorize_ingress])
    set_rules(sg, :authorize_egress, resource[:authorize_egress])

    sg
  end
  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end

  private

  def self.merge_sources(perms)
    merged = {}
    perms.each do |perm|
      if merged[[perm['protocol'], perm['ports']]]
        merged[[perm['protocol'], perm['ports']]]['sources'] += perm['sources']
      else
        merged[[perm['protocol'], perm['ports']]] = perm
      end
    end
    merged.values
  end


  def set_rules(sg, method, rules)
    listing_method_for = {
      :authorize_ingress => :ingress_ip_permissions,
      :authorize_egress => :egress_ip_permissions
    }
    sg.send(listing_method_for[method]).each do |rule|
      rule.revoke
    end
    if rules
      rules.each do |perm|
        protocol = perm['protocol'].to_sym
        sources = perm['sources'].map do |source|
          if source =~ /^\d+\.\d+\.\d+\.\d+\/\d+$/
            # IP CIDR
            source
          else
            # must be another SG
            sg.vpc.security_groups.with_tag('Name', source).first
          end
        end
        case method
        when :authorize_egress
          sg.authorize_egress *sources, :protocol => protocol, :ports=>perm['ports']
        when :authorize_ingress
          sg.authorize_ingress protocol, perm['ports'], *sources
        end

      end
    end
  end
end

