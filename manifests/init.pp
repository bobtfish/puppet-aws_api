# == Class: aws_api
#
# Full description of class aws_api here.
#
# === Parameters
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#
class aws_api (
) inherits aws_api::params {

  # validate parameters here

  class { 'aws_api::install': } ->
  class { 'aws_api::config': } ~>
  class { 'aws_api::service': } ->
  Class['aws_api']
}
