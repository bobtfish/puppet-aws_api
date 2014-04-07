# git clone git@github.com:bobtfish/puppet-aws_api.git
# cd puppet-aws_api
# bundle install
# bundle exec puppet apply tests/create.pp --libdir lib

aws_dopts { 'eu-west1-dev':
  ensure               => 'present',
  domain_name          => 'dev.yelpcorp.com',
  region               => 'eu-west-1',
  ntp_servers          => ['10.10.1.4'],
  netbios_name_servers => ['10.10.1.4'],
  domain_name_servers  => ['10.10.1.4']
}

aws_vpc { 'eu-west-1deveu':
  ensure           => 'present',
  cidr             => '10.84.0.0/16',
  dhcp_options     => 'eu-west1-dev',
  instance_tenancy => 'default',
  region           => 'eu-west-1',
}

aws_subnet { 'euwest1cdevc back tier subnet':
  ensure => 'present',
  vpc    => 'eu-west-1deveu',
  az     => 'eu-west-1c',
  cidr   => '10.84.1.0/24',
  tags   => {
    'ephemeral' => false,
    'habitat'   => 'euwest1cdevc',
    'tier'      => 'internal'
  },
}

aws_vgw { 'eu-west-1deveu':
  ensure            => present,
  vpn_type          => 'ipsec.1',
  availability_zone => 'eu-west-1a',
  vpc               => 'eu-west-1deveu'
}

aws_cgw { 'eu-west-1deveu_6000':
  ensure     => present,
  ip_address => '208.178.67.126',
  bgp_asn    => 65000,
  region     => 'eu-west-1',
}

aws_vpn { 'eu-west-1deveu_vpn':
  ensure => present,
  vgw    => 'eu-west-1deveu',
  cgw    => 'eu-west-1deveu_6000',
  type   => 'ipsec.1',
}

aws_igw { 'eu-west-1deveu':
  ensure => present,
  vpc    => 'eu-west-1deveu',
}

aws_routetable { 'euwest1deveu':
  vpc                    => 'eu-west-1dev',
  main                   => true,
  associated_subnets     => 'euwest1cdeveu back tier subnet',
  distribute_routes_from => [ Aws_igw['eu-west-1deveu'], Aws_vgw['eu-west-1deveu'] ]
}

