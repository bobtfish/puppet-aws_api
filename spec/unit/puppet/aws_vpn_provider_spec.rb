#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:aws_vpn).provider(:api)

describe provider_class do
  context "with 2 resources in each of 2 regions in 2 accounts" do
    let(:two_vpns) {[:vpn1, :vpn2]}
    let(:two_regions) { [:region1, :region2] }
    let(:two_accounts) {[
      {:name => 'a', :access_key_id => 'b', :secret_access_key => 'c' },
      {:name => 'x', :access_key_id => 'y', :secret_access_key => 'z' }
    ]}
    let(:ec2_mock) {
      ec2_mock = double 'object'
      ec2_mock.stub_chain('regions.[].vpn_connections').and_return(two_vpns)
      ec2_mock
    }

    before :each do
      provider_class.should_receive(:regions).and_return(two_regions)
      expect(provider_class).to receive(:new_from_aws) do |a1, a2, a3|
        [:region1, :region2].include?(a1).should be(true)
        [:vpn1, :vpn2].include?(a2).should be(true)
        ['a', 'x'].include?(a3).should be(true)
        :blah
      end.at_least(:once)
    end

    it "should find 8 instances" do
      provider_class.should_receive(:ec2).at_least(:once).and_return(ec2_mock)
      provider_class.instances(two_accounts).count.should eq(8)
    end
    it "should send a key hash to the ec2 method" do
      expect(provider_class).to receive(:ec2) do |arg|
        arg.each_key do |k|
          [:access_key_id, :secret_access_key].include?(k).should be(true)
        end
        ec2_mock
      end.at_least(:once)
      provider_class.instances(two_accounts).count.should eq(8)
    end
  end


end

