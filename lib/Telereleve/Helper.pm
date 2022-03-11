package Telereleve::Helper;

use Moose::Role;
use Carp;
use feature qw(say);
use Data::Dumper;
use Time::Piece;
use Time::Local qw( timegm );

=head1 NAME

Telereleve::Helper - Helper

=head1 VERSION

Version 0.5

=cut

our $VERSION = '0.5';

=head1 SYNOPSIS

parameters

see L<Telereleve::Helper::CheckDatas>

=head1 ATTRIBUTES

=cut

=head2 start_time

Epoque absolue de référence: janvier 2013

=cut

has 'start_time' => (
	is => 'rw',
	default => Time::Piece->strptime("2013-01-01 00:00:00",'%Y-%m-%d %H:%M:%S')->epoch
);

has 'now' => (
	is => 'rw',
);

=head1 SUBROUTINES/METHODS


=cut

=head2 date_from_ddc_time

A partir d'une date hexa reçue d'un ddc ou de n'importe quoi d'ailleurs, renvoie le timestamp unix traditionnel.

Parametre:

	chaine hexa
	
Retourne

	timestamp unix, entier, nombre de secondes depuis 1970

=cut
sub date_from_ddc_time {
    my ($self,$date_hexa) = @_;
	$self->now($self->start_time +  hex($date_hexa));
    return $self->now;
}

=head2 date_to_ddc_time

A partir d'une date formattée renvoie la date au format hexa et à partir de janvier 2013, ou de ce qui a été décidé, voir start_time

Parametre:

	date au format %Y-%m-%d %H:%M:%S
	
retourne:

	chaine hexa, nombre de secondes depuis start time qui est le 1er janvier 2013

=cut
sub date_to_ddc_time {
    my ($self,$now) = @_;
    my $date = Time::Piece->strptime($now, '%Y-%m-%d %H:%M:%S')->epoch - $self->start_time;
    return sprintf('%08X',$date);
}

=head2 timestamp_to_ddc_time

A partir d'un tiemstamp unix renvoie la date au format hexa et à partir de janvier 2013, ou de ce qui a été décidé, voir start_time

Parametre:

	timestamp unix
	
retourne:

	chaine hexa, nombre de secondes depuis start time qui est le 1er janvier 2013

=cut
sub timestamp_to_ddc_time {
    my ($self,$now) = @_;
    my $date = $now - $self->start_time;
    return sprintf('%08X',$date);
}

=head2 human_date

Même chose que date_from_ddc_time, mais renvoie une date lisible par les pauvres humains que nous sommes.

Heure gmt naturellement

=cut
sub human_date {
	my ($self,$date_hexa) = @_;
	$self->now($self->start_time +  hex($date_hexa));
	return scalar(gmtime($self->now));
}

=head2 ddc_date_parsed

A partir d'une date hexa, renvoie un tableau de date gmtime (voir perldoc -f localtime, gmtime fait la même chose, mais ne décrit pas le tableau en détail )

Heure gmt naturellement

Paramètres

	Date DdC au format chaine Hexa
	
Retourne

	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)

=cut
sub ddc_date_parsed {
	my ($self,$date_hexa) = @_;
	$self->now($self->start_time +  hex($date_hexa));
	return gmtime($self->now);
}

=head2 double_to_heure

A partir d'une date courante en double seconde renvoie un time au format HH::MM::SS

Paramètre:

	chaine hexa, double secondes

Retourne:

	chaine "HH:MM:SS"
	
=cut
sub double_to_heure {
	my ($self,$double) = @_;
	my $sec = hex($double) * 2;
	my $hour = sprintf("%02i", int($sec/(60*60)));
	my $minutes =  sprintf("%02i",  ($sec/60)%60);
	my $secondes = sprintf("%02i", $sec%60);
	return "$hour:$minutes:$secondes";
}

=head2 simple_to_heure

Prend en paramètre une heure au format hexa double secondes et renvoie "HH:MM:SS"

=cut
sub simple_to_heure {
	my ($self,$double_secondes_hexa) = @_;
	my $sec = hex($double_secondes_hexa);
	my $hour = sprintf("%02i", int($sec/(60*60)));
	my $minutes =  sprintf("%02i",  ($sec/60)%60);
	my $secondes = sprintf("%02i", $sec%60);
	return "$hour:$minutes:$secondes";
}

=head2 get_current_heure_gaziere

A partir d'un timestamp courant et d'une heure gazière renvoie l'heure gazière correspondante.

L'heure de référence est celle du jour précédent pour les timestamp entre minuit et l'heure gazière


=cut
sub get_current_heure_gaziere {
	my ($self,$hexa_timestamp_current_time,$heure_gaziere_hexa) = @_;
	return $self->get_current_heure_reference($hexa_timestamp_current_time,$heure_gaziere_hexa);
}
=head2 get_current_heure_reference

A partir d'un timestamp courant et d'une heure de référence renvoie l'heure de référence correspondante.

L'heure de référence est celle du jour précédent pour les timestamp entre minuit et l'heure de référénce

Paramètres:

	hexa_timestamp_current_time: timestamp courant au format hexa

	heure_reference_hexa: heure de référence au format hexa

Retourne:

	Heure de référence sous forme de chaine hexa et en double secondes.


=cut
sub get_current_heure_reference {
	my ($self,$hexa_timestamp_current_time,$heure_reference_hexa) = @_;
	#Il faut vérifier le cas des timestamp du matin, dans ce cas l'heure de référence d'arrêté de consommation journalier est celle du jour d'avant, d'où les calculs savants et alambiqués
	#si vous avez mieux et plus simple, go ahead, moi, j'arrête pour aujourd'hui
	my  ($mday,$mon,$year,$wday,$yday,$isdst);
	(undef,undef,undef,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($self->date_from_ddc_time($hexa_timestamp_current_time));
	my $current_midnight_timestamp = timegm(0,0,0, $mday,$mon,$year);
	my $current_midnight = $self->timestamp_to_ddc_time($current_midnight_timestamp);
	#et dans le cas où on est après minuit, mais avant l'heure de référence, l'heure de référence est la veille 
	my $difference = hex($hexa_timestamp_current_time) - hex($current_midnight);
	if ($difference < (hex($heure_reference_hexa) * 2)) {
		(undef,undef,undef,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(($self->date_from_ddc_time($hexa_timestamp_current_time) - 86400));
	}
	$current_midnight_timestamp = timegm(0,0,0, $mday,$mon,$year);
	$current_midnight = $self->timestamp_to_ddc_time($current_midnight_timestamp);
	return wantarray ?
			(	sprintf("%08X", (hex($current_midnight) + (hex($heure_reference_hexa) * 2)) ),
				sprintf("%08X", $current_midnight)
			)
			: sprintf("%08X", (hex($current_midnight) + (hex($heure_reference_hexa) * 2)) ) ;
}


=head1 AUTHOR

phv, C<< <philippe.devisme at suez-env.com> >>

=head1 BUGS

Please report any bugs or feature requests to Ondeo Systems.

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014-2015 Ondeo Systems.

This program is NOT free software; you canNOT redistribute it and/or modify it.

=cut

1; # End of Telereleve::Helper
