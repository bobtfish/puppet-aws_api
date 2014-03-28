#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:aws_credential).provider(:api)

describe provider_class do
  let(:instances) do
    provider_class.instances
  end

  it('does not have any instances') do
    expect(instances.size).to eql 0
  end
end

