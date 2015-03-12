#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:aws_subnet).provider(:api)

describe provider_class do
  context "with 2 resources in each of 2 regions" do
    let(:type) { :subnet }

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

