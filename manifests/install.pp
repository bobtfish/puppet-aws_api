# == Class aws_api::install
#
class aws_api::install {
  include aws_api::params

  package { $aws_api::params::package_name:
    ensure => present,
  }
}
