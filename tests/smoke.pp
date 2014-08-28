# some very lazy smoke tests


aws_vpc { 'main':
  region => 'us-east-1'
}
aws_subnet {"main":
  vpc => 'main'
}

aws_ec2_instance {"node":
  image_id => 'bogus',
  instance_type => 't1.whatever',
  subnet => 'main',
  key_name => 'default'
}

aws_rrset {"SRV _sip._tcp.exampe.com.":
  ttl => 123,
  zone => 'example.com.'
}

aws_hosted_zone{ 'example.com.':

}