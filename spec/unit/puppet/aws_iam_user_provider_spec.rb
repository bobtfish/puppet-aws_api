#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:aws_iam_user).provider(:api)

describe provider_class do
  context "with 2 resources in 2 accounts" do
    let(:two_iams) {[:iam1, :iam2]}
    let(:two_regions) { [:region1, :region2] }
    let(:two_accounts) {[
      {:name => 'a', :access_key_id => 'b', :secret_access_key => 'c' },
      {:name => 'x', :access_key_id => 'y', :secret_access_key => 'z' }
    ]}
    let(:iam_mock) {
      iam_mock = double 'object'
      iam_mock.stub_chain('users').and_return(two_iams)
      iam_mock
    }

    before :each do
      expect(provider_class).to receive(:new_from_aws) do |a1, a2|
        [:iam1, :iam2].include?(a1).should be(true)
        ['a', 'x'].include?(a2).should be(true)
        :blah
      end.at_least(:once)
    end

    it "should find 4 instances" do
      provider_class.should_receive(:iam).at_least(:once).and_return(iam_mock)
      provider_class.instances(two_accounts).count.should eq(4)
    end
    it "should send a key hash to the iam method" do
      expect(provider_class).to receive(:iam) do |arg|
        arg.each_key do |k|
          puts k
          [:access_key_id, :secret_access_key].include?(k).should be(true)
        end
        iam_mock
      end.at_least(:once)
      provider_class.instances(two_accounts).count.should eq(4)
    end
  end
end
