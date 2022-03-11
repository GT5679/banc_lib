package Error::Correction::RS;

use Moose;

use Carp;

use Data::Dumper;
use feature qw(say);

use 5.006;

=head1 NAME

Error::Correction::RS - encode (and sooner or later decode) RS

=head1 VERSION

Version 0.05

=cut

our $VERSION = '0.05';


=head1 SYNOPSIS

    use Error::Correction::RS;

    my $rs = Error::Correction::RS->new( degree => 8, length => 7, capability => 4, parity => 3 );
    if ( !$rs->encode( [ 1, 6, 4 ]) ) {
		print $rs->msg_hex();
		print $rs->msg_parity();
	}
	
	
	#perhaps
	my ($corrected) = $rs->decode($string);
	

=head1 EXPORT

no export

=head1 Attributes

=cut

#mm
has 'degree' => (
	is => 'ro',
	reader => 'get_degree',
	writer => 'set_degree',
    lazy      => 1,
	default => 8,
);

#nn
has 'length' => (
	is => 'ro',
	reader => 'get_length',
	writer => 'set_length',
    lazy      => 1,
	default => 255,
);


#tt
# kk
has 'capability' => (
	is => 'ro',
	reader => 'get_capability',
	writer => 'set_capability',
    lazy      => 1,
	default => 4,
);

#kk
# tt
has 'parity' => (
	is => 'ro',
	reader => 'get_parity',
	writer => 'set_parity',
    lazy      => 1,
	default => 3,
);

has '_alpha_to' => (
	is => 'rw'
);


has '_index_of' => (
	is => 'rw',
);

has '_generator_polynomial' => (
	is => 'rw',
);

has 'msg_orig' => (
	is => 'rw',
);

has 'msg_parity' => (
	is => 'rw',
	trigger => \&_build_msg_hex
);

has 'msg_hex' => (
	is 		  => 'rw',
	predicate => 'has_msg_hex',
);

has 'modulos' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef[Str]',
  default   => sub { {
    '2' 	=> "111", # (1+x+x^^2)
    '3' 	=> "1101", # (1+x+x^^3)
    '4' 	=> "11001", # (1+x+x^^4)
    '5' 	=> "101001", # (1+x^^2+x^^5)
    '6' 	=> "1100001", # (1+x+x^^6)
    '7' 	=> "10010001", # (1+x^^3+x^^7)
    '8' 	=> "101110001", # (1+x^^2+x^^3+x^^4+x^^8)
    '9' 	=> "1000100001", # (1+x^^4+x^^9)
    '10'    => "10010000001", # (1+x^^3+x^^10)
    '11'    => "101000000001", # (1+x^^2+x^^11)
    '12'    => "1100101000001", # (1+x+x^^4+x^^6+x^^12)
    '13'    => "11011000000001", # (1+x+x^^3+x^^4+x^^13)
    '14'    => "110000100010001", # (1+x+x^^6+x^^10+x^^14)
    '15'    => "1100000000000001", # (1+x+x^^15)
    '16'    => "11010000000010001", # (1+x+x^^3+x^^12+x^^16)
  } },
  handles   => {
	  set_modulo     => 'set',
	  get_modulo     => 'get',
	  list_modulos   => 'kv',
  },
);

=head1 SUBROUTINES/METHODS

=head2 encode

	take the string of symbols in data[i], i=0..(k-1) and encode systematically to produce 2*tt parity symbols in bb[0]..bb[2*tt-1] 
	
	data[] is input and bb[] is output in polynomial form.
	
	Encoding is done by using a feedback shift register with appropriate connections specified by the elements of gg[], which was generated above.
	
	Codeword is   c(X) = data(X)*X**(nn-kk)+ b(X)   

    parameters: array ref of integer 
	
	Result available:
	
	$rs->msg_hex()
	
	$rs->msg_parity(); 

=cut

sub encode {
	my ($self,$msg) = @_;
	confess("Message missing") if !@$msg || @$msg == 0;
	$self->_generate_gf();
	$self->_gen_poly();	
	$self->_encode($msg);
	return 0;
}

sub _encode {
	my ($self,$msg) = @_;
    my $feedback;
#	my @data = reverse @$msg;
	my @data = @$msg;
	$self->msg_orig($msg);
	my @index_of = @{ $self->_index_of() };
	my @alpha_to = @{ $self->_alpha_to() };	
	my @gg 		 = @{ $self->_generator_polynomial() };
    my @bb;

	# for 0 to 255 -32 = 223
#   for (my $i=0; $i< ($self->get_length() - $self->get_parity()); $i++) {
    # for 0 to 32 
    for (my $i=0; $i< ($self->get_parity()); $i++) {  
        $bb[$i] = 0 ;
    }
	
	# for 32-1=31 to 0
#	for (my $i=($self->get_parity() - 1); $i>=0; $i--)
    # for 255-32-1=222 to 0
    for (my $i=($self->get_length() - $self->get_parity() - 1); $i>=0; $i--) 
    {
#		$feedback = $index_of[ $data[$i] ^ $bb[$self->get_length() - $self->get_parity() - 1]] || 0;
    	$feedback = $index_of[ $data[$i] ^ $bb[$self->get_parity() - 1]]; # || 0;
    	if ($feedback != -1) 
       	{
       		# for 255 - 32  -1 = 222  to 0
#			for (my $j=($self->get_length() - $self->get_parity() - 1); $j>0; $j--)
       		# for 32-1=31 to 0
       		for (my $j=($self->get_parity() - 1); $j>0; $j--)  
       		{
       			if ($gg[$j] != -1) 
       			{
       				$bb[$j] = $bb[$j-1] ^ $alpha_to[($gg[$j] + $feedback) % $self->get_length()] ;
                } 
                else 
                {
                	$bb[$j] = $bb[$j-1] ;
                }
            }
            $bb[0] = $alpha_to[($gg[0] + $feedback) % $self->get_length()] ;
        } 
        else
        {
        	# for 255 - 32  -1 = 222  to 0
#			for (my $j=($self->get_length() - $self->get_parity() -1); $j>0; $j--)
        	# for 32-1=31 to 0
        	for (my $j=($self->get_parity() -1); $j>0; $j--) 
          	{
          		$bb[$j] = $bb[$j-1] ;
          	}
          	$bb[0] = 0 ;
       }
    }
    
    
    #for (my $i=0; $i < $self->get_capability(); $i++) {
    #    print "data[".$i. "] = ".$data[$i]."; msg[".$i."]".@$msg[$i]. "\n" ;
    #}
    #for (my $i=0; $i < $self->get_parity(); $i++) {
    #    print "bb[".$i. "] = ".$bb[$i]. "\n" ;
    #}
    
    
	$self->msg_parity(\@bb);
	return 0;
}

=head2 decode

	todo

=cut

sub decode {
	my ($self) = @_;
	
}

=head2 _generate_gf

	generate GF(2**mm) from the irreducible polynomial p(X) in pp[0]..pp[mm]
	lookup tables:  index->polynomial form   alpha_to[] contains j=alpha**i;
                   polynomial form -> index form  index_of[j=alpha**i] = i
	alpha=2 is the primitive element of GF(2**mm)
   
=cut

sub _generate_gf {
	my ($self) = @_;
	confess("Groumpf degre pas bon") if $self->get_length() != (2**$self->get_degree() ) - 1;
	confess("Groumpf! la capability ne correspond pas") if $self->get_parity() != $self->get_length()  - $self->get_capability() ;	
	my $mask = 1 ;
	my @alpha_to;
	my @index_of;
	my $mm = $self->get_degree();
	my $nn = $self->get_length();
	my @pp = split //, $self->get_modulo( $self->get_degree());
	  
	$alpha_to[$mm] = 0 ;
	for (my $i=0; $i < $mm; $i++) { 
		$alpha_to[$i] = $mask ;
		$index_of[$alpha_to[$i]] = $i ;
		if ( $pp[$i] != 0) {
		   $alpha_to[$mm] ^= $mask ;
		}
		$mask <<= 1 ;
	}
	$index_of[$alpha_to[$mm]] = $mm ;
	$mask >>= 1 ;
	for (my $i=$mm+1; $i<$nn; $i++) { 
		if ($alpha_to[$i-1] >= $mask) {
			$alpha_to[$i] = $alpha_to[$mm] ^ (($alpha_to[$i-1]^$mask) << 1) ;
			$index_of[$alpha_to[$i]] = $i ;
		} else {
			$alpha_to[$i] = $alpha_to[$i-1] << 1 ;
			$index_of[$alpha_to[$i]] = $i ;
		}
		#$index_of[0] = -1 ;
	}
	$index_of[0] = -1 ;
	$self->_alpha_to(\@alpha_to);
	$self->_index_of(\@index_of);
	return 0;
}

=head2 _gen_poly

	Obtain the generator polynomial of the tt-error correcting, length
	nn=(2**mm -1) Reed Solomon code  from the product of (X+alpha**i), i=1..2*tt
	
=cut
sub _gen_poly {
	my ($self) = @_;
	my @gg;
	my @index_of = @{ $self->_index_of() };
	my @alpha_to = @{ $self->_alpha_to() };
	$gg[0] = 2 ;   # /* primitive element alpha = 2  for GF(2**mm)  */
	$gg[1] = 1 ;   # /* g(x) = (X+alpha) initially */
    #for (my $i=2; $i<=($self->get_length()-$self->get_parity()) ; $i++) {
    for (my $i=2; $i<=($self->get_parity()) ; $i++) {  
	  $gg[$i] = 1 ;
	  for (my $j=$i-1; $j>0; $j--) {
		if ($gg[$j] != 0) {
			$gg[$j] = $gg[$j-1] ^ $alpha_to[ ( $index_of[$gg[$j]] + $i) % $self->get_length()] ;
		} else {
			$gg[$j] = $gg[$j-1] ;
		}
	  }
	  $gg[0] = $alpha_to[($index_of[$gg[0]] + $i) % $self->get_length()] ;   #  /* gg[0] can never be zero */
    }
    #/* convert gg[] to index form for quicker encoding */
    for (my $i=0; $i<= ($self->get_parity()) ; $i++) {
		$gg[$i] = $index_of[$gg[$i]] ;
    }
    $self->_generator_polynomial(\@gg);
	$self->_alpha_to(\@alpha_to);
	$self->_index_of(\@index_of);   
	return 0;
}

sub _build_msg_hex {
	my ($self,$parity,$old_parity) = @_;
	my @orig = @{ $self->msg_orig() };
	# my @parity = reverse @{ $parity };
	my @parity = @{ $parity };
	
	
	my $msg_hex = unpack "H*", pack("C*", @orig,@parity);
	$self->msg_hex($msg_hex);
}

=head1 AUTHOR

phv, C<< <philippe.devisme at suez-env.com> >>

=head1 BUGS

Please report any bugs or feature requests to .


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Error::Correction::RS


=head1 ACKNOWLEDGEMENTS

Original code got from Simon Rockliff, University of Adelaide   21/09/89

	L<http://www.eccpage.com/rs.c>

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Ondeo Systems.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.



=cut

__PACKAGE__->meta->make_immutable;

1; # End of Error::Correction::RS
