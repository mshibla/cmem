package member;

use Moose;
use namespace::autoclean;
use IO::Socket::INET;
use IO::Socket::Multicast;
use overload
 '""' => sub { $_[0]->name() . '[' . $_[0]->ip()->addr() . ']' },
;

has 'name' => (
  is  => 'rw',
  isa => 'Str',
);

has 'ip' => (
  is  => 'rw',
  isa => 'ip_addr',
);


__PACKAGE__->meta->make_immutable;

1;
