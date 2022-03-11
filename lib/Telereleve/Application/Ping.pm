package Telereleve::Application::Ping;

use Moose;
use feature qw(say);
use Data::Dumper;

extends 'Telereleve::Application';

with 'Telereleve::Helper::CheckDatas';

=head1 NAME

Telereleve::Application::Ping - Gestion d'une commande Ping

=head1 VERSION

Version 0.50

=cut

our $VERSION = '0.50';


=head1 SYNOPSIS

Gestion d'une commande INSTPING

Données envoyées par un ddc pour déterminer la présence de concentrateurs et modem lan voisins.

La commande PING est exécutée par le ddc à réception 

d'une commande lan COMMAND_EXECINSTPING

ou
	
d'une commande nfc EXEC_INSTPING
	
Les données nécessaires pour construire les parties basses de la trame (L2/L6) proviennent du fichier de campagne, mais peuvent être surchargées manuellement (pour le cas où vous voudriez faire une surprise au concentrateur).
	
    use Telereleve::Application::Ping;

    my $ping = Telereleve::Application::Ping->new(testname => 'nomtest' , mainconfig_file => 'campagne.cfg');
    
	$ping->build();
	say $ping->message_binary();
	ou
	say $ping->message_hexa();
	
Le contenu est à envoyé via un TRX, voir Telereleve::COM::Trx
	

=head1 ATTRIBUTES

=cut

has '+application' => (
	is 		=> 'rw',
	default => 'INSTPING',
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



=head1 SUBROUTINES/METHODS

=cut

override 'build' => \&_build;

override 'extract' => \&_extract;


=head2 _build

=cut


sub _build {
	my ($self,$message) = @_;
	$self->logger->info($self->application() . " begin.");
	confess("Message manquant") unless $message;
	super();
	$self->logger->info($self->application() . " done");
}

sub BUILD {
	my ($self) = @_;
	$self->keysel(0);
}

=head2 _extract

L'extraction L2 et L6 est faite plus bas, voir les libs de typer Layer.

extraction de la partie L7

=over 4

=item 	L7DownChannel
	
=item 	L7DownMod
	
=item	L7PingRxDelay
	
=item	L7PingRxLength

=back

Aucun contrôle de validité des données n'est fait, utiliser check_parameters pour ce faire.

Accessible ainsi:

	say $ping->get_response('L7DownChannel');

=cut

sub _extract {
	my ($self) = @_;
	$self->logger->info($self->application() . " begin.");
	super();
	#extraction des données L7
	my ($L7DownChannel,$L7DownMod,$L7PingRxDelay,$L7PingRxLength) = unpack "H2 H2 H2 H2", pack "H*", $self->decrypted();
	#$self->L7DownChannel(concent_id => $L7DownChannel);	
	$self->set_response(L7DownChannel => $L7DownChannel);	
	$self->set_response(L7DownMod => $L7DownMod);	
	$self->set_response(L7PingRxDelay => $L7PingRxDelay);		
	$self->set_response(L7PingRxLength => $L7PingRxLength);
	
	$self->logger->trace("L7DownChannel ". $L7DownChannel);
	$self->logger->trace("L7DownMod ". $L7DownMod);
	$self->logger->trace("L7PingRxDelay ". $L7PingRxDelay);
	$self->logger->trace("L7PingRxLength ". $L7PingRxLength);
	$self->logger->info($self->application() . " done");
}

=head2 build_message

Méthode sommaire de fabrication de la trame de données à envoyer
	
Paramètres

	$commande_name: toujours undef, mais reste pour compatibilité avec autres applications (COMMAND, RESPONSE, etc)
	
	$datas: hashref de chaines hexa, 
			L7DownChannel
			L7DownMod
			L7PingRxDelay
			L7PingRxLength

Aucun contrôle n'est effectué sur la validité des données envoyées. Mais ne vous inquiétez pas, si c'est faux, vous recevrez une réponse bien sentie.

Retourne:

	message (string hexadécimale)			
			
=cut
sub build_message {
	my ($self,$commande_name,$datas) = @_;
 	my $message = $datas->{'L7DownChannel'}.$datas->{'L7DownMod'}.$datas->{L7PingRxDelay}.$datas->{L7PingRxLength};
	return $message;
}

#vérification des paramètres, par rapport à ce qui est attendu

=head2 check_parameters

Pour le ping, ce n'est pas strictement nécessaire en l'absence de test associé.

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
	if (!$self->get_response('L7DownChannel')) {
		$ok = 1;
		$self->logger->error("L7DownChannel indéfini");
	}
	if (!$self->get_response('L7DownMod')) {
		$ok = 1;
		$self->logger->error("L7DownMod indéfini");
	}
	if (!$self->get_response('L7PingRxDelay')) {
		$ok = 1;
		$self->logger->error("L7PingRxDelay indéfini");
	}	
	if (!$self->get_response('L7PingRxLength')) {
		$ok = 1;
		$self->logger->error("L7PingRxLength indéfini");
	}	
	my $params_found = {
		L7DownChannel => $self->get_response('L7DownChannel'),
		L7DownMod => $self->get_response('L7DownMod'),
		L7PingRxDelay => $self->get_response('L7PingRxDelay'),
		L7PingRxLength => $self->get_response('L7PingRxLength'),
	};		
	return ($ok,$params_found);	
}


=head1 AUTHOR

phv, C<< <philippe.devisme at suez-env.com> >>

=head1 BUGS

Please report any bugs or feature requests to Ondeo Systems.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Telereleve::Application::Ping

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013-2014 Ondeo Systems.

This program is absolutly NOT free software; you cannot redistribute it nor modify it.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;

1; # End of Telereleve::Application::Ping
