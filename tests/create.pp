# git clone git@github.com:bobtfish/puppet-aws_api.git
# cd puppet-aws_api
# bundle install
# bundle exec puppet apply tests/create.pp --libdir lib

# dopt-d1a9a3b3
#aws_dopt { 'eu-west1-dev':
#  ensure => present
#  ... TODO
#}

# vpc-5f7f613d
aws_vpc { 'eu-west-1deveu':
  ensure           => 'present',
  cidr             => '10.84.0.0/16',
#  dhcp_options     => 'eu-west-1-dev',
  instance_tenancy => 'default',
  region           => 'eu-west-1',
  tags             => {'test' => 'tdoran'},
}

#aws_vgw { 'eu-west-1deveu':
#  type => 'ipsec.1',
#  vpc    => 'us-west-1dev'
#}

#aws_cgw { 'eu-west-1deveu_6000':
#  ensure => present,
#  ip     => '208.178.67.126',
#  asn    => 65000,
#  vpc    => 'us-west-1dev'
#}

#aws_routetable { 'euwest1deveu':
#  vpc              => 'us-west-1dev'
#  main             => true,
#}

#aws_subnet { 'euwest1deveu back tier subnet':
#  vpc              => 'us-west-1dev'
#  ensure           => 'present'
#  cidr             => '10.84.0.0/24',
#  az               => 'eu-west-1a',
#  route_table      => 'euwest1deveu'
#}

#aws_igw { '...':
# ???
#}

