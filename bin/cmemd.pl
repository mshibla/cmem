#!/usr/local/bin/perl

use strict;
use warnings;
use diagnostics;

use lib '../lib';
use ip_addr;
use member;
use cluster;

{
  my $mcast_group = ip_addr->new('addr' => '238.1.1.5');
  my $mcast_port  = 51510;
  my $ip1         = ip_addr->new('addr' => '192.168.0.9');
  my $ip2         = ip_addr->new('addr' => '192.168.0.11');
  my $m1          = member->new(
    'name' => 'talyn2',
    'ip'   => $ip1,
  );
  my $m2          = member->new(
    'name' => 'b',
    'ip'   => $ip2,
  );  
	my $cluster     = cluster->new(
    'members' => [$m1, $m2],
    'address' => $mcast_group,
    'port'    => $mcast_port,
  );

  $cluster->join($m1);

  my @members     = $cluster->members();

  print STDOUT ("Cluster contains members '@members'\n");
}
