package Telereleve::Application;

use Moose;

use feature qw(say);
use Data::Dumper;

use Carp;
use Config::Tiny;
use Log::Log4perl qw(:easy);
use Log::Log4perl::Appender::File;
use Time::Piece;
use Sys::Hostname;

with 'Telereleve::Layer::Liaison',
     'Telereleve::Layer::Presentation',
     'Telereleve::Helper',
     'Telereleve::Helper::CheckDatas';

=head1 NAME

Telereleve::Application - Couche applicative (couche L7)

=head1 VERSION

Version 0.50

=cut

our $VERSION = '0.50';


=head1 SYNOPSIS

Ce module Perl est la B<classe centrale> pour la gestion des couches applicatives (couche L7) du banc de test 
dans le cadre d'une campagne de tests.
	
Il n'est pas utilisable directement, mais à travers une classe spécialisée (voir ci-dessous les différentes applications possibles).

Il peut être utilisé pour trouver le type de trame utilisé dans le cadre des communications lan, voir check_flux. L'information sur le type de trame est dans la trame elle-même et en fonction de celle-ci, il sera possible d'utiliser

L<Telereleve::Application::Data|telereleve-application-data.html>

ou

L<Telereleve::Application::Response|telereleve-application-response.html>

ou

L<Telereleve::Application::Ping|telereleve-application-ping.html>

	
Rôles:

=over 4

=item Chargement de la configuration.

=item Chargement du module de log

=item Construction de trames avant envoi

Appel des méthodes (L<Presentation/L6|telereleve-layer-presentation.html> puis L<Liaison/L2|telereleve-layer-liaison.html>) permettant de construire une trame de données.

=item Analyse de trames après réception

Appel des méthodes (L<Liaison/L2|telereleve-layer-liaison.html> puis L<Presentation/L6|telereleve-layer-presentation.html>) permettant de décomposer une trame de données.

=back

Par exemple:

    use Telereleve::Application::Command;
	
    my $appli = Telereleve::Application::Command->new(testname => 'nomtest' , mainconfig_file => 'campagne.cfg');

	$appli->build('0000');
	
	Trame générée
	
	$appli->message_binary();
	
En sens inverse, la réception d'une trame
	
	$appli->extract("trame binaire");
	
	Le message (L7) est disponible via
	
	$appli->decrypted();
	
Pour Data et Response, voir les libs correspondantes
	
	perldoc L<Telereleve::Application::Data|telereleve-application-data.html>
	
	perldoc L<Telereleve::Application::Response|telereleve-application-response.html>
	

=head2 Log

La mise en oeuvre des logs est faite ici à travers le fichier de configuration.

Librairie utilisée pour les logs: L<Log::Log4Perl>

Fonctionnement

L'appel du fichier de log utilisé est réalisé à travers le fichier de configuration campagne.cfg


	[main]
	conflog=etc/campagnelog.cfg

Pour avoir un exemple de fichier de logs, voir dans le réperpoire git modules/tests	

=head2 Configuration

La configuration générale est chargée par ce module.

Le fichier de conf est un paramètre obligatoire.
	
Ce fichier de conf doit charger tous les éléments nécessaires à une campagne de tests.

voir L<Config::Tiny>

=head2 Données du fichier de configuration

Les valeurs sont en hexa, sauf précision contraire	

	
	[main]
	#informations générales
	#Emplacement du fichier de conf des logs
	conflog=fabricants\sappel\ddc\carte-demonstration\v1.0\etc\campagnelog.cfg
	application_conf=fabricants\sappel\ddc\carte-demonstration\v1.0\etc\applications.cfg
	#hexa
	kmac=214B6D61636465746573743230313423
	#kmac=00000000000000000000000000000000
	kenc0=00000000000000000000000000000000
	kenc1=00000000000000000000000012C7C5B1
	kenc2=00000000000000000000000012C7C5B2
	...
	kenc15=00000000000000000000000012C7C5B3

	klog=2334313032747365746564676F6C4B21
	#klog=00000000000000000000000000000000
	kmob=2334313032747365746564676F6C4B21
	#kmob=00000000000000000000000000000000
	master_pwd=
	integrator_pwd=717E75791D23281F

	[liaison]
	#données spécifiques à la couche L2
	#hexa et msb
	#Itron: ITG => 2687
	#Sappel : DME => 11A5
	#Sagemcom: SAG => 4C27	
	id_fabricant=a remplir
	#utilisé pour les trames lan
	id_ddc=a remplir avec radio_number en lsb
	download_id=224

	[presentation]
	#integer
	#clef kenc utilisée: de 0 à 14
	keysel=1
	#integer, précise si la trame contient un timestamp ou non
	wts=1
	#hexa optionnel, prend l'heure courante si le champ est vide
	timestamp=
	#integer, n'importe quelle valeur
	cpt=54
	downbnum=30

	#l'entrée correspond à un des ddc enregistré dans liaison
	[DDC]
	MASTER_PWD=a remplir
	INTEGRATOR_PWD=a remplir
	VERS_FW_TRX=a remplir
	VERS_HW_TRX=a remplir
	RADIO_NUMBER=a remplir
	RADIO_MANUFACTURER=a remplir
	METER_NUMBER=a remplir
	METER_MANUFACTURER=a remplir
	RF_DOWNSTREAM_CHANNEL=64
	RF_DOWNSTREAM_MOD=00
	TYPE_MODULE=a remplir avec 00 ou 01
	PING_RX_DELAY=10
	PING_RX_LENGTH=10
	L7SwVersion=2000
	L7KeyVal=010203040506070809L7KeyVal=010203040506070809
	L7DwnldId=010203
	L7Klog=0102030405067080900010203040506
	L7SwVersionIni=0102
	L7SwVersionTarget=0102
	L7MField=0102
	L7DcHwId=0102
	L7BlocksCount=0002
	L7ChannelId=01
	L7ModulationId=01
	L7DaysProg=0078
	L7DaysRepeat=0058
	L7DeltaSec=01
	HashSW=01020304
	Vsoftmaj=0102
	SwSize=010203
	
=head2 Erreurs

Les erreurs sont relevés à travers confess (voir Carp).
	
La valeur renvoyée est une pile d'erreurs.
	
Utilisation:
	
	eval {  appelle de méthode };
	if ($@) {
		Action
	}

=head2 Librairies

Applications de la couche L7 

Applications LAN: commandes, datas, download, 

Applications locales

=over 4

=item L<Telereleve::Application::Command|telereleve-application-command.html>

Application LAN: messages Command, envoi de commandes au DDC via le LAN.

Les réponses reçues sont traitées par l'application LAN Response, voir plus bas.

=item L<Telereleve::Application::Data|telereleve-application-data.html>

Application LAN: messages data reçus du DDC.

Les librairies ci-dessous permettent de traiter les différents types de trames data.

=item L<Telereleve::Application::Data::Helper|telereleve-application-data-helper.html>

Role Moose, Helper pour gérer des données métier.

=item L<Telereleve::Application::Data::Trames|telereleve-application-data-trames.html>

=item L<Telereleve::Application::Data::Trames::Configuration|telereleve-application-data-trames-configuration.html>

=item L<Telereleve::Application::Data::Trames::Pose|telereleve-application-data-trames-pose.html>

=item L<Telereleve::Application::Data::Trames::Releve|telereleve-application-data-trames-releve.html>

=item L<Telereleve::Application::Data::Trames::Supervision|telereleve-application-data-trames-supervision.html>

=item L<Telereleve::Application::Download|telereleve-application-download.html>

Application LAN: messages Download

=item L<Telereleve::Application::Ping|telereleve-application-ping.html>

Application LAN: messages Ping

=item L<Telereleve::Application::Pong|telereleve-application-pong.html>

Application LAN: messages Pong

=item L<Telereleve::Application::Response|telereleve-application-response.html>

Application LAN: messages Response, traitement de la réponse renvoyée par un DDC

=item L<Telereleve::Application::Local|telereleve-application-local.html>

Commandes locales

L<Telereleve::Application::Local::Tools|telereleve-application-local-tools.html>

Méthodes utilitaires associées.

=item L<Telereleve::Application::Local::Fabricants|telereleve-application-local-fabricants.html>

Commandes locales propres à chaque fabricant

=back

Couche L7 et helpers

=over 4

=item L<Telereleve::Application|telereleve-application.html>

Couche L7
	
=item L<Telereleve::Helper|telereleve-helper.html>

=item L<Telereleve::Helper::CheckDatas|telereleve-helper-checkdatas.html>

=item L<Telereleve::Helper::Formats|telereleve-helper-formats.html>	
	
=back

Couches basses

=over 4

=item L<Telereleve::Layer::Liaison|telereleve-layer-liaison.html>

Couche L2, gestion notamment du CRC.

=item L<Telereleve::Layer::Presentation|telereleve-layer-presentation.html>

Couche L6, gestion du cryptage principalement.

=back

Outils pour les scripts de tests.

=over 4

=item L<Telereleve::Testeur|telereleve-testeur.html>

L<Telereleve::Testeur::Local|telereleve-testeur-local.html>: Méthodes utilitaires pour appeler certaines commandes
 
=item L<Telereleve::Testeur::Simple|telereleve-testeur-simple.html>

Méthodes pour les tests NFC
 
=item L<Telereleve::Testeur::LAN|telereleve-testeur-lan.html>

Méthodes pour les tests lan

=item L<Telereleve::Testeur::Moteur|telereleve-testeur-moteur.html>

Méthodes pour les tests moteur

=back

B<Communication>

=over 4

=item L<Telereleve::COM::NFC|telereleve-com-nfc.html>

Communications NFC via le lecteur CR95HF.

=item L<Telereleve::COM::Trx|telereleve-com-trx.html>

Communication radios à travers les modules SmartBrick d'Alciom

=item L<Telereleve::COM::DHCP|telereleve-com-dhcp.html>

Vrai faux serveur DHCP pour tromper le ModemLan

=item L<Telereleve::COM::Modemlan|telereleve-com-modemlan.html>

Communications UDP avec le modemLAN.

=back

Divers

=over 4

=item L<Digest::CRC|digest-crc.html>

=item L<Error::Correction::RS|error-correction-rs.html>

=back
	
=head1 Attributes

=cut

has 'logger' => (
	is => 'rw'
);

has 'interface' => ( 
	is => 'rw',
	default => 'lan',
 );

our $testname;
has 'testname' => (
	is	 => 'rw',
	required => 1,
);

our $log_filename;
has 'log_filename' => (
	is	 => 'rw',
);

has 'integrator_pwd' => (
	is	 => 'rw',
);

has 'master_pwd' => (
	is	 => 'rw',
);

has 'wize_rev' => ( 
	is => 'rw', 
	default => '0.0'  
);

=head2 Application

Applications possibles voir la SFTD Lan.

	INSTPING
	INSTPONG
	DATA
	COMMAND
	RESPONSE
	DOWNLOAD

=cut
has 'application' => (
	is => 'rw',
	predicate => 'has_application_name',
);
 
=head2 mainconfig_file

value: path to conf
 
=cut 
has 'mainconfig_file' => (
	is => 'rw',
	required => 1,
	predicate => 'has_mainconfig_file',
	clearer  => 'clear_mainconfig_file',
	trigger  => \&_load_mainconfig_file,
);

has 'mainconfig' => (
	is => 'rw',
);

has 'appliconfig_file' => (
	is => 'rw',
	predicate => 'has_appliconfig_file',
	clearer  => 'clear_appliconfig_file',
);

has 'appliconfig' => (
	is => 'rw',
);

has 'testconfig' => (
	'is' 	=> 'rw',
	predicate => 'has_testconfig',
	clearer  => 'clear_testconfig',
	builder => '_load_testconfig',	
);

=head2 timestamp_envoi

Après analyse d'une trame, timestamp d'envoi complété

Le timestamp d'envoi des trames est sur 2 octets, octets de poids faible du timestamp courant.

Le timestamp doit être reconsitué à partir des éléments trouvés dans la trame ou de tout autre moyen


=cut
has 'timestamp_envoi' => (
	is => 'rw',
	predicate => 'has_timestamp_envoi',
);

=head1 SUBROUTINES/METHODS

=cut

sub getlogfile {
	my ($path,$filename) = @_;
	my $host = hostname;
	if ($testname) 
	{
            my $gt =  gmtime(time);
            my $dt = $gt->strftime("%Y-%m-%d");
            my $path_dt = $gt->strftime("%Y-%m-%d");
            mkdir($path.$path_dt) unless -e $path.$path_dt;
            $filename = $path_dt."/".$testname . "-$host-$dt.log";
	}

	$log_filename = $path.$filename;
	return $log_filename;
}

=head2 build

paramètre: message sous forme de chaîne héxadécimale ("00010F1A")
	
La méthode effectue deux opérations successives.
	
crypte (couche présentation)
	
puis
	
compose (réalise la trame complète de L2 à L7)

La	trame est accessible via
	
	$obj->message_hexa()
	
	ou
	
	$obj->message_binary();
	
Gestion des erreurs: 

Trapper les erreurs avec eval et récupérer avec $@.
	
La gestion des erreurs relève de la responsabilité de l'utilisateur de la librairie.
	
=cut

sub build {
	my ($self,$message) = @_;
	#crypte les données
	$self->crypte($message);
	#compose la trame de liaison
	if ($self->has_crypted) 
	{
            $self->compose(  $self->crypted );
	} 
	else 
	{
            confess("unknown error during ciphering process");
	}
	return 0;
}

=head2 extract

Extrait les données d'un message au format binaire.
	
La méthode effectue deux actions successives.
	
Décompose la trame reçue
	
puis
	
Décrypte le message
		
Le message décomposé et décrypté est accessible via
	
	$obj->decrypted();

format: chaîne hexa
	
Gestion des erreurs: 

Trapper les erreurs avec eval et récupérer avec $@.
	
La gestion des erreurs relève de la responsabilité de l'utilisateur de la librairie.	
	
=cut

sub extract {
	my ($self,$message) = @_;
	confess("Input message is missing!!") unless $message;
	#decompose la trame de liaison
	my $message_presentation = $self->decompose($message);
	#decrypte le message issu de la trame de liaison
	if ( $message_presentation) {
            $self->decrypte($message_presentation);
	}
	return 0;
}


=head2 check_flux

Vérifie le type de la trame et renvoie le champ C-field.

Utile pour savoir quelle classe utilisée.

Parametres:

	Message au format binaire tel qu'il a été reçu.
	
Retourne:

	C-field

=cut
sub check_flux {
	my ($self,$message) = @_;
	my ($length,$cfield) = unpack("H2 H2",$message);
	return ($cfield);
}

#méthodes privées

sub _load_mainconfig_file {
	my ($self) = @_;
	
	confess("Un fichier de configuration pour la campagne est obligatoire") unless $self->has_mainconfig_file;
	unless (-e $self->mainconfig_file) {
	confess(qq|Il semble que le fichier de configuration est absent: |.$self->mainconfig_file.qq|
Pour un bon fonctionnement de votre script, il faut un fichier de configuration.

Voir la doc qui se trouve dans Telereleve::Application

Voir aussi dans modules/tests qui contient un modele de fichier de configuration.
|  );
	}
	
	my $config;
	eval { 
		$self->mainconfig( Config::Tiny->read( $self->mainconfig_file ) ); 
		die "Erreur dans le fichier de conf [" . $self->mainconfig_file . "] ".$Config::Tiny::errstr if $Config::Tiny::errstr;
		Log::Log4perl->easy_init($ERROR);
		$testname = $self->testname();
		Log::Log4perl::init($self->mainconfig()->{main}->{conflog});
		
	};
	if ($@) {
		confess(qq|[_load_mainconfig_file]\n$@

#########################################

The logs configuration file is missing.

The main configuration file (|.$self->mainconfig_file.qq|) must contains a link to the logs configuration file.

#########################################

|);
	}
	eval {
		if ($self->has_application_name) {
			$self->logger( Log::Log4perl->get_logger(   lc("application.".$self->application) ));
			#initialisation des données de la couche de liaison
			$self->_init_liaison_datas();
			#initialisation des données de la couche de présentation
			$self->_init_presentation_datas();
			############################################################################
			# start modif for wize
			
                        my $wize_rev = '0.0';
			if ($self->mainconfig()->{'main'}->{wize_rev}) 
			{
                            $wize_rev = $self->mainconfig()->{'main'}->{wize_rev};
			}
			$self->_update_wize_rev($wize_rev);
			# end modif for wize
			###########################################################################
			#load config propre à l'application
			#$self->_load_appliconfig_file();
			$self->_init_ddc_datas();
			$self->_init_concentrateur_datas();	
			$self->integrator_pwd(  $self->mainconfig()->{main}->{integrator_pwd}   );
			$self->master_pwd(  $self->mainconfig()->{main}->{master_pwd}   );
		} else {
			$self->logger( Log::Log4perl->get_logger(  "application" ));
		}
	};
	$self->log_filename($log_filename);
	if ($@) {
		confess("[_load_mainconfig_file][init error] $@");
	}
#	$self->logger()->file_switch("tutu.log");
}

=head2 _load_appliconfig_file

Méthode privée, passez votre chemin
	
Charge la conf propre à l'appli

=cut
sub _load_appliconfig_file {
	my ($self) = @_;
	eval {
            die("Le fichier de conf de l'appli n'existe pas, modifier la conf de campagne (param:application_conf). Fichier attendu:" . $self->mainconfig()->{main}->{application_conf} ) unless -e $self->mainconfig()->{main}->{application_conf};
            $self->appliconfig( Config::Tiny->read( $self->mainconfig()->{main}->{application_conf} ) ); 
            #récupération des données propres à une appli
	};
	if ($@) {
            confess("[_load_appliconfig_file] $@" );
	}
}

sub _init_ddc_datas {
	my ($self) = @_;

	$self->set_VERS_HW_TRX(  $self->mainconfig()->{DDC}->{VERS_HW_TRX}   ) if  $self->mainconfig()->{DDC}->{VERS_HW_TRX};
	$self->set_VERS_FW_TRX(  $self->mainconfig()->{DDC}->{VERS_FW_TRX}   ) if $self->mainconfig()->{DDC}->{VERS_FW_TRX};
	$self->set_RADIO_NUMBER(  $self->mainconfig()->{DDC}->{RADIO_NUMBER}   );
	$self->set_RADIO_MANUFACTURER(  $self->mainconfig()->{DDC}->{RADIO_MANUFACTURER}   );
	$self->set_METER_NUMBER(  $self->mainconfig()->{DDC}->{METER_NUMBER}   );
	$self->set_METER_MANUFACTURER(  $self->mainconfig()->{DDC}->{METER_MANUFACTURER}   );
	$self->set_MASTER_PWD(  $self->mainconfig()->{DDC}->{MASTER_PWD}   );	
	$self->set_INTEGRATOR_PWD(  $self->mainconfig()->{DDC}->{INTEGRATOR_PWD}   );
	
	$self->MODULE_TYPE( $self->mainconfig()->{DDC}->{MODULE_TYPE}  ) if $self->mainconfig()->{DDC}->{MODULE_TYPE} ;
	
	$self->PING_RX_DELAY( $self->mainconfig()->{DDC}->{PING_RX_DELAY}  ) if $self->mainconfig()->{DDC}->{PING_RX_DELAY};
	$self->PING_RX_LENGTH( $self->mainconfig()->{DDC}->{PING_RX_LENGTH}  ) if $self->mainconfig()->{DDC}->{PING_RX_LENGTH};

	$self->EXCH_RX_DELAY('01');
	$self->EXCH_RX_DELAY( $self->mainconfig()->{DDC}->{EXCH_RX_DELAY}  ) if $self->mainconfig()->{DDC}->{EXCH_RX_DELAY};
	$self->EXCH_RX_LENGTH('01');
	$self->EXCH_RX_LENGTH( $self->mainconfig()->{DDC}->{EXCH_RX_LENGTH}  ) if $self->mainconfig()->{DDC}->{EXCH_RX_LENGTH};
	$self->EXCH_RESPONSE_DELAY('01');
	$self->EXCH_RESPONSE_DELAY( $self->mainconfig()->{DDC}->{EXCH_RESPONSE_DELAY}  ) if $self->mainconfig()->{DDC}->{EXCH_RESPONSE_DELAY};

        $self->RF_DOWNSTREAM_CHANNEL('78');
	$self->RF_DOWNSTREAM_CHANNEL( $self->mainconfig()->{DDC}->{RF_DOWNSTREAM_CHANNEL}  ) if $self->mainconfig()->{DDC}->{RF_DOWNSTREAM_CHANNEL};
	$self->RF_DOWNSTREAM_MOD('00');
	$self->RF_DOWNSTREAM_MOD( $self->mainconfig()->{DDC}->{RF_DOWNSTREAM_MOD}  ) if $self->mainconfig()->{DDC}->{RF_DOWNSTREAM_MOD};
	
	$self->RF_UPSTREAM_CHANNEL('64');
	$self->RF_UPSTREAM_CHANNEL( $self->mainconfig()->{DDC}->{RF_UPSTREAM_CHANNEL}  ) if $self->mainconfig()->{DDC}->{RF_UPSTREAM_CHANNEL};
	$self->RF_UPSTREAM_MOD('00');
	$self->RF_UPSTREAM_MOD( $self->mainconfig()->{DDC}->{RF_UPSTREAM_MOD}  ) if $self->mainconfig()->{DDC}->{RF_UPSTREAM_MOD};

	$self->L7KeyVal(  $self->mainconfig()->{DDC}->{L7KeyVal}   ) if $self->mainconfig()->{DDC}->{L7KeyVal} ;	
	$self->set_L7SwVersion(  $self->mainconfig()->{DDC}->{L7SwVersion}   ) if $self->mainconfig()->{DDC}->{L7SwVersion};
		
	
	#downloads
	$self->L7DwnldId($self->mainconfig()->{DDC}->{L7DwnldId})  if  $self->mainconfig()->{DDC}->{L7DwnldId};
	$self->L7HwVersion(  $self->mainconfig()->{DDC}->{L7HwVersion}   ) if $self->mainconfig()->{DDC}->{L7HwVersion};
	$self->L7Klog($self->mainconfig()->{DDC}->{L7Klog})  if  $self->mainconfig()->{DDC}->{L7Klog};
	$self->L7SwVersionIni($self->mainconfig()->{DDC}->{L7SwVersionIni})  if  $self->mainconfig()->{DDC}->{L7SwVersionIni};
	$self->L7SwVersionTarget($self->mainconfig()->{DDC}->{L7SwVersionTarget})  if  $self->mainconfig()->{DDC}->{L7SwVersionTarget};
	$self->L7MField($self->mainconfig()->{DDC}->{L7MField})  if  $self->mainconfig()->{DDC}->{L7MField};
	$self->L7DcHwId($self->mainconfig()->{DDC}->{L7DcHwId})  if  $self->mainconfig()->{DDC}->{L7DcHwId};
	
	#lan
	$self->L7BlocksCount($self->mainconfig()->{DDC}->{L7BlocksCount})  if  $self->mainconfig()->{DDC}->{L7BlocksCount};
	#nfc
	$self->BlocksCount($self->mainconfig()->{DDC}->{BlocksCount})  if  $self->mainconfig()->{DDC}->{BlocksCount};
	
	$self->L7ChannelId($self->mainconfig()->{DDC}->{L7ChannelId})  if  $self->mainconfig()->{DDC}->{L7ChannelId};
	$self->L7ModulationId($self->mainconfig()->{DDC}->{L7ModulationId})  if  $self->mainconfig()->{DDC}->{L7ModulationId};
	$self->L7DaysProg($self->mainconfig()->{DDC}->{L7DaysProg})  if  $self->mainconfig()->{DDC}->{L7DaysProg};
	$self->L7DaysRepeat($self->mainconfig()->{DDC}->{L7DaysRepeat})  if  $self->mainconfig()->{DDC}->{L7DaysRepeat};
	$self->L7DeltaSec($self->mainconfig()->{DDC}->{L7DeltaSec})  if  $self->mainconfig()->{DDC}->{L7DeltaSec};
	$self->HashSW($self->mainconfig()->{DDC}->{HashSW})  if  $self->mainconfig()->{DDC}->{HashSW};
	$self->Vsoftmaj($self->mainconfig()->{DDC}->{Vsoftmaj})  if  $self->mainconfig()->{DDC}->{Vsoftmaj};
	$self->SwSize($self->mainconfig()->{DDC}->{SwSize})  if  $self->mainconfig()->{DDC}->{SwSize};	
	#$self->futur($self->mainconfig()->{DDC}->{futur})  if  $self->mainconfig()->{DDC}->{futur};
}

sub _init_concentrateur_datas {
	my ($self) = @_;
	$self->set_L7ConcentId( $self->mainconfig()->{concentrateur}->{L7ConcentId} ) 
                            if $self->mainconfig()->{concentrateur}->{L7ConcentId};
	$self->set_L7ModemId( $self->mainconfig()->{concentrateur}->{L7ModemId} ) 
                            if $self->mainconfig()->{concentrateur}->{L7ModemId};	
	
}

sub _init_liaison_datas {
	my ($self) = @_;
	$self->liaison_application_name($self->application);
	my $level = "liaison";
	
	if ($self->mainconfig()->{$level}->{id_fabricant}) 
	{
            $self->id_fabricant(  $self->mainconfig()->{$level}->{id_fabricant});
	}
	else 
	{
            $self->id_fabricant( 'FFFF' );
	}
	
	if ($self->mainconfig()->{$level}->{id_ddc})
	{
            $self->id_ddc(  $self->mainconfig()->{$level}->{id_ddc});
	}
	else
	{
            $self->id_ddc( '000000000000' );
	}
	
        if ($self->mainconfig()->{$level}->{download_id})
	{
            $self->download_id($self->mainconfig()->{$level}->{download_id});
	}
	else
	{
            $self->download_id('000000');
	}
}

sub _init_presentation_datas {
	my ($self) = @_;
	my $level = "presentation";
	
	if ($self->mainconfig()->{$level}->{keysel}){
            $self->keysel(  $self->mainconfig()->{$level}->{keysel} );
	}
	else {
            $self->keysel( '00' );
	}
	
	$self->wts(  $self->mainconfig()->{$level}->{wts}   ) 
		if defined($self->mainconfig()->{$level}->{wts} ) && $self->mainconfig()->{$level}->{wts} != 0;
	
	$self->timestamp( $self->mainconfig()->{$level}->{timestamp}    ) if $self->mainconfig()->{$level}->{timestamp};

	if($self->mainconfig()->{$level}->{cpt}){
            $self->set_cpt(  $self->mainconfig()->{$level}->{cpt});
	}
	else {
            $self->set_cpt( '0000' );
	}

	# Get kmacs
        $self->_load_kmac($self->mainconfig());
	
	# Get kencs
        $self->_load_kenc($self->mainconfig());
	
	# Get klog
	if ( $self->mainconfig()->{'main'}->{klog}) {
            $self->klog( $self->mainconfig()->{'main'}->{klog} );
	}
	else {
            $self->klog('0000000000000000000000000000000000000000000000000000000000000000' );
	}
	
	# Get kmob
	if ($self->mainconfig()->{'main'}->{kmob}) {
            $self->kmob( $self->mainconfig()->{'main'}->{kmob} );
	}
	else {
            $self->kmob('0000000000000000000000000000000000000000000000000000000000000000');
	}
	
	$self->downbnum(  $self->mainconfig()->{$level}->{downbnum}   );
}


sub _load_kmac {
    my ($self, $keyconfig) = @_;
    $self->set_kmac(0,'00' x 256);
    my $cnt = 0;
    for (my $i = 0; $i <= 255; $i++) 
    {
        if ( $keyconfig->{'main'}->{"kmac$i"} )
        {
            $self->set_kmac($i,$keyconfig->{'main'}->{"kmac$i"});
            $cnt++;
        }
        else 
        {
            $self->set_kmac($i,'0000000000000000000000000000000000000000000000000000000000000000');
        }
    }
    $self->logger->trace($cnt . " kmac set");
    
    if ($keyconfig->{'main'}->{kmac}) 
    {
        # Set the default kmac at index 255
        $self->set_kmac(255, $keyconfig->{'main'}->{kmac} );
        $self->logger->trace("Kmac set to default one");
        $self->kmac( $self->get_kmac(255) ) ;
    }
    else 
    {
        if ( $keyconfig->{'main'}->{Opr} ) 
        {
                $self->logger->trace("Oper Id= " . $keyconfig->{'main'}->{Opr} );
                $self->kmac( $self->get_kmac($keyconfig->{'main'}->{Opr}) ) ;
        }
        else 
        {
                $self->logger->trace("Kmac set to default one");
                $self->kmac( $self->get_kmac(255) ) ;
        }
    }
    
    $self->logger->trace("Current Kmac = " . $self->kmac() );
}

sub _load_kenc {
    my ($self, $keyconfig) = @_;
    
    $self->set_kenc(0,'00' x 16);

    if ($keyconfig->{'main'}->{kenc}) 
    {
        $self->kenc( $keyconfig->{'main'}->{kenc} ) ;
        if ($keyconfig->{'main'}->{kenc} !~ m/^0+$/) 
        {
            $self->add_kenc($keyconfig->{'main'}->{kenc});
        }
    }
    for (my $i = 0; $i <= 15; $i++) 
    {
        if ($keyconfig->{'main'}->{"kenc$i"} )
        {
            $self->set_kenc($i,$keyconfig->{'main'}->{"kenc$i"});
        }
        else {
            $self->set_kenc($i, '0000000000000000000000000000000000000000000000000000000000000000');
        }
    }
    
    #if ($self->has_keysel && $keyconfig->{'main'}->{"kenc".$self->keysel} ) 
    if ($self->has_keysel && ($self->keysel() <= $self->count_kencs() ) ) 
    {
        $self->kenc( $self->get_kenc($self->keysel) ) ;
    }
}


sub _update_wize_rev {
    my ($self, $wize_rev) = @_;
    $self->wize_rev($wize_rev);
    
    my $level;
    $level = "liaison";
    # Set ci_field
    $self->ci_field('b4') if $self->wize_rev() eq '0.0'; 
    $self->ci_field('20') if $self->wize_rev() eq '1.2';
    
    # Set presentation template
    $level = "presentation";
    if ($self->wize_rev() == '0.0')
    {
        $self->_exversion_value(0);
        if ($self->mainconfig()->{$level}->{wts}) {
            $self->wts($self->mainconfig()->{$level}->{wts});
        }
        else {
            $self->wts(1);
        }
        $self->presentation_template->{'exchange'} = "H2 H4",
        $self->presentation_length->{'exchange'} = 11; 
    }
    else { # wize_rev > '0.0'
        $self->wts(1);
        $self->_exversion_value(1) if $self->wize_rev() eq '1.2';
        # Set the L6OperId
        if ($self->mainconfig()->{$level}->{Opr}) {
                $self->Opr($self->mainconfig()->{$level}->{Opr});
        }
        # Set the L6App
        if ($self->mainconfig()->{$level}->{App}) {
                $self->App($self->mainconfig()->{$level}->{App});
        }
        $self->presentation_template->{'exchange'} = "H2 H2 H4 H2";
        $self->presentation_length->{'exchange'} = 13; 
    }
}


sub _load_testconfig {
	my ($self) = @_;
}


=head1 AUTHOR

phv, C<< <philippe.devisme at suez-env.com> >>.

=head1 BUGS

Please report any bugs or feature requests to Ondeo Systems.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Telereleve::Application

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013-2015 Ondeo Systems.

This program is NOT free software; you cannot redistribute it nor modify it.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;

1; # End of Telereleve::Application
