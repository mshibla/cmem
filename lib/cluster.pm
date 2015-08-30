package cluster;

use Moose::Util::TypeConstraints;
use Moose;
use IO::Socket::INET;
use IO::Socket::Multicast;
use Socket;
use IO::Select;
use namespace::autoclean;
use List::Compare;
use DateTime;
use ip_addr;
use member;


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

has 'me'        => (
  is         => 'rw',
  isa        => 'member',
);

has 'send_sock' => (
  is         => 'rw',
  isa        => 'IO::Socket',
);

has 'recv_sock' => (
  is         => 'rw',
  isa        => 'IO::Socket',
);

has 'selector'  => (
  is         => 'rw',
  isa        => 'IO::Select',
);

has 'skew'      => (
  # seconds
  is         => 'rw',
  isa        => 'Int',
  default    => 60,
);

has 'timeout'   => (
  # seconds
  is         => 'rw',
  isa        => 'Int',
  default    => 300,
);

has 'version'   => (
  is         => 'ro',
  isa        => 'Str',
  default    => '0.1.0-ALPHA',
);


sub cjoin {
  my $self        = shift;
  my $member      = shift;

  ($self->has_address() && $self->has_port())
    || die("Both address and port must be defined to join cluster.\n");

  (defined($member))
    || die("Must specify member object to join cluster.\n");

  my $ip          = $member->ip();

  $self->iface($ip);

  # we might pass through this routine more than once, e.g. if there's high load w/ renice

  if (!($self->recv_sock())) {
    # create read socket

    my $recv_s    = IO::Socket::Multicast->new(
      Proto     => $self->proto(),
      ReuseAddr => 1,
      LocalPort => $self->port(),
    );

    my $dest      = $self->address()->addr();

    $recv_s->mcast_add($dest)
      || die("Cannot join multicast group '$dest'\n");

    $self->recv_sock($recv_s);

    if (!($self->selector())) {
      # create selector and add read socket

      my $sel     = IO::Select->new();
      $sel->add($recv_s);
      $self->selector($sel);
    }
  }

  if (!($self->send_sock())) {
    # create write socket

    my $dest      = $self->address()->addr();
    my $send_s    = IO::Socket::Multicast->new(
      Proto     => $self->proto(),
      ReuseAddr => 1,
      PeerAddr  => $dest . ':' . $self->port(),
    );

    $self->send_sock($send_s);
  }

  my $msg         = "join " . $self->iface()->addr();

  $self->announce($msg);
}


sub heartbeat {
  my $self        = shift;
  my $msg         = "alive " . $self->iface()->addr() . " " . DateTime->now()->epoch();

  $self->announce($msg);
}


sub leave {
  my $self        = shift;
  my $msg         = "leave " . $self->iface()->addr();

  $self->announce($msg)
}


sub membership {
  my $self        = shift;
  my @members     = map { $_->ip() } $self->members();
  my $msg         = join(' ', @members);

  $self->announce($msg);
}


sub announce {
  my $self        = shift;
  my $mesg        = shift;
  my $timer       = DateTime->now()->epoch();
  my $message     = "$timer: [" . $self->iface()->addr() . "] $mesg";

  $self->send_sock()->send($message)
    || die("Cannnot send message '$message' to group: $!\n");

  return(0);
}


sub remove_member {
  my $self        = shift;
  my $member      = shift;
  my @members     = $self->members();
  my @new         = grep { $_->ip()->addr() ne $member } @members;
  
  $self->members(\@new);
}


sub check_heartbeats {
  my $self        = shift;
  my $timeout     = $self->timeout();
  my $timer       = DateTime->now()->epoch();
  my @members     = $self->members();

  MEMBER:
  foreach my $member (@members) {
    my $elapsed   = $timer - $member->heartbeat();
    if ($elapsed > $timeout) {
      # stale heartbeat, remove cluster member
      warn("Member '$member' has stale heartbeat: '$elapsed' > '$timeout'.\n");
      my $addr    = $member->ip()->addr();
      if ($self->me()->ip()->addr() eq $addr) {
        # need to rejoin cluster, something happened and I've timed out
        my $m1    = $self->me();
        $m1->heartbeat($timer);
        $self->cjoin($m1);
      } else {
        $self->remove_member($member->ip()->addr());
      }
    }
  }
}


sub receive {
  my $self        = shift;
  my $sock        = shift;
  my $timer       = DateTime->now()->epoch();
  my $data        = '';
  my $bufsize     = 1024;
  my $sender      = $sock->recv($data, $bufsize);
  my $mesg        = $data;
  my $port;
  my $ip;
  my $sip;

  if ($sender) {
    ($port, $ip)  = unpack_sockaddr_in($sender);
    $sip          = inet_ntoa($ip);
  }

  LOOP:
  while (length($data) == $bufsize) {
    
    # may still be data to receive
    
    ($sock->has_exception())
      && last LOOP;

    my $send      = $sock->recv($data, $bufsize);

    (length($data))
      && ($mesg .= $data);

    if (defined($send)) {
      if ($send ne $sender) {
        # not sure what this is
        my($np, $ni) = unpack_sockaddr_in($send);
        die("Sender '$ni' has changed from initial sender '$sip' within the same message.\n");
      }
    }
  }

  if ($mesg !~ m/^(\d+): \[([^\]\s]+)\] (.*)/) {
    warn("Sender '$sip' send a malformed message '$mesg'.\n");
    return;
  }

  my $mesg_time   = $1;
  my $stated      = $2;
  my $message     = $3;

  # format of $sender may not match that of $stated sender, ignore

  # stale messages are bad

  my $skew        = $timer - $mesg_time;

  if ($skew < 0) {
    # message was received before it was sent(!)
    warn("Sender '$sip' with stated identity '$stated' has significant clock skew from us '$skew'.\n");
  } elsif ($skew > $self->skew()) {
    # message is stale
    warn("Sender '$sip' with stated identity '$stated' message '$message' delayed '$skew'.\n");
  } else {
    $self->parse($sip, $message);
  }
}


sub parse {
  my $self        = shift;
  my $sender      = shift;
  my $message     = shift;

  MESG:
  for ($message) {

    m/^join (\S+)$/       && do {
      my $joiner  = $1;
      my @members = map { $_->ip()->addr() } $self->members();
      if (grep {$_ eq $joiner} @members) {
        # already a member, maybe missed a leave message
      } else {
        my $addr  = ip_addr->new('addr' => $sender);
        my $m     = member->new(
          'name'      => $joiner,
          'ip'        => $addr,
          'heartbeat' => DateTime->now->epoch(),
        );
        push(@members, $m);
        $self->members(\@members);
      }
      # inform joiner of cluster membership
      my $msg     = "cluster @members";
      $self->announce($msg);
      last MESG;
    };
    
    m/^alive (\S+) (\d+)$/      && do {
      my $member   = $1;
      my $timer    = $2;
      my @members  = $self->members();
      my $found    = 0;
      M:
      foreach my $m (@members) {
        ($m->ip()->addr() eq $member)
          || next M;
        $found++;
        $m->heartbeat(DateTime->now()->epoch());
        last M;
      }
      $self->members(\@members);
      last MESG;
    };
    
    m/^leave (\S+)$/      && do {
      my $member   = $1;
      $self->remove_member($member);
      last MESG;
    };
    
    m/^cluster (.*)$/     && do {
      my $m_list   = $1;
      my @stated   = split(" ", $m_list);
      my @members  = map { $_->ip()->addr() } $self->members();
      my $lc       = List::Compare->new(\@stated, \@members);
      my @in_s     = $lc->get_Lonly();
      my @in_m     = $lc->get_Ronly();
      if (@in_s) {
        warn("Sender '$sender' reports members '@in_s' which we don't recognize.\n");
      } elsif (@in_m) {
        warn("Sender '$sender' does not recognize members '@in_m'.\n");
      }
      last MESG;
    };
  }
}


__PACKAGE__->meta->make_immutable;


1;
