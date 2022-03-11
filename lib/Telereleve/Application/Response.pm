package Telereleve::Application::Response;

use Moose;
use feature qw(say);
use Data::Dumper;

extends 'Telereleve::Application';

with 'Telereleve::Helper::CheckDatas';

use Exporter qw(import);
our @EXPORT_OK = qw(RESPONSE_READPARAMETERS RESPONSE_WRITEPARAMETERS  RESPONSE_WRITEKEY  RESPONSE_ANNDOWNLOAD RESPONSE_EXECINSTPING 
				);
our %EXPORT_TAGS = ( Responses => [ qw(RESPONSE_READPARAMETERS RESPONSE_WRITEPARAMETERS  RESPONSE_WRITEKEY  RESPONSE_ANNDOWNLOAD  RESPONSE_EXECINSTPING) ] 
					);

=head1 NAME

Telereleve::Application::Response - Gestion des réponses LAN

=head1 VERSION

Version 0.5

=cut

our $VERSION = '0.5';

=head1 SYNOPSIS

SFTD de référence: v1.10

Librairie pour traiter les réponses LAN, voir dans la SFTD LAN les parties suivantes: 9.6.2, 10

L'usage principale de cette librairie est l'analyse de trames radio envoyées par un DDC, voir la SFTD LAN pour plus de précisions sur les dites trames.

On peut aussi l'utiliser pour simuler un ddc et donc générer des trames de réponse, si, si!

Elle est totalement et strictement indépendante des moyens de communication, il est donc possible de l'utiliser pour analyser une trame stockée dans un fichier texte simple (analyse_trames_lan.pl).


B<ATTENTION>

La méthode extract attend une chaîne binaire, voir L<Telereleve::Layer::Liaison|telereleve-layer-liaison.html>.

B<Exemple>

    use Telereleve::Application::Response;
	ou
	use Telereleve::Application::Response qw(:Responses);

    my $response = Telereleve::Application::Response->new(testname => 'nomtest' , mainconfig_file => 'campagne.cfg');

	#decomposition et dechiffrement de la trame avec extract
	eval {
		$response->extract(pack('H*',$trame_hexa_recue_par_tout_moyen_a_votre_disposition));
	};
	if ($@) {
		say $@;
	}
	#verification des paramètres avec check_parameters
	my ($verdict,$params_found);
	eval {
		($verdict,$params_found) = $response->check_parameters(
						'RESPONSE_READPARAMETERS',
						{'L7ErrorCode' => '00'},
						{'RF_UPSTREAM_CHANNEL' => '64'}
						);
	};
	if ($@) {
		$self->fatal_error($verdict);
		$self->logger()->fatal("[parse frame] $@->{message}");
		confess( $@ );		
	}	
	
Voir plus bas le fonctionnement détaillé de B<L<check_parameters>>.
	
A partir de là plusieurs actions sont possibles.
	
Les détails de base de la trame L7 sont disponibles de deux façons différentes:
	
	$response->L7ResponseId();
	$response->L7ErrorCode();
	$response->L7SwVersion();
	$response->L7Rssi();
	
ou en appelant la commande get_response avec le paramètre souhaité (nom de la SFTD).
	 
	$response->get_response('L7ResponseId');
	
En cas d'erreur, on peut lire les réponses avec get_response également.

	$response->get_response('L7ErrorParam');
	
	
Liste des réponses possibles

	$response->response_pairs();

Une fois ces réponses obtenues, des informations complémentaires sont disponibles selon le type de commande: pong et read_parameters

Extraction des données des pongs

	$response->get_pongs()
	
	my %pong = $response->read_pong(0);	
	$response->nb_pongs();
	
Contenant

		L7ConcentId
		L7ModemId
		L7RSSIUp
		L7RSSIDown	
		
	for (my $i=0;$i < $response->count_pongs; $i++) {
		my %pong_detail = $pong->read_pong($i);
		#cles, voir perldoc read_pong
		#L7ConcentId
		#L7ModemId
		#L7RSSIUp
		#L7RSSIDown
	}

Lecture des paramètres lus
	
	my %parameters = $response->read_response_parameters();
	say $response->get_response_parameter_name('CURRENT_STATE');
	foreach my $pair ( $response->response_parameters_name_pairs()) {
		say "pair: ". Dumper($pair);
	}

=head2 Gestion des erreurs

En cas derreur, la lib se confesse, donc il faut toujours utiliser C<eval>.

	eval {  $response->get_pongs() };
	if ($@) {
		say $@;
	}

Attention: $@ est une chaîne brute. voir le module Perl appelé Carp.

=cut

=head2 EXPORT

Déclaration pour exporter les identifiants des différentes commandes.


	use Telereleve::Application::Response qw(:Responses);

=cut

=head2 Attributes

=cut

has '+application' => (
	is 		=> 'rw',
	default => 'RESPONSE',
);

has 'L7ResponseId' => (
	is 		=> 'rw',
);

has 'L7ErrorCode' => (
	is 		=> 'rw',
);

=head2 extracted_parameters

Données métier extraites des trames (de type read ou write).

=cut
has 'extracted_parameters' => (
	is 			=> 'rw',
	predicate 	=> 'has_extracted_parameters'
);

has 'L7ErrorParam' => (
	is 			=> 'rw',
);

has 'nb_pong' => (
	is 			=> 'rw',
);

=head2 Types de réponses

Ces réponses sont exportables, voir ci-dessus.

	RESPONSE_READPARAMETERS 
	RESPONSE_WRITEPARAMETERS  
	RESPONSE_WRITEKEY  
	RESPONSE_ANNDOWNLOAD 
	RESPONSE_EXECINSTPING

Usage:

	say RESPONSE_READPARAMETERS;
	
	affiche 16
	
	say sprintf("%02X", RESPONSE_READPARAMETERS)
	
	affiche 10

=cut
sub RESPONSE_READPARAMETERS 	() {0x10}
sub RESPONSE_WRITEPARAMETERS 	() {0x20}
sub RESPONSE_WRITEKEY 			() {0x28}
sub RESPONSE_ANNDOWNLOAD 		() {0x30}
sub RESPONSE_EXECINSTPING 		() {0x40}


=head2 pongs

Tableau (arrayref) des pongs récupérés.

Après avoir extrait la trame L7, voir ci-dessus, appeler: 

	$response->get_pongs();
	#puis
	
	my %pongs = $response->read_pong(0);
	#coentnu du pong, voir plus bas
	%pongs = {
		L7ConcentId 	=> 'value',
		L7ModemId 	=> 'value',
		L7RSSIUp		=> 'value',
		L7RSSIDown	=> 'value',
	};

Méthodes:

	get_pong
	count_pongs
	all_pongs
	add_pong
	map_pong
	filter_pong
	find_pong
	has_pongs
	has_no_pongs


=cut
has 'pongs' => (
  traits    => ['Array'],
  is        => 'ro',
  isa       => 'ArrayRef',
  default   => sub { [] },
  handles   => {
            all_pongs    => 'elements',
            add_pong     => 'push',
            map_pong     => 'map',
            filter_pong  => 'grep',
            find_pong    => 'first',
            get_pong     => 'get',
            count_pongs  => 'count',
            has_pongs    => 'count',
            has_no_pongs => 'is_empty',
            clear_pongs  => 'clear',
  },
);

=head2 response_template

Hash listant les structures de chaque type de trame. 

En cas de modification de la SFTD, il faut modifier ces éléments pour qu'ils correspondent au nouveau format.

Utiliser avec pack/unpack pour générer ou analyser un trame L7 de réponse.

Liste encore valide début 2015.

	'10' 	=> "H2 H2 H4 H2 H*", 		#response_readparameters
	'20' 	=> "H2 H2 H4 H2",				#response_writeparameters
	'28' 	=> "H2 H2 H4 H2",				#response_writekey
	'30'	=> "H2 H2 H4 H2",				#response_anndownload
	'40'	=> "H2 H2 H4 H2 H2 H18 H18 H18",	#response_execinstping

Méthodes

	get_response_template('10');
	
	response_templates_list

=cut
has 'response_template' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef[Str]',
  default   => sub { {
		'10' 	=> "H2 H2 H4 H2 H*", 		#response_readparameters
		'20' 	=> "H2 H2 H4 H2",				#response_writeparameters
		'28' 	=> "H2 H2 H4 H2",				#response_writekey
		'30' 	=> "H2 H2 H4 H2",				#response_anndownload
		'40' 	=> "H2 H2 H4 H2 H2 H18 H18 H18",	#response_execinstping
  } },
  handles   => {
	  get_response_template     => 'get',
	  response_templates_list   => 'kv',
  },
);

=head2 error_responses

Hashref des réponses en fonction du type de réponses

Méthodes

	get_error_response
	
	liste_errors_response
	
Exemple d'usage:

	say $reponse->get_error_response(RESPONSE_READPARAMETERS)->{1};

	affiche: 	Numéro de paramètre non supporté, voir la sftd lan

	
=cut
has 'error_responses' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
#   default   => sub { {
#         10 => {
#                 1 => "Numéro de paramètre non supporté",
#                 2 => "Tentative de lecture d'un élément write only",
#                 3 => "Réponse trop longue pour être transmise",
#                 255 => "Commande non supportée"
#                 },
#         20 => {
#                 1 => "Numéro de paramètre non supporté",
#                 2 => "Tentative de lecture d'un élément write only",
#                 3 => "Tentative d'affectation d'une valeur illégale",
#                 4 => "Réponse trop longue pour être transmise"
#                 }, 
#         28 => {
#                 1 => "Longueur de trame incorrecte",
#                 2 => "Valeur illégale d'un paramètre",
#                 3 => "Clé de chiffrement Kchg non utilisée",
#                 }, 
#         30 => {
#                 1 => "Valeur illégale d'un paramètre",
#                 2 => "Longueur de trame incorrecte",	
#                 3 => "Mauvaise version logicielle de départ",
#                 4 => "Mauvaise version matérielle du dispositif de comptage",
#                 5 => "Clé de chiffrement Kchg non utilisée",
#                 6 => "Jour de début de diffusion incorrect",
#                 7 => "Opération refusée, car mise à jour est en cours depuis interface locale",
#                 },
#         40 => {
#                 1 => "Longueur de trame incorrecte",
#                 2 => "Valeur illégale d'un paramètre",
#                 3 => "Clé de chiffrement Kchg non utilisée",
#                 }, 
#   } },
  default   => sub { {
        10 => {
                1 => "Unknown parameter id",
                2 => "Write Only parameter",
                3 => "Response too long",
                255 => "Unsupported command"
                },
        20 => {
                1 => "Unknown parameter id",
                2 => "Read Only parameter",
                3 => "Fobidden value",
                4 => "Response too long"
                }, 
        28 => {
                1 => "Uncorrect frame length ",
                2 => "Fobidden value",
                3 => "Ciphering key Kchg has to be used",
                }, 
        30 => {
                1 => "Fobidden value",
                2 => "Uncorrect frame length ",
                3 => "Wrong initial firmware version",
                4 => "Wrong hardware version",
                5 => "Ciphering key Kchg has to be used",
                6 => "Wrong first firmware broadcast day",
                7 => "Local update is already in progress",
                8 => "Target software version",
                9 => "Target version already downloaded, waiting for update",
                10 => "Diffusion time out of broadcasting window",
                },
        40 => {
                1 => "Uncorrect frame length ",
                2 => "Fobidden value",
                3 => "Ciphering key Kchg has to be used",
                }, 
  } },
  handles   => {
	  get_error_response     => 'get',
	  liste_errors_response   => 'kv',
  },
);


=head2 responses

Hashref contenant les réponses communes extraites des trames.

	L7ResponseId
	L7ErrorCode
	L7SwVersion
	L7Rssi
	L7ErrorParam

Méthodes disponibles
	
=head3 	set_response

	$response->set_response('L7ResponseId' => 10);
		
=head3	get_response

	say $response->get_response('L7ErrorCode');
		
=head3 	response_pairs

  for my $pair ( $response->response_pairs ) {
      print "$pair->[0] = $pair->[1]\n";
  }

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

has 'commandes' => (
	  traits    => ['Hash'],
	  is        => 'ro',
	  isa       => 'HashRef[Str]',
	  default   => sub { {	
			'RESPONSE_READPARAMETERS' 	=> '10',
			'RESPONSE_WRITEPARAMETERS' 	=> '20',			
			'RESPONSE_WRITEKEY' 	  	=> '28',
			'RESPONSE_ANNDOWNLOAD' 	  	=> '30',			
			'RESPONSE_EXECINSTPING' 	=> '40',
			'10' => 'RESPONSE_READPARAMETERS',
			'20' => 'RESPONSE_WRITEPARAMETERS',			
			'28' => 'RESPONSE_WRITEKEY',
			'30' => 'RESPONSE_ANNDOWNLOAD',			
			'40' => 'RESPONSE_EXECINSTPING',
	  } },
	  handles   => {
		  get_commande     => 'get',
		  add_commande     => 'set',
		  commande_pairs   => 'kv',
	  },
);

=head2 response_parameter_name

Tableau des paramètres demandés au DDC extraits de la trame L7 et disponibles, ça concerne uniquement les RESPONSE_READPARAMETERS.

Méthode pour obtenir la valeur d'un paramètre donné.
	
	get_response_parameter_name

	all_response_parameters
		liste des réponses
	
	response_parameters_keys
		Liste des clés possibles


	say $response->get_response_parameter_name('CLOCK_CURRENT_EPOCH');
		
=cut

has 'response_parameter_name' => (
	  traits    => ['Hash'],
	  is        => 'ro',
	  isa       => 'HashRef',
	  default   => sub { {

	  } },
	  handles   => {
		  set_response_parameter_name     => 'set',			
		  get_response_parameter_name     => 'get',
		  response_parameters_name_pairs   	=> 'kv',
		  response_parameters_name_keys 		=> 'keys',
		  all_response_parameters_name		=> 'elements',		  
	  },
);

override 'build' => \&_build;

override 'extract' => \&_extract;

=head1 SUBROUTINES/METHODS


=head2 _build

C'est très simple, transparent et facile à comprendre, les couches basses bossent sans s'abaisser (bis). 

Il faut juste donner une trame L7 correcte, ou pas. L'application ressort une trame toute propre sans (trop) se poser de questions.

La trame est disponible sous la forme:

	$commande->message_hexa();
	
	ou
	
	$commande->message_binary();

Pour en savoir plus, il faut se pencher sur L<Telereleve::Layer::Liaison|telereleve-layer-liaison.html>.

=cut


sub _build {
	my ($self,$message) = @_; 
	$self->logger->info($self->application() . " begin.");
	super();
	$self->logger->info($self->application() . " done");
}

=head2 _extract

Extraction des données des trames L2 et L6, travail réalisé en amont dans les libs Liaison et Presentation.

Le travail effectif est réalisé par B<extract> qui est une méthode de L<Telereleve::Application|telereleve-application.html> qui elle-même s'appuie sur L<Telereleve::Layer::Presentation|telereleve-layer-presentation.html>. 

	$response->extract();

Voir L<Telereleve::Layer::Presentation|telereleve-layer-presentation.html> pour avoir plus de précisions.
	
Les éléments concernant le statut de la réponse sont enregistrés dans le tableau.
		
	L</responses>
		
L'attribut L</extracted_parameters> contient les paramètres extraits sous forme de chaîne héxa.		
		
=cut

sub _extract {
	my ($self) = @_; 
	$self->logger->info($self->application() . " begin.");
	super();
	#elements de base d'une trame de reponse
	my ($parameters) = $self->extract_base_trame();
	
	$self->extracted_parameters(uc($parameters)) if $parameters;
	#extraction de données pour read_parameters et pong uniquement
	#$self->logger->info("L7ResponseId: " .  $self->L7ResponseId());
	
	
	if ( $self->L7ResponseId() eq sprintf("%02X",RESPONSE_READPARAMETERS)) 
	{
            $self->read_response_parameters();
	} 
	elsif ( $self->L7ResponseId() eq sprintf("%02X",RESPONSE_WRITEPARAMETERS)) 
	{ 
            #$self->read_response_parameters();
	} 
	elsif ( $self->L7ResponseId() eq sprintf("%02X",RESPONSE_WRITEKEY)) 
	{ 
            #$self->read_response_parameters();
	} 
	elsif ( $self->L7ResponseId() eq sprintf("%02X",RESPONSE_ANNDOWNLOAD)) 
	{
            #$self->read_response_parameters();
	} 
	elsif ($self->L7ResponseId() eq sprintf("%02X",RESPONSE_EXECINSTPING)) 
	{
            $self->get_pongs();
	} 
	else 
	{
		#$self->logger->warn("ResponseId inconnu [" . $self->L7ResponseId() . "]");
		#confess({error => 0x02, message => "ResponseId inconnu [" . $self->L7ResponseId() . "]"});
	}
	$self->logger->info($self->application() . " done");
}

=head2 extract_base_trame

Extrait les éléments de base d'une trame, voir la sftd LAN à ce sujet.

Retourne:

	$parameters: chaine hexa des paramètres trouvés 

	
=cut
sub extract_base_trame {
	my ($self) = @_;
	my ($response_id,$error_code,$sw_version,$rssi,$parameters, $reste);
	
	#($response_id,$error_code,$sw_version,$rssi,$parameters) = unpack("H2 H2 H4 H2 H*", pack("H*", $self->decrypted() ) );
        ($response_id, $error_code, $reste) = unpack("H2 H2 H*", pack("H*", $self->decrypted() ) );
	
	confess({error => 0x07 , message => "unknown response type"}) unless $self->get_error_response($response_id);

	$self->L7ResponseId($response_id);
	$self->set_response(L7ResponseId => $response_id);
	
	$self->L7ErrorCode($error_code);
	$self->set_response(L7ErrorCode => $error_code);
	
	if (hex($error_code) == 0) 
	{ 
            ($sw_version, $rssi, $parameters) = unpack("H4 H2 H*", pack("H*", $reste ) );
            # No error
            eval 
            {
                $self->L7SwVersion($sw_version) ;
            };
            if ($@) 
            {
                confess({error => 0x07 , message => "probleme avec le parametre L7SwVersion. Pas la bonne version attendue. Laisser vide ou modifier le fichier de conf"})
            }
            $self->set_response(L7SwVersion => $sw_version);
            $self->L7Rssi($rssi);
            $self->set_response(L7Rssi => $rssi);
            
            $self->logger->trace("L7ResponseId: " . $self->L7ResponseId() . " (" . $self->get_commande($response_id) .")");
            $self->logger->trace("Frame       : " .$self->decrypted());
            $self->logger->trace("SW version  : " .$sw_version );
            $self->logger->trace("RSSI	       : " .$rssi );
            $self->logger->trace("Error code  : " .$error_code );
            $self->logger->trace("Datas       : [" .$parameters."]" );            
            
	} 
	elsif ( hex($error_code) > 0 ) 
	{
            ($parameters) = unpack("H4 H2 H*", pack("H*", $reste ) );
            # Error
            #my ($response_id,$error_code,$error_param) = unpack("H2 H2 H2", pack("H*", $self->decrypted() ) );
            $self->L7ErrorParam($parameters);
            $self->set_response(L7ErrorParam => $parameters);

            $self->logger->trace("L7ResponseId: " . $self->L7ResponseId() . " (" . $self->get_commande($response_id) .")");
            $self->logger->trace("Frame       : " .$self->decrypted());
            $self->logger->trace("Error code  : " .$error_code );
            $self->logger->trace("Datas       : [" .$parameters."]" );
	}
	if( $parameters )
	{
            return $parameters;
	}
	else 
	{
            return undef;
	}       
}

=head2 read_response_parameters

Analyse les données trouvés dans la trame s'ils exixtent et les place dans le hashref B<responses> voir ci-dessus.

Voir l'exemple donné en début de cette aide. Ne pas utiliser directement.
	
=cut
sub read_response_parameters {
	my ($self) = @_;
	return undef if hex($self->L7ErrorCode()) != 0x00  ;
	confess( {error => 0x07 , message => "No parameters received."}) unless $self->has_extracted_parameters && hex($self->L7ErrorCode()) == 0x00  ;
	my $datas_extract = $self->extracted_parameters;
	my $base_trame = $datas_extract;
	my $deja_vu = '';
	while ( my ($param_id) = $datas_extract =~ m/^([A-Fa-f0-9]{2})/) 
	{
		$param_id = uc($param_id);
		if ($deja_vu eq $param_id ) {
			confess({error => 0x07 , message => "parameter already seen (frame:$base_trame)" });
		}
		$deja_vu = $param_id;
		confess({error => 0x07 , message => "Unknown parameter: MIA ? $param_id"}) unless $self->get_parameter_name_by_id($param_id);
		my $len = $self->get_parameter_name_by_id($param_id)->[1] * 2;
		$datas_extract =~ s/$param_id([A-Fa-f0-9]{$len})?//;
		my $value = $1;
		confess({error => 0x07 , message =>"Missing value"})  unless $value;				
		confess({error => 0x07 , message =>"Value: false length, check your datas. $value (expected length: ".$self->get_parameter_name_by_id($param_id)->[1].")"}) 
				if length($value) != $len;
		$self->logger->info("$param_id : ".$self->get_parameter_name_by_id($param_id)->[0]." => $value");
		$self->set_response_parameter_name( $self->get_parameter_name_by_id($param_id)->[0] => uc($value)  );
	}
}

=head2 get_pongs

Initialise le tableau des pongs et le nombre de pongs renvoyés dans la trame
	
	my $response = new Telereleve->Application::Response();
	$response->_extract();
	$response->get_pongs();	
	
=cut

sub get_pongs {
	my ($self) = @_;
	confess({error => 0x07 , message =>"This frame is not pong response!"}) unless $self->L7ResponseId() eq "40";
	
	$self->clear_pongs();
	my (undef,undef,undef,undef,$nbpong,@pongs) = unpack("H2 H2 H4 H2 H2 H18 H18 H18", pack("H*", $self->decrypted() ) ); 
	$self->add_pong(@pongs);
	$self->nb_pong($nbpong);
	
        if ($self->count_pongs > 0) 
        {
            $self->logger->info("Nb PONG ". $self->nb_pong);
            $self->logger->info("i : L7ConcentId : L7ModemId : L7RSSIUp : L7RSSIDown");
        }
        
        for (my $i=0; $i < $self->count_pongs; $i++) 
        {
            my %pong_detail = $self->read_pong($i);
            $self->logger->info(
                $i 
                ." : " . $pong_detail{'L7ConcentId'}
                ." : " . $pong_detail{'L7ModemId'}
                ." : " . $pong_detail{'L7RSSIUp'}
                ." : " . $pong_detail{'L7RSSIDown'});
        }
	
	return 0;
}

=head2 read_pong

Retourne un hash du pong demandé
	
	my %pong = $response->read_pong(0);
	
clés: 

=over 4
	
=item 	L7ConcentId

=item 	L7ModemId

=item 	L7RSSIUp

=item 	L7RSSIDown

=back
	
=cut

sub read_pong {
	my ($self,$index) = @_;
	confess({error => 0x07 , message =>"This frame is not a pong response."}) unless $self->L7ResponseId() eq "40";
	confess({error => 0x07 , message =>"Index not present or out of array"}) if !defined($index) || $index + 1 > hex( $self->nb_pong());
	my ($concent_id,$modem_id,$rssi_up,$rssi_down) = unpack("H12 H2 H2 H2", pack("H*", $self->get_pong($index) ) ); 
	return ( 'L7ConcentId' => $concent_id,'L7ModemId' => $modem_id,'L7RSSIUp' => $rssi_up,'L7RSSIDown' => $rssi_down);
}

#vérification des paramètres, par rapport à ce qui est attendu

=head2 check_parameters

Méthode qui vérifie les paramètres extraits de la trame par rapport à ce qu'un test demande.

Le détail des erreurs est loggé.

Exemple:

	my $appli =  new Telereleve::Application::Response(testname => 'nomtest' , mainconfig_file => 'campagne.cfg');
	eval {
		$appli->extract(pack('H*',$trame));
	};
	if ($@) {
		say Dumper($@);
	}
	my ($verdict,$params_found) = $appli->check_parameters('RESPONSE_WRITEPARAMETERS',
							{
								  'L7Rssi' => 'valide',
								  'L7SwVersion' => 'valide',
								  'L7ResponseId' => '20',
								  'L7ErrorCode' => '00'
							},
							{'RF_UPSTREAM_CHANNEL' => '64'}
				);
	say "verdict $verdict";
	say Dumper($params_found);

	
Parametres:

	$commande_name: nom de la commande (RESPONSE_WRITEPARAMETERS/RESPONSE_READPARAMETERS)
		voir plus haut les Types de réponses disponibles
	
	$status_to_check: 
		référence de hash des statuts de la réponse, données communes à toutes les trames
		Les noms correspondent à ce que peut trouver dans la sftd lan
	
		{id => valeur}

		
		
	$parameters_to_check
		reference de hash des paramètres à vérifier
		Les noms correspondent à ce que peut trouver dans la sftd lan
		{id => valeur}
		
		Pour les valeurs, les 3 premiers sont équivalents, je pensais avoir des usages différents en décembre 2013 :), 
		ils contrôlent la validité de la valeur obtenue. 
		La liste des paramètres et des valeurs possibles se trouve dans L<Telereleve::Helper::CheckDatas|telereleve-helper-checkdatas.html>.
		Les valeurs peuvent contenir:
		
		valide
		save
		conf
		une chaîne héxadécimale contenant la valeur attendue
		
		
		
Retourne:
	
	verdict (entier)
	0 : ok 
	ou
	1 : failed
	
	params_found
	hashref des paramètres reçus avec les noms de paramètres

	{
		'RF_UPSTREAM_CHANNEL' => '78',
		'PAS_MESURE' => '00'
	}
	

=cut
sub check_parameters {
	my ($self,$commande_name,$status_to_check,$parameters_to_check) = @_;
	my $ok = 0;
	my $params_found = {};
	#verif des erreurs possibles
	foreach my $champ (keys %$status_to_check) {
		#peut vérifier la version notamment L7SwVersion
		if ($status_to_check->{$champ} =~ m/(?:valide|config|save)/i) {
			#exception qui concerne 2 tests, pas trouvé de solution transparente et pas le temps de chercher
			if ($champ =~ m/-/) {
				($ok) = $self->check_liaison_datas($champ);
			} else {
				eval {
					$self->$champ($self->get_response($champ));
				};
				if ($@) {
					$self->logger()->error("error: $champ => expected [$status_to_check->{$champ}] - received [" . $self->get_response($champ) . "]" );	
					$ok = 1;				
				}
			}
		} elsif ( hex($status_to_check->{$champ}) != hex($self->get_response($champ)) ) {
			$self->logger()->error("error: $champ => expected [$status_to_check->{$champ}] - received [" . $self->get_response($champ) . "]" );
			$ok = 1;
		} else {
			$self->logger()->info("Status OK: expected [$status_to_check->{$champ}] - received [" . $self->get_response($champ) . "]");
		}
	}
	if (hex($self->L7ErrorCode()) != 0) {
		return ($ok,$params_found);
	}
	
	#verif des paramètres
	foreach my $param (keys %$parameters_to_check) {
		if (!$self->get_response_parameter_name($param)) {
			$self->logger->error("error: $param not found in response");
			$ok = 1;
			next;
		}
		#$self->METER_MANUFACTURER("010203");
		$params_found->{$param} = $self->get_response_parameter_name($param);
		if (hex($self->L7ErrorCode()) != 0) {
			 #a priori on ne fait rien
		} else {
			eval {
				if ($parameters_to_check->{$param} =~ m/(?:valide|save|conf)/i) {
					#exemple
					#$self->METER_MANUFACTURER("010203");				
					$self->$param( $self->get_response_parameter_name($param) );
				} else {
					$self->$param( $parameters_to_check->{$param} );
					if (hex($parameters_to_check->{$param}) != hex($self->get_response_parameter_name($param))) {
						$self->logger->error("match error! expected: $parameters_to_check->{$param} - received:" . $self->get_response_parameter_name($param));
						$ok = 1;				
					}
				}
			};
			if ($@) {
				$self->logger->error("error: $param => expected [$parameters_to_check->{$param}] - received [" . $self->get_response_parameter_name($param) . "]" );	
				$ok = 1;
			}
		}
	}
	return ($ok,$params_found);
}



=head2 build_message

Génération de message de type Response (pour les cas désespérés où vous voudriez vous prendre pour un DdC).

Pas vraiment compliqué ni vraiment utile non plus, permet surtout d'éviter de connaître l'identifiant du type de réponse.

Quizz pour les nuls: Quel est l'identifiant de RESPONSE_WRITEKEY ?

Paramètres

	commande_name (string)
		
	parametres (string) sous forme de chaîne héxadécimale
		
	$complement: paramètres compplémentaires sous forme de hashref
		
Retourne:

	message chaîne héxadécimale

		
=cut
sub build_message {
	my ($self,$commande_name,$parameters,$complement) = @_;
	my $message;
	if ($commande_name) {
		my $commande_id = $self->get_commande(uc($commande_name));
		$self->logger->info("$commande_name => $commande_id");
		#commande read et write parameters
		if ( hex($commande_id) == RESPONSE_READPARAMETERS 
			 || hex($commande_id) ==   RESPONSE_WRITEPARAMETERS
			 || hex($commande_id) ==   RESPONSE_EXECINSTPING	) {
			$message = uc( $self->get_commande(uc($commande_name)) 
					. $complement->{'L7ErrorCode'}
					. ($self->L7SwVersion() || $complement->{'L7SwVersion'})
					. $complement->{'L7Rssi'}
					. $parameters);	
			
		} elsif ( hex($commande_id) == RESPONSE_ANNDOWNLOAD ) {
			$parameters .= $self->L7DwnldId().  $self->L7Klog().  $self->L7SwVersionIni().  $self->L7SwVersionTarget()
						.  $self->L7MField().  $self->L7DcHwId().  $self->L7BlocksCount().  $self->L7ChannelId()
						.  $self->L7ModulationId().  $self->L7DaysProg().  $self->L7DaysProg().  $self->L7DeltaSec()
						.  $self->HashSW();
						
			$message = uc( $self->get_commande(uc($commande_name))
					. $complement->{'L7ErrorCode'}
					. ($self->L7SwVersion() || $complement->{'L7SwVersion'})
					. $complement->{'L7Rssi'}
				. $parameters);
		} elsif ( hex($commande_id) == RESPONSE_WRITEKEY ) {
			$parameters .= $self->L7KeyVal();
			$message = uc( $self->get_commande(uc($commande_name)) 
					. $complement->{'L7ErrorCode'}
					. ($self->L7SwVersion() || $complement->{'L7SwVersion'})
					. $complement->{'L7Rssi'}			
				. $parameters);	
		}
		#commandes writekey/ann_download
	}
	return $message;
}


sub check_liaison_datas {
	my ($self,$champ) = @_;
	my $ok = 0;
	my $champ_clean = $champ;
	$champ_clean =~ s/-//g;
	if ($self->get_liaison_response($champ)) {
		eval {
			$self->$champ_clean($self->get_liaison_response($champ));
		};
		if ($@) {
			$self->logger->error("error $champ " . $self->get_liaison_response($champ) );
			$ok = 1;
		}
	} else {
		$ok = 1;
	}
	return $ok;
}

=head1 AUTHOR

phv, C<< <philippe.devisme at suez-env.com> >>

=head1 BUGS

Please report any bugs or feature requests to Ondeo Systems.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Telereleve::Application::Response
	
	libdocs/index.html

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014-2015 Ondeo Systems.

This program is NOT free software; you cannot redistribute it and/or modify it.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;

1; # End of Telereleve::Application::Response
