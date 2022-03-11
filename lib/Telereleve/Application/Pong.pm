package Telereleve::Application::Pong;

use Moose;
use feature qw(say);
use Data::Dumper;

extends 'Telereleve::Application';

with 'Telereleve::Helper::CheckDatas';

=head1 NAME

Telereleve::Application::Pong - Gestion d'une commande Pong

=head1 VERSION

Version 0.50

=cut

our $VERSION = '0.50';


=head1 SYNOPSIS

message INSTPONG

Génération du pong retourné par chaque concentrateur pour chaque modem lan ayant reçu un INTSPING

    use Telereleve::Application::Pong;

    my $pong = Telereleve::Application::Pong->new(testname => 'nomtest' , mainconfig_file => 'campagne.cfg');
    
	
	$pong->extract();
	
	#Données du pong au format hexadécimal
	La trame au complet
	$pong->decrypted()
	
	
	Les détails
	$pong->concent_id()
	$pong->modem_id();
	$pong->rssi()
	
	A l'inverse pour un ping reçu, voir Telereleve::Application::Pong
	peut renvoyer un pong
	
	my $message = $pong->build_message(
					undef,				#pour raison de compatibilité avec les autres commandes
					{
						L7ConcentId => '000102030405',
						L7ModemId	=> '01',
						RSSI		=> '01',
					});
	#initialisé la valeur du compteur L6 à la valeur souhaitée
	# la valeur par défaut est dans le fichier de campagne.cfg
	$pong->set_cpt(12);		
	$pong->build($message);	
	
	#le résultat sous forme de chaine hexa peut être envoyé vers un trx pour envoi.
	$pong->message_hexa();	#chaine hexa
	
voir Telereleve::COM::Trx pour l'envoi par un trx, voir L<Telereleve::COM::Trx|telereleve-com-trx.html>
	
	La trame peut être envoyée sous forme de tableau de valeur hexa ou sous forme de chaine hexa
	
	my @array_ref = map {  hex $_  }  $pong->message_hexa() =~ m/([A-Fa-f0-9]{2})/ig;
	
	$trx->send_message([$pong->message_hexa()],3,undef,1);
	

=head2 ATTRIBUTES

	concent_id
	
	modem_id
	
	rssi

=cut

has '+application' => (
	is 		=> 'rw',
	default => 'INSTPONG',
);

has 'concent_id' => (
		is => 'rw'
);

has 'modem_id' => (
		is => 'rw'
);
has 'rssi' => (
		is => 'rw'
);

=head2 response_parameters

Réponses extraites de la trame L7 sous forme de hash
	
Méthode pour obtenir la valeur d'un paramètre donné.
	
	get_response_parameter_name

	all_response_parameters
		liste des réponses
	
	response_parameters_keys
		Liste des clés possibles
		
=cut

has 'response_parameters' => (
	  traits    => ['Hash'],
	  is        => 'ro',
	  isa       => 'HashRef',
	  default   => sub { {

	  } },
	  handles   => {
		  set_response_parameter_name     => 'set',			
		  get_response_parameter_name     => 'get',
		  response_parameters_pairs   	=> 'kv',
		  response_parameters_keys 		=> 'keys',
		  all_response_parameters 		=> 'elements',		  
	  },
);

=head2 responses

Hash des réponses communes à toutes les trames (L7ResponseId,L7ErrorCode,L7SwVersion,L7Rssi,L7ErrorParam) extraites des données reçues.

Méthodes:
	
		set_response
		
		get_response
		
		response_pairs

=cut
has 'responses' => (
	  traits    => ['Hash'],
	  is        => 'ro',
	  isa       => 'HashRef[Str]',
	  default   => sub { {
	  
	  } },
	  handles   => {
		  set_response     => 'set',	  
		  get_response     => 'get',
		  response_pairs   => 'kv',	  
	  },
);



override 'build' => \&_build;

override 'extract' => \&_extract;

=head1 SUBROUTINES/METHODS

=head2 _build

=cut


sub _build {
	my ($self) = @_;
	$self->logger->info($self->application() . " begin.");
	super();
	$self->logger->info($self->application() . " done");
}

sub BUILD {
	my ($self) = @_;
	$self->keysel(0);
}

=head2 _extract

L'extraction L2 et L6 est faite plus bas, voir les libs de typer Layer.

Extrait


=over 4

=item 	L7ConcentId
	
=item 	L7ModemId
	
=item	L7Rssi

=back

Aucun contrôle de validité des données n'est fait, utiliser check_parameters pour ce faire.

Accessible ainsi:

	say $ping->get_response('concent_id');


=cut

sub _extract {
	my ($self) = @_;
	$self->logger->info($self->application() . " begin.");
	super();
	my ($concent_id,$modem_id,$rssi) = unpack "H12 H2 H2", pack "H*", $self->decrypted();
	$self->concent_id($concent_id);
	$self->set_response(L7ConcentId => $concent_id);	
	$self->modem_id($modem_id);
	$self->set_response(L7ModemId => $modem_id);	
	$self->rssi($rssi);
	$self->set_response(L7Rssi => $rssi);
	$self->logger->info($self->application() . " done");
}

=head2	build_message

construit un message pong

Paramètres
	
	commande_name: undef, utilisé pour compatibilité avec les autres commandes
	
	datas: hashhref
		Attendu
			{
				L7ConcentId => '000102030405',
				L7ModemId	=> '01',
				RSSI		=> '01',
			}

Aucun contrôle n'est effectué sur la validité des données envoyées. Mais ne vous inquiétez pas, si c'est faux, vous recevrez une réponse bien sentie.			

Retourne:

	message (string hexadécimale)
			
=cut
sub build_message {
	my ($self,$commande_name,$datas) = @_;
	confess("L7ConcentId manque") unless $datas->{'L7ConcentId'};
	confess("L7ModemId manque") unless $datas->{'L7ModemId'};
	confess("RSSI manque") unless $datas->{'RSSI'};
	my $message = $datas->{'L7ConcentId'}.$datas->{'L7ModemId'}.$datas->{RSSI};
	$self->logger->debug("[build_message][PONG] L7: ".$message );
	return $message;
}

#vérification des paramètres, par rapport à ce qui est attendu

=head2 check_parameters

Pour le pong, comme le ping, ce n'est pas strictement nécessaire en l'absence de test associé.

TODO

	$commande_name: nom de la commande, undef parce que c'est du ping et qu'on le sait déjà
		mais c'est pour rester compatible avec les autres commandes
	
	$status_to_check
		reference de hash des erreurs à vérifier
	
	$parameters_to_check
		reference de hash des paramètres à vérifier
		id => valeur

=cut
sub check_parameters {
	my ($self,$commande_name,$status_to_check,$parameters_to_check) = @_;
	my $ok = 0;
	if (!$self->get_response('L7ConcentId')) {
		$ok = 1;
		$self->logger->error("L7ConcentId indéfini");
	}
	if (!$self->get_response('L7ModemId')) {
		$ok = 1;
		$self->logger->error("L7ModemId indéfini");
	}
	if (!$self->get_response('L7Rssi')) {
		$ok = 1;
		$self->logger->error("L7Rssi indéfini");
	}	
	my $params_found = {
		L7ConcentId => $self->get_response('L7ConcentId'),
		L7ModemId => $self->get_response('L7ModemId'),
		L7Rssi => $self->get_response('L7Rssi'),
	};	
	eval {
		$self->L7ConcentId($self->get_response('L7ConcentId'));
		$self->L7ModemId($self->get_response('L7ModemId'));
	};
	if ($@) {
		$self->logger->error("match error:  $@");
		$ok = 1;
	}
	
	return ($ok,$params_found);	
}


=head1 AUTHOR

phv, C<< <philippe.devisme at suez-env.com> >>

=head1 BUGS

Please report any bugs or feature requests to Ondeo Systems.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Telereleve::Application::Pong

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014-2015 Ondeo Systems.

This program is not free software; you cannot redistribute it and/or modify it.

=cut

1; # End of Telereleve::Application::Pong
