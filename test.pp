aws_credential { 'dev':
  user => 'tom',
  password => 'insecure',
} ->
aws_subnet { 'foo': 
  account => 'dev'
}

