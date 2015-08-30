#!/usr/local/bin/perl

use strict;
use warnings;
use diagnostics;
use DateTime;
use lib '../lib';
use ip_addr;
use member;
use cluster;


sub setup {
  my $cluster      = shift;
  my $listen_port  = shift;
  my $listen       = IO::Socket::INET->new(
    Listen => 1,
    LocalPort => $listen_port,
  );

  (defined($listen))
    || die("Cannot create listener on port '$listen_port': $!\n");

  return($listen);
}


{
  my $timeout      = 10; # seconds
  my $interval     = 60; # seconds
  my $mcast_group  = ip_addr->new('addr' => '238.1.1.5');
  my $mcast_port   = 51510;
  my $listen_port  = 51511;

  # IP addresses are checked for IPv4-ness via ip_addr class

  my $ip1          = ip_addr->new('addr' => '192.168.0.9');

  # first member of the cluster is myself

  my $m1           = member->new(
    'name'      => 'talyn2',
    'ip'        => $ip1,
    'heartbeat' => DateTime->now()->epoch(),
  );

  # create / join the cluster

  my $cluster      = cluster->new(
    'members'   => [$m1],
    'address'   => $mcast_group,
    'port'      => $mcast_port,
  );

  # announce my join to the cluster

  $cluster->cjoin($m1);

  # get selector for reading

  my $sel          = $cluster->selector();

  # setup listener for third-party clients

  my $listen       = setup($cluster, $listen_port);

  # add to selector

  $sel->add($listen);
  $cluster->selector($sel);

  # main loop until shutdown

  my $start        = DateTime->now()->epoch();

  LOOP:
  while (1) {
    my @ready      = $sel->can_read($timeout);

    READ:
    foreach my $reader (@ready) {

      if ($reader == $listen) {

        # third-party client, report cluster membership only, at present
        
        my $client = $listen->accept();
        my @membs  = $cluster->members();

        MEMBER:
        foreach my $member (@membs) {
          # the joys of overloading quote operators
          $client->send("$member\n");
        }

        # end client connection, we never added to selector, no need to remove

        $client->close();

      } elsif ($reader == $cluster->recv_sock()) {

        # cluster data

        $cluster->receive($cluster->recv_sock());
      }
    }

    my $now        = DateTime->now()->epoch();

    if ($now - $interval > $start) {
      $cluster->heartbeat();
      $start       = $now;
    }
  }

  $cluster->leave();

  exit(0);
}
