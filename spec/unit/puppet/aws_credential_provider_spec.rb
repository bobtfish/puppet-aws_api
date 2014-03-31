#!/usr/bin/env rspec
require 'spec_helper'

type_class = Puppet::Type.type(:aws_credential)
provider_class = type_class.provider(:api)

describe provider_class do
  let(:instances) { provider_class.instances }

  it('does not have any instances') do
    expect(instances.size).to eql 0
  end
end

describe type_class do
  it "should be able to create an instance" do
    described_class.new(:name => 'foo').should_not be_nil
  end

  [:access_key, :secret_key].each do |param|
    it "should accept #{param} parameter" do
      described_class.attrtype(param).should == :property
    end
  end
end

