package Telereleve::Helper::Formats;

use Moose::Role;

=head1 NAME

Telereleve::Helper::Formats - Gestion des formats de trame

=head1 VERSION

Version 0.50

=cut

our $VERSION = '0.50';


=head1 SYNOPSIS

Rôle Moose
	
Usage dans une librairie:
	
    with 'Telereleve::Helper::Formats';

Rôle à utiliser dans un autre rôle ou dans une classe quelconque.
	
Gère le format utilisé
	
permet de connaître le format associé à une application
	
voir
	
	Telereleve::Layer::Liaison

=head1 Attributes

=head2 format de trame

	format: exchange ou download ou nfc
		
=cut

has 'format' => (
	is => 'rw',
);

=head2 application_format

	Tableau de correspondance entre une application et le le format utilisé

	Méthodes accessibles
	
	get_application_format(application)
	
		retourne le format de trame
	
	$obj->get_application_format('INSTPING'); # retourne exchange
	
	Usage:
	
	$obj->format( $obj->get_application_format('INSTPING') );
	
	application_format_pairs
	
		Liste des applications et trames disponibles

=cut

has 'application_format' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef[Str]',	
   default   => sub { {
		'INSTPING' 	=> 'exchange',
		'INSTPONG' 	=> 'exchange',
		'DATA' 		=> 'exchange',
		'COMMAND'	=> 'exchange',
		'RESPONSE'	=> 'exchange',
		'DOWNLOAD'	=> 'download',
		'NFC'		=> 'nfc',
  } },
  handles   => {
	  get_application_format     => 'get',
	  application_format_pairs   => 'kv',
  }, 
);

=head2 max_length_message

	Methode 
		get_max_length_message
		
	exemple

	my $exchange_longueur_max = $obj->get_max_length_message("exchange");
	
	ou encore
	
	my $exchange_longueur_max = $obj->get_max_length_message(  $obj->format() );


=cut

#a multiplier à l'usage en fonction des besoins, pour de l'hexa, c'est donc * 2
#ou aussi  length(pack("H*","6d65737361676520656e2068657861646563696d616c"))
has 'max_length_message' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {
		'exchange' 	=> 104,
		'download' => 210, 
		'nfc' => 245, 		
  } },
  handles   => {
	  get_max_length_message     => 'get',
  },
);


=head1 SUBROUTINES/METHODS

=head1 AUTHOR

phv, C<< <philippe.devisme at suez-env.com> >>

=head1 BUGS

Please report any bugs or feature requests to Ondeo Systems.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Telereleve::Helper::Formats

=head1 ACKNOWLEDGEMENTS

=head1 LICENSE AND COPYRIGHT

Copyright 2013-2015 Ondeo Systems.

This program is not free software; you cannot redistribute it nor modify it.

=cut

1; # End of Telereleve::Helper::Formats
