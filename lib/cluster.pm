package cluster;

use Moose::Util::TypeConstraints;
use Moose;
use IO::Socket::INET;
use IO::Socket::Multicast;
use namespace::autoclean;


subtype 'port',
  as      'Int',
  where   { (0 <= $_) && ($_ <= 65535) },
  message { "Port '$_' does not appear to be a service port." },
;

subtype 'proto',
  as      'Str',
  where   { ($_ eq 'udp') || ($_ eq 'tcp') },
  message { "Protocol '$_' does not appear to be a multicast protocol." },
;

has 'port'      => (
  is         => 'rw',
  isa        => 'port',
  predicate  => 'has_port',
);

has 'address'   => (
  is         => 'rw',
  isa        => 'ip_addr',
  predicate  => 'has_address',
);

has 'proto'     => (
  is         => 'rw',
  isa        => 'proto',
  default    => 'udp',
);

has 'iface'     => (
  is         => 'rw',
  isa        => 'ip_addr',
  predicate  => 'has_iface',
);

has 'members'   => (
  is         => 'rw',
  isa        => 'ArrayRef[member]',
  auto_deref => 1,
);

has 'send_sock' => (
  is         => 'rw',
  isa        => 'IO::Socket',
);

has 'recv_sock' => (
  is         => 'rw',
  isa        => 'IO::Socket',
);

sub join {
  my $self   = shift;
  my $member = shift;

  ($self->has_address() && $self->has_port())
    || die("Both address and port must be defined to join cluster.\n");

  (defined($member))
    || die("Must specify member object to join cluster.\n");

  my $ip     = $member->ip();

  $self->iface($ip);

  # create read socket

  my $recv_s = IO::Socket::Multicast->new(
    Proto     => $self->proto(),
    ReuseAddr => 1,
    LocalPort => $self->port(),
  );

  my $dest   = $self->address()->addr();

  $recv_s->mcast_add($dest)
    || die("Cannot join multicast group '$dest'\n");

  $self->recv_sock($recv_s);

  my $send_s = IO::Socket::Multicast->new(
    Proto     => $self->proto(),
    ReuseAddr => 1,
    PeerAddr => $dest . ':' . $self->port(),
  );

  $self->send_sock($send_s);

  $self->announce();
}

sub announce {
  my $self   = shift;
  my $timer  = gmtime();
  my $mesg   = "$timer: " . $self->iface()->addr();

  $self->send_sock()->send($mesg)
    || die("Cannnot send message '$mesg' to group: $!\n");

  return(0);
}

__PACKAGE__->meta->make_immutable;


1;
