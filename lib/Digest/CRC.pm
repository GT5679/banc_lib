package Digest::CRC;

use strict;
use vars qw($VERSION $XS_VERSION @ISA @EXPORT_OK %_typedef);

require Exporter;

@ISA = qw(Exporter);

@EXPORT_OK = qw(
 crc8 crcccitt crc16 crcopenpgparmor crc32 crc64 crc
 crc_hex crc_base64
 crcccitt_hex crcccitt_base64
 crc8_hex crc8_base64
 crc16_hex crc16_base64
 crc16_dnp crc16_en13757
 crcopenpgparmor_hex crcopenpgparmor_base64
 crc32_hex crc32_base64
 crc64_hex crc64_base64
 crc16_xmodem_ccitt crc16_ffff_ccitt crc16_1dof_ccitt
);

$VERSION    = '0.181';
$XS_VERSION = $VERSION;
$VERSION    = eval $VERSION;

eval {
  # PERL_DL_NONLAZY must be false, or any errors in loading will just
  # cause the perl code to be tested
  local $ENV{PERL_DL_NONLAZY} = 0 if $ENV{PERL_DL_NONLAZY};
  require DynaLoader;
  local @ISA = qw(DynaLoader);
  bootstrap Digest::CRC $XS_VERSION;
  1
};

sub _reflectperl {
  my ($in, $width) = @_;
  my $out = 0;
  for(my $i=1; $i < ($width+1); $i++) {
    $out |= 1 << ($width-$i) if ($in & 1);
    $in=$in>>1;
  }
  $out;
}

# Only load the non-XS stuff on demand
defined &_crc or eval <<'ENOXS' or die $@;

sub _reflect($$) {
  my ($in, $width) = @_;
  my $out = 0;
  for(my $i=1; $i < ($width+1); $i++) {
    $out |= 1 << ($width-$i) if ($in & 1);
    $in=$in>>1;
  }
  $out;
}

sub _tabinit($$$) {
  my ($width,$poly_in,$ref) = @_;
  my @crctab;
  my $poly = $poly_in;

  if ($ref) {
    $poly = _reflect($poly,$width);
  }

  for (my $i=0; $i<256; $i++) {
    my $r = $i<<($width-8);
    $r = $i if $ref;
    for (my $j=0; $j<8; $j++) {
      if ($ref) {
	$r = ($r>>1)^($r&1&&$poly)
      } else {
	if ($r&(1<<($width-1))) {
	  $r = ($r<<1)^$poly
	} else {
	  $r = ($r<<1)
	}
      }
    }
    my $x=$r&2**$width-1;
    push @crctab, $x;
  }
  \@crctab;
}

sub _crc($$$$$$$$) {
  my ($message,$width,$init,$xorout,$refin,$refout,$cont,$tab) = @_;
  if ($cont) {
    $init = ($init ^ $xorout);
    $init = _reflect($init, $width) if $refin;
  }
  my $crc = $init;
  if ($refin == 1) {
    $crc = _reflect($crc,$width);
  } elsif ($refin > 1 and $refin <= $width) {
    $crc = _reflect($crc,$refin);
  }
  my $pos = -length $message;
  my $mask = 2**$width-1;
  while ($pos) {
    if ($refin) {
      $crc = ($crc>>8)^$tab->[($crc^ord(substr($message, $pos++, 1)))&0xff]
    } else {
      $crc = (($crc<<8))^$tab->[(($crc>>($width-8))^ord(substr $message,$pos++,1))&0xff]
    }
  }

  if ($refout && !$refin) {
    if ($refout == 1) {
      $crc = _reflect($crc,$width);
    } elsif ($refout > 1 and $refout <= $width) {
      $crc = _reflect($crc,$refout);
    }
  }

  $crc = $crc ^ $xorout;
  $crc & $mask;
}

1;

ENOXS

%_typedef = (
# name,  [width,init,xorout,refout,poly,refin,cont);
  crc8 => [8,0,0,0,0x07,0,0],
  
  crcccitt => [16,0xffff,0,0,0x1021,0,0], #base 0xffff, poly 0x1021 - A => b915
  crc16 => [16,0,0,1,0x8005,1,0],		  #base 0 poly 0x8005		- A => 0x30C0
  
  crc16_xmodem_ccitt => [16,0,0,0,0x1021,0,0],	#xmodem base 0, poly 0x1021 - A => 58E5
  #width=16 poly=0x3d65 init=0x0000 refin=true refout=true xorout=0xffff check=0xea82 name="CRC-16/DNP"
  crc16_dnp => [16,0,0xffff,1,0x3D65,1,0],	#dnp base 0, poly 0x3D65 - A => 58E5
  crc16_en13757 => [16,0,0xffff,0,0x3D65,0,0],	#13757 base 0, poly 0x3D65 - A => 58E5
  
  crc16_ffff_ccitt => [16,0xffff,0,0,0x1021,0,0],	# base FFFF, poly 0x1021 - A => B915
  crc16_1dof_ccitt	=> [16,0x1d0f,0,0,0x1021,0,0],  # base 1D0F, poly 0x1021 - A => 9479
  
  crcopenpgparmor => [24,0xB704CE,0,0,0x864CFB,0,0],
  crc32 => [32,0xffffffff,0xffffffff,1,0x04C11DB7,1,0],
  #
);


=head2 Calculs de CRC possibles

	Le module attend une chaîne ASCII.
	
	exemple d'utilisation:
	
	my $input2 = join '', 'aa'..'dd';
	my $crc16_xmodem_ccitt_t2 = crc16_xmodem_ccitt(join "", 
						map { chr($_) } 
						map { hex($_) } 
						($input2 =~ m/([a-fA-F0-9]{2})/g));	

	CRC-16	0x30C0
	
	CRC-16 (Modbus)	0x707F
	
	CRC-16 (Sick)	0x4100
	
	CRC-CCITT (XModem)	0x58E5
	
	CRC-CCITT (0xFFFF)	0xB915
	
	CRC-CCITT (0x1D0F)	0x9479
	
	CRC-CCITT (Kermit)	0x8D53
	
	CRC-DNP	0xFF9A
	
	CRC16 EN 13757 
	
	CRC-32	0xD3D99E8B

=cut

sub new {
  my $that=shift;
  my %params=@_;
  my $class = ref($that) || $that;
  my $self = {map { ($_ => $params{$_}) }
                      qw(type width init xorout refout poly refin cont)};
  bless $self, $class;
  $self->reset();
  map { if (defined($params{$_})) { $self->{$_} = $params{$_} } }
                      qw(type width init xorout refout poly refin cont);
  $self
}

sub reset {
  my $self = shift;
  my $typeparams;
  # default is crc32 if no type and no width is defined
  if (!defined($self->{type}) && !defined($self->{width})) {
    $self->{type} = "crc32";
  }
  if (defined($self->{type}) && exists($_typedef{$self->{type}})) {
    $typeparams = $_typedef{$self->{type}};
    $self->{width} = $typeparams->[0],
    $self->{init} = $typeparams->[1],
    $self->{xorout} = $typeparams->[2],
    $self->{refout} = $typeparams->[3],
    $self->{poly} = $typeparams->[4],
    $self->{refin} = $typeparams->[5],
    $self->{cont} = $typeparams->[6],
  }
  $self->{_tab} = _tabinit($self->{width}, $self->{poly}, $self->{refin});
  $self->{_data} = undef;
  $self
}

#########################################
# Private output converter functions:
sub _encode_hex { sprintf "%x", $_[0] }

sub _encode_base64 {
  my ($res, $padding, $in) = ("", undef, $_[0]);
  $in = pack("H*", sprintf("%x",$in));
  while ($in =~ /(.{1,45})/gs) {
	  $res .= substr pack('u', $1), 1;
	  chop $res;
  }
  $res =~ tr|` -_|AA-Za-z0-9+/|;
  $padding = (3 - length($in) % 3) % 3;
  $res =~ s#.{$padding}$#'=' x $padding#e if $padding;
  $res =~ s#(.{1,76})#$1\n#g;
  $res
}

#########################################
# OOP interface:

sub add {
  my $self = shift;
  $self->{_data} .= join '', @_ if @_;
  $self
}

sub addfile {
  my ($self,$fh) = @_;
  if (!ref($fh) && ref(\$fh) ne "GLOB") {
    require Symbol;
    $fh = Symbol::qualify($fh, scalar caller);
  }
  my $read = 0;
  my $buffer = '';
  my $crc;
  my $oldinit = $self->{init};
  while ($read = read $fh, $buffer, 32*1024) {
    $self->add($buffer);
    $crc = $self->digest;
    $self->{cont}=1;
    $self->{init}=$crc;
  }
  $self->{init} = $oldinit;
  $self->{_crc} = $crc;
  die __PACKAGE__, " read failed: $!" unless defined $read;
  $self
}

sub add_bits {
}

sub digest {
  my $self = shift;
  my $crc;
  if (!$self->{_crc}) {
    my $init = $self->{init};
    $crc =_crc($self->{_data},$self->{width},$init,$self->{xorout},
	 $self->{refin},$self->{refout},$self->{cont},$self->{_tab});
  } else {
    $crc = $self->{_crc};
    $self->{_crc} = undef;
  }
  $self->{_data} = undef;
  $crc
}

sub hexdigest {
  _encode_hex($_[0]->digest)
}

sub b64digest {
  _encode_base64($_[0]->digest)
}

sub clone {
  my $self = shift;
  my $clone = { 
    type => $self->{type},
    width => $self->{width},
    init => $self->{init},
    xorout => $self->{xorout},
    poly => $self->{poly},
    refin => $self->{refin},
    refout => $self->{refout},
    _data => $self->{_data}
  };
  bless $clone, ref $self || $self;
}

#########################################
# Procedural interface:

sub crc {
  my ($message,$width,$init,$xorout,$refout,$poly,$refin,$cont) = @_;
  _crc($message,$width,$init,$xorout,$refin,$refout,$cont,_tabinit($width,$poly,$refin));
}

sub _cont {
  my ($message,$init,@parameters) = @_;
  if (defined $init) {
    $parameters[1] = $init;
    $parameters[6] = 1;
  }
  crc($message,@parameters);
}

sub _reverse_endian
{
	my ($i) = @_;
	return (($i & 0xff00) >> 8) | (($i & 0xff) << 8);
}


# CRC8
# poly: 07, width: 8, init: 00, revin: no, revout: no, xorout: no

sub crc8 { _cont($_[0],$_[1],@{$_typedef{crc8}}) }

# CRC-CCITT standard
# poly: 1021, width: 16, init: ffff, refin: no, refout: no, xorout: no

sub crcccitt { _cont($_[0],$_[1],@{$_typedef{crcccitt}}) }

# CRC16
# poly: 8005, width: 16, init: 0000, revin: yes, revout: yes, xorout: no

sub crc16 { _cont($_[0],$_[1],@{$_typedef{crc16}}) }

sub crc16_xmodem_ccitt { _cont($_[0],$_[1],@{$_typedef{crc16_xmodem_ccitt}}) }

sub crc16_dnp { _reverse_endian( _cont($_[0],$_[1],@{$_typedef{crc16_dnp}})) }

sub crc16_en13757 {  _cont($_[0],$_[1],@{$_typedef{crc16_en13757}}) }

sub crc16_ffff_ccitt { _cont($_[0],$_[1],@{$_typedef{crc16_ffff_ccitt}}) }

sub crc16_1dof_ccitt { _cont($_[0],$_[1],@{$_typedef{crc16_1dof_ccitt}}) }


# CRC-24 for OpenPGP ASCII Armor checksum
# https://tools.ietf.org/html/rfc4880#section-6
# poly: 0x864CFB, width: 24, init: 0xB704CE, refin: no, refout: no, xorout: no

sub crcopenpgparmor { crc($_[0],@{$_typedef{crcopenpgparmor}}) }

# CRC32
# poly: 04C11DB7, width: 32, init: FFFFFFFF, revin: yes, revout: yes,
# xorout: FFFFFFFF
# equivalent to: cksum -o3

sub crc32 { _cont($_[0],$_[1],@{$_typedef{crc32}}) }

# CRC64
# special XS implementation (_crc64)

sub crc64 { _crc64($_[0],$_[1]) }

sub crc_hex { _encode_hex &crc }

sub crc_base64 { _encode_base64 &crc }

sub crc8_hex { _encode_hex &crc8 }

sub crc8_base64 { _encode_base64 &crc8 }

sub crcccitt_hex { _encode_hex &crcccitt }

sub crcccitt_base64 { _encode_base64 &crcccitt }


sub crc16_xmodem_ccitt_hex { _encode_hex &crc16_xmodem_ccitt }

sub crc16_xmodem_ccitt_base64 { _encode_base64 &crc16_xmodem_ccitt }

sub crc16_dnp_hex { _encode_hex &crc16_dnp }

sub crc16_dnp_base64 { _encode_base64 &crc16_dnp }


sub crc16_ffff_ccitt_hex { _encode_hex &crc16_ffff_ccitt }

sub crc16_ffff_ccitt_base64 { _encode_base64 &crc16_ffff_ccitt }

sub crc16_1dof_ccitt_hex { _encode_hex &crc16_1dof_ccitt }

sub crc16_1dof_ccitt_base64 { _encode_base64 &crc16_1dof_ccitt }


sub crc16_hex { _encode_hex &crc16 }

sub crc16_base64 { _encode_base64 &crc16 }

sub crcopenpgparmor_hex { _encode_hex &crcopenpgparmor }

sub crcopenpgparmor_base64 { _encode_base64 &crcopenpgparmor }

sub crc32_hex { _encode_hex &crc32 }

sub crc32_base64 { _encode_base64 &crc32 }

sub crc64_hex { _encode_hex &crc64 }

sub crc64_base64 { _encode_base64 &crc64 }

1;
__END__

=head1 NAME

Digest::CRC - Generic CRC functions

=head1 SYNOPSIS

  # Functional style

  use Digest::CRC qw(crc64 crc32 crc16 crcccitt crc crc8 crcopenpgparmor);
  $crc = crc64("123456789");
  $crc = crc32("123456789");
  $crc = crc16("123456789");
  $crc = crcccitt("123456789");
  
  $crc = crc16_xmodem_ccitt("123456789");
  $crc = crc16_ffff_ccitt("123456789");
  $crc = crc16_1dof_ccitt("123456789");
  
  $crc = crc16_dnp("123456789");
  $crc = crc16_en13757("123456789");
  
  $crc = crc8("123456789");
  $crc = crcopenpgparmor("123456789");

  $crc = crc($input,$width,$init,$xorout,$refout,$poly,$refin,$cont);


  # add data to existing

  $crc = crc32("ABCD", $crc);


  # OO style
  use Digest::CRC;

  $ctx = Digest::CRC->new(type=>"crc16");
  $ctx = Digest::CRC->new(width=>16, init=>0x2345, xorout=>0x0000, 
                          refout=>1, poly=>0x8005, refin=>1, cont=>1);

  $ctx->add($data);
  $ctx->addfile(*FILE);

  $digest = $ctx->digest;
  $digest = $ctx->hexdigest;
  $digest = $ctx->b64digest;


=head1 DESCRIPTION

The B<Digest::CRC> module calculates CRC sums of all sorts.
It contains wrapper functions with the correct parameters for CRC-CCITT,
CRC-16, CRC-32 and CRC-64, as well as the CRC used in OpenPGP's
ASCII-armored checksum.

=head1 SEE ALSO

https://tools.ietf.org/html/rfc4880#section-6

=head1 AUTHOR

Oliver Maul, oli@42.nu

=head1 COPYRIGHT

CRC algorithm code taken from "A PAINLESS GUIDE TO CRC ERROR DETECTION
 ALGORITHMS".

The author of this package disclaims all copyrights and 
releases it into the public domain.

=cut
