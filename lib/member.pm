package member;

use Moose;
use namespace::autoclean;
use overload
 '""' => sub { $_[0]->name() . '[' . $_[0]->ip()->addr() . ']' },
;

has 'name'      => (
  is  => 'rw',
  isa => 'Str',
);

has 'ip'        => (
  is  => 'rw',
  isa => 'ip_addr',
);

has 'heartbeat' => (
  is  => 'rw',
  isa => 'Int',
);


__PACKAGE__->meta->make_immutable;

1;
