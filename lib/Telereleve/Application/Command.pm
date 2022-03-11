package Telereleve::Application::Command;

use Moose;
use feature qw(say);
use Data::Dumper;

extends 'Telereleve::Application';

=head1 NAME

Telereleve::Application::Command - Gestion des commandes (via le lan)

=head1 VERSION

Version 0.5

=cut

our $VERSION = '0.5';


=head1 SYNOPSIS

Librairie pour constuire des trames de types commande ou les analyser.


Exemple:

    use Telereleve::Application::Command;

	my $commande = new Telereleve::Application::Command(testname => 'nomtest' , mainconfig_file => 'campagne.cfg');
	$commande->id_ddc( 'id_ddc en hexa');
	$commande->id_fabricant('id_fabricant en hexa');   
	$commande->set_cpt( int(hex( substr($commande->epoch_timestamp(),-4)) /2) );
	my $trameL7 = $commande->build_message('COMMAND_READPARAMETERS','0878');
	$commande->build($trameL7);


	
Trame accessible via
	
	$commande->message_binary()
	
	$commande->message_hexa()

voir L<Telereleve::Layer::Presentation|telereleve-layer-presentation.html>.	
	
=head1 SEE ALSO	

L<Telereleve::Application|telereleve-application.html>

et les couches basses:

L<Telereleve::Layer::Liaison|telereleve-layer-liaison.html>

L<Telereleve::Layer::Presentation|telereleve-layer-presentation.html>

L<Telereleve::Helper::Formats|telereleve-helper-formats.html>

Pour l'envoi ou la réception de données, voir

L<Telereleve::COM::Trx|telereleve-com-trx.html>

ou

L<Telereleve::COM::NFC|telereleve-com-nfc.html>

Le répertoire git contient un répertoire tests contenant des exemples complets.	

=head1 ATTRIBUTES

Application, surcharge de l'attribut de Telereleve::Application

Application, nom de l'application,
	
	default: COMMAND

check_params, si la valeur est différente de 0, vérifie les données read/write parameters lors de la construction d'un message

	default: 0
	
	
=cut

has '+application' => (
	is 		=> 'rw',
	default => 'COMMAND',
);


has 'check_params' => (
	is 		=> 'rw',
	default => 0,
);

=head2 commandes

commandes, hash des commandes possibles avec leur id

	get_commande
		obtenir un id pour un nom de commande
	
	commande_pairs
		Liste des commandes disponibles
	
	my $commande_id = $commande->get_commande('COMMAND_WRITEPARAMETERS');
	
=cut

has 'commandes' => (
	  traits    => ['Hash'],
	  is        => 'ro',
	  isa       => 'HashRef[Str]',
	  default   => sub { {
			'COMMAND_READPARAMETERS'  => '10',
			'COMMAND_WRITEPARAMETERS' => '20',
			'COMMAND_WRITEKEY' 		  => '28',
			'COMMAND_ANNDOWNLOAD' 	  => '30',
			'COMMAND_EXECINSTPING' 	  => '40',		
	  } },
	  handles   => {
	  	  set_commande     => 'set',
		  get_commande     => 'get',
		  commande_pairs   => 'kv',
	  },
);

=head2 parameters

Hash des paramètres disponibles, version 1.11 de la sftd ddc
	
Méthodes

	get_parameter_name
		A partir de l'id d'un paramètre retourne une référence de tableau [id,longueur attendue]
	parameters_keys
		liste des paramètres sous forme de array

	my $datas = $commande->get_parameter_name('F1');
	où
	$datas = ['NEXT_TIME_EVENT',2];

	
voir le rôle moose <Telereleve::Helper>
	
=cut

override 'build' => \&_build;

override 'extract' => \&_extract;

=head1 SUBROUTINES/METHODS

=cut
sub _build {
	my ($self,$message) = @_;
	$self->logger->info($self->application() . " begin.");
	confess("Message manquant") unless $message;
	super();
	$self->logger->info($self->application() . " done");
}

sub _extract {
	my ($self) = @_;
	$self->logger->info($self->application() . " begin.");
	super();

	#extraction des données L7
	my ($L7CommandId, $L7Frm ) = unpack "H2 H*", pack "H*", $self->decrypted();

	print $L7CommandId ."\n";
	
	if ($L7CommandId eq $self->get_commande('COMMAND_ANNDOWNLOAD') ) 
	{
		my ($L7DwnldId, $L7Klog, $L7SwVersionIni, $L7SwVersionTarget, $L7MField, 
	        $L7DcHwId, $L7BlocksCount, $L7ChannelId, $L7ModulationId, $L7DaysProg,
	        $L7DaysRepeat, $L7DeltaSec, $HashSW 
	        ) = unpack "H6 H32 H4 H4 H4 H4 H4 H2 H2 H8 H2 H2 H8", pack "H*", $L7Frm;
	
		$self->set_commande(L7CommandId => $L7CommandId);
		$self->set_commande(L7DwnldId => $L7DwnldId);
		$self->set_commande(L7Klog => $L7Klog);
		$self->set_commande(L7SwVersionIni => $L7SwVersionIni);
		$self->set_commande(L7SwVersionTarget => $L7SwVersionTarget);
		$self->set_commande(L7MField => $L7MField);
		$self->set_commande(L7DcHwId => $L7DcHwId);
		$self->set_commande(L7BlocksCount => $L7BlocksCount);
		$self->set_commande(L7ChannelId => $L7ChannelId);
		$self->set_commande(L7ModulationId => $L7ModulationId);
		$self->set_commande(L7DaysProg => $L7DaysProg);
		$self->set_commande(L7DaysRepeat => $L7DaysRepeat);
		$self->set_commande(L7DeltaSec => $L7DeltaSec);
		$self->set_commande(HashSW => $HashSW);
	}
	elsif ($L7CommandId eq $self->get_commande('COMMAND_WRITEKEY')) 
	{
		my ($L7KeyId, $L7KeyVal, $L7KIndex) = unpack "H2 H64 H2", pack "H*", $L7Frm;
		$self->set_commande(L7KeyId => $L7KeyId);
		$self->set_commande(L7KeyVal => $L7KeyVal);
		$self->set_commande(L7KIndex => $L7KIndex);
	}
	$self->logger->info($self->application() . " done");
}

=head2 build_message

Méthode sommaire de fabrication de la trame de données à envoyer.

Attribut check_params 

	si l'attribut est différent de 0, vérifie que les paramètres correspondent à quelque chose ;)
	
Parametres:
	
	$commande_name (string)
		Nom de la commande, exemple: 
			COMMAND_READPARAMETERS
			
			COMMAND_WRITEPARAMETERS
			
			COMMAND_WRITEKEY
				si aucun parametre n'est envoyé, ca chercher les infos dans le fichier de campagne
			
			COMMAND_ANNDOWNLOAD
				si aucun parametre n'est envoyé, ca chercher les infos dans le fichier de campagne
				
			COMMAND_EXECINSTPING
				message vide
	
	$datas (string) sous forme de chaîne héxadécimale

	$complement
		données complémentaires pour tests spéciaux en général
		
		L6keySel est une valeur hexadécimale, mais elle est castée sous forme d'entier dans le code, voir L<Telereleve::Layer::Presentation|telereleve-layer-presentation.html>
				
		L6keySel => '0E'
			pour utiliser une autre clef que le clef 01 dans les requetes 
					(WRITE/READ)PARAMETERS
					COMMAND_WRITEKEY
					COMMAND_ANNDOWNLOAD

ATTENTION à la case de B<L6keySel>
					
					
Return:
		
	Renvoie le message qui est la concaténation de

	commande_id + datas
	
=cut
sub build_message {
	my ($self,$commande_name,$datas,$complements) = @_;
	$datas .= ''; #eviter warnings surtout
	my $message ='';
	confess("[build_message] commande inconnue: $commande_name") unless $self->get_commande(uc($commande_name));
	$self->logger()->info("$commande_name: $datas");
	if (uc $commande_name =~ m/COMMAND_(?:WRITE|READ)PARAMETERS/) {
		if ($complements && $complements->{L6keySel}) {
			my $keysel = hex($complements->{L6keySel});
			$self->keysel($keysel);
			$self->kenc( $self->get_kenc($keysel) );	
			$self->logger->info("kenc $keysel: " .$self->kenc());
		}
		if ($self->check_params) { 
			my $datas_extract = $datas;
			while ( my ($param_id) = $datas_extract =~ m/^([A-Fa-f0-9]{2})/) {
				$param_id = uc($param_id);
				confess("Parametre inconnu au bataillon: MIA ? $param_id") unless $self->get_parameter_name_by_id($param_id);
				if ($commande_name eq "COMMAND_READPARAMETERS") {
					$datas_extract =~ s/^([A-Fa-f0-9]{2})//;
					next;
				}
				#valeur dépend du type de commande
				my $len = $self->get_parameter_name_by_id($param_id)->[1] * 2;
				$datas_extract =~ s/$param_id([A-Fa-f0-9]{$len})?//;
				my $value = $1;
				confess("Une valeur manque ($param_id:$len) datas [$datas]")  unless $value;				
				confess("Valeur: longueur fausse, veuillez vérifier vos données: $value (longueur attendue: ".$self->get_parameter_name_by_id($param_id)->[1].")") 
						if length($value) != $len;
				$self->logger->info("$param_id : ".$self->get_parameter_name_by_id($param_id)->[0]." => $value");
			}
		}
		#$message = lc( $self->get_commande(uc($commande_name)) . $datas);
	} elsif (uc $commande_name eq 'COMMAND_EXECINSTPING') {
		#$message = lc( $self->get_commande(uc($commande_name)));
	} elsif (uc $commande_name eq 'COMMAND_WRITEKEY') {
		#voir sftd la, 9.6.1.3, on utilie la kchg, cle 16
		if ($complements && $complements->{L6keySel}) {
			my $keysel = hex($complements->{L6keySel});
			$self->keysel($keysel);
			$self->kenc(  $self->get_kenc($keysel) );
		} else {
			$self->keysel(15);
			$self->kenc(  $self->get_kenc(15) );
		}
		$message = lc( $self->get_commande(uc($commande_name)) );
		if ($datas eq "") {
			my @params = qw(L7KeyId L7KeyVal L7KIndex);
			foreach my $param (@params) {
				confess({error => 0x70, message => "$param: missing parameter in hash"}) unless ( $complements->{$param}  || $self->$param());
				$datas .=   $complements->{$param} 	;
			}
		}		
	} elsif (uc $commande_name eq 'COMMAND_ANNDOWNLOAD') {	
		#$self->logger->info("COMMAND_ANNDOWNLOAD");
		#certains éléments viennent de la conf (SwVersionIni, L7 MField) 
		#voir le fichier de conf application download
		#$message = lc( $self->get_commande(uc($commande_name)) );
		if ($complements && $complements->{L6keySel}) {
			my $keysel = hex($complements->{L6keySel});
			$self->keysel($keysel);
			$self->kenc(  $self->get_kenc($keysel) );
		} else {
			$self->keysel(15);
			$self->kenc(  $self->get_kenc(15) );
		}		
		$self->logger->info("datas [$datas]");
		if ($datas eq "") {
			$self->logger->info("chercher dans la conf");
			my @params = qw(L7DwnldId L7Klog L7SwVersionIni L7SwVersionTarget L7MField L7DcHwId L7BlocksCount L7ChannelId L7ModulationId L7DaysProg L7DaysRepeat L7DeltaSec HashSW);
			foreach my $param (@params) {
				confess({error => 0x70, message => "$param: missing parameter in campagne config file, see DDC block"}) unless ( $complements->{$param}  || $self->$param());
				$datas .=  ( $complements->{$param} || $self->$param() )
			}
		}
	} else {
		confess("commande inconnue ou vide ($commande_name)");
	}
 	$message = lc( $self->get_commande(uc($commande_name)) . $datas);
	return $message;
}


=head2 build_raw_message

Méthode sommaire de fabrication de la trame de données à envoyer

permet d'envoyer des trames L7 incohérentes.
	
=cut
sub build_raw_message {
	my ($self,$commande_hexa,$datas) = @_;
	my $datas_extract = $datas;
 	my $message = $commande_hexa . $datas;
	return $message;
}


=head1 AUTHOR

phv, C<< <philippe.devisme at suez-env.com> >>

=head1 BUGS

Please report any bugs or feature requests to Ondeo Systems.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Telereleve::Application::Command


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013-2015 Ondeo Systems.

This program is not free software; you cannot  redistribute it nor modify it.


=cut

no Moose;
__PACKAGE__->meta->make_immutable;

1; # End of Telereleve::Application::Command
