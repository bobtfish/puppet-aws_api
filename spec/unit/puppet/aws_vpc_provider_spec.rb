#!/usr/bin/env rspec
require 'spec_helper'

class Hash
  def to_h; self; end
end

provider_class = Puppet::Type.type(:aws_vpc).provider(:api)

class Puppet::Type::Aws_vpc::ProviderApi
  attr_reader :property_hash
end

describe provider_class do
  context "with vpc object mocked" do
    let(:instances) do
      thingy = double()
      mock_dopts = double()
      allow(mock_dopts).to receive(:tags).and_return({ 'Name' => 'mydopt' })
      allow(thingy).to receive(:tags).and_return({ 'Name' => 'foo' })
      allow(thingy).to receive(:id).and_return('vpc-6666')
      allow(thingy).to receive(:cidr_block).and_return('10.10.0.0/16')
      allow(thingy).to receive(:dhcp_options_id).and_return('FIXME')
      allow(thingy).to receive(:instance_tenancy).and_return(:default)
      expect(provider_class).to receive(:regions).and_return(['us-west-1'])
      expect(provider_class).to receive(:vpcs_for_region).and_return([thingy])
      expect(provider_class).to receive(:find_dhopts_item_by_name).with('FIXME').and_return(mock_dopts)
      provider_class.instances
    end
    if ENV['AWS_ACCESS_KEY']
      it('finds 1 vpc') { expect(instances.size).to eql(1) }
      it('has expected properties') { expect(instances[0].property_hash.reject { |k,v| k == :aws_item }).to \
        eql({:region=>"us-west-1", :cidr=>"10.10.0.0/16", :dhcp_options=> 'mydopt', :instance_tenancy=>"default", :ensure=>:present, :name=>"foo", :tags=>{}, :id=>"vpc-6666"}) }
    end
  end

  context "with 2 resources in each of 2 regions" do
    let(:type) { :vpc }

    def thing(name); double(:name => name, :tags => {'Name' => name}); end
    let(:client) { double('client',
      :"describe_#{type}s" => double(:"#{type}_set" => [:"#{type}1", :"#{type}2"])) }
    let(:region) { double('region', :client => client) }
    let(:ec2) { double('ec2', :regions => double(:[] => region)) }
    let(:aws_thing) { double('aws_thing', :aws_item => double(:id => nil)) }

    it "should find 4 instances" do
      provider_class.stub(:ec2 => ec2, :regions => [:region1, :region2])
      expect(client).to receive(:"describe_#{type}s")
      expect(provider_class).to receive(:preload) {|r, n, _, _| thing(n)}.at_least(:once)
      expect(provider_class).to receive(:new_from_aws).and_return(aws_thing).at_least(:once)
      expect(provider_class.instances.count).to eq(4)
    end
  end
end
