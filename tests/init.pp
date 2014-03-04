aws_vpc { 'us-west-1dev':
  ensure           => 'present',
  cidr             => '10.40.0.0/19',
  dhcp_options_id  => 'dopt-940a91fc',
  id               => 'vpc-b7e309df',
  instance_tenancy => 'default',
  region           => 'us-west-1',
  tags             => {'test' => 'tdoran'},
}

aws_subnet { 'uswest1cdevc back tier subnet':
  vpc_id           => 'vpc-b7e309df', # FIXME - this should be vpc => 'us-west-1dev',
  ensure           => 'present'
}

#aws_dopt { '...':
#}

#aws_igw { '...':
#}

#aws_routetable { '...':
#}

