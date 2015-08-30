package ip_addr;

use Moose::Util::TypeConstraints;
use Moose;
use namespace::autoclean;


subtype 'ip',
  as 'Str',
  where { m/^(?:(?:[0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}(?:[0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/ },
  message { "The string you provided ('$_') does not look like an IPv4 address." },
;

has 'addr' => (
  is  => 'rw',
  isa => 'ip',
);


__PACKAGE__->meta->make_immutable;


1;
