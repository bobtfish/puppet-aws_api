# git clone git@github.com:bobtfish/puppet-aws_api.git
# cd puppet-aws_api
# bundle install
# bundle exec puppet apply tests/init.pp --libdir lib

Aws_vpc['eu-west-1deveu'] ->
aws_dopts { 'eu-west1-dev':
  ensure      => 'absent',
  domain_name => 'eu-west-1.compute.internal',
  region      => 'eu-west-1',
}

aws_subnet { 'euwest1cdevc back tier subnet':
  ensure => 'absent',
  vpc    => 'eu-west-1deveu',
  az     => 'eu-west-1c',
  cidr   => '10.84.1.0/24',
  tags   => {
    'ephemeral' => false,
    'habitat'   => 'euwest1cdevc',
    'tier'      => 'internal'
  },
}
->
aws_vpc { 'eu-west-1deveu':
  ensure           => 'absent',
  cidr             => '10.84.0.0/16',
#  dhcp_options     => 'eu-west-1-dev',
  instance_tenancy => 'default',
  region           => 'eu-west-1',
  tags             => {'test' => 'tdoran'},
}
aws_igw { 'eu-west-1deveu':
  ensure => absent,
  vpc    => 'eu-west-1deveu',
}
->Aws_vpc['eu-west-1deveu']

aws_vgw { 'eu-west-1deveu':
  ensure            => absent,
  vpn_type          => 'ipsec.1',
  availability_zone => 'eu-west-1a',
  vpc               => 'eu-west-1deveu'
} ->Aws_vpc['eu-west-1deveu']

aws_vpn { 'eu-west-1deveu_vpn':
  ensure     => absent,
  vgw => 'eu-west-1deveu',
  cgw => 'eu-west-1deveu_6000',
  type => 'ipsec.1',
} -> Aws_cgw['eu-west-1deveu_6000']
Aws_vpn['eu-west-1deveu_vpn']
->
Aws_vgw['eu-west-1deveu']

aws_cgw { 'eu-west-1deveu_6000':
  ensure     => absent,
  ip_address => '208.178.67.126',
  bgp_asn    => 65000,
} ->Aws_vpc['eu-west-1deveu']

#aws_routetable { 'euwest1deveu':
#  vpc              => 'us-west-1dev'
#  main             => true,
#}

