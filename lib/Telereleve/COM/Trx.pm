package Telereleve::COM::Trx;

use Moose;
use feature qw(say);
use Scalar::Util;
use Data::Dumper;

#use Win32::SerialPort;
#use Win32::TieRegistry ( Delimiter=> '/' );

BEGIN { $Package::Alias::BRAVE = 1 }

BEGIN {
    #say($^O);
    if ($^O eq "MSWin32")
    {        
        #require Win32::SerialPort;
        #use Package::Alias SerPort => 'Win32::SerialPort';
        #SerialPort->import();
        #Win32::SerialPort->import(); 
    }
    elsif ($^O eq "linux")
    {
        #require Device::SerialPort;
        use Package::Alias SerPort => 'Device::SerialPort';
        #SerialPort->import();
        #Device::SerialPort->import(); 
    }
    else
    {
        
    }
}


use Time::HiRes qw(usleep);
use Digest::CRC;

use Carp;
use Config::Tiny;
use Exporter qw(import);
our @EXPORT_OK = qw(TRX_MESSAGE_OK 
                    TRX_UNSUPPORTED_SETTING_NUMBER 
                    TRX_UNSUPPORTED_SETTING_VALUE 
                    TRX_NO_MESSAGE 
                    TRX_RX_MESSAGE_LOST 
                    TRX_TX_MESSAGE_LOST 
                    TRX_TRIGGER_MODE_UNSUPPORTED 
                    TRX_TRIGGER_OUTPUT_MODE_UNSUPPORTED 
                    TRX_UNSUPPORTED_ACTION_COMMAND     
                    TRX_CANNOT_EXECUTE_COMMAND
                );
our %EXPORT_TAGS = ( error_code => [ qw(TRX_MESSAGE_OK TRX_NO_MESSAGE 
                    TRX_RX_MESSAGE_LOST TRX_TX_MESSAGE_LOST
                    TRX_TRIGGER_MODE_UNSUPPORTED TRX_TRIGGER_OUTPUT_MODE_UNSUPPORTED 
                    TRX_UNSUPPORTED_ACTION_COMMAND     TRX_CANNOT_EXECUTE_COMMAND
                        ) ], 
                    );

=head1 NAME

Telereleve::COM::Trx - Pilotage des modules smartbrick d'Alciom

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

Emission et réception des trames radio avec les trx Alciom.

    use Telereleve::COM::Trx;
    
    ou
    
    use Telereleve::COM::Trx qw(:error_code);
    
    voir ci-dessous error codes du TRX pour le détail des données exportées.

    my $trx = Telereleve::COM::Trx->new(config => "path/to/config.cfg");
    
config: voir la fin de ce document
    
Erreurs: voir ci-dessous

Les données à envoyer peuvent être codées à la main ou provenir d'une trame construite avec les libs de téléreleve (voir L<Telereleve::Application|telereleve-application.html> et suivants)

Les trames constuites par les librairies sont sous forme de chaîne héxadécimale.

Cette Librairie TRX.pm accepte en entrée des trames sous forme de de chaine ou sous forme de tableau de valeur.


Exemple d'envoi de trame sous forme de tableau de valeur.
    
    if ($trx->open() == 0) {
        $trx->set_v2_config("3A","3A",12 );
        my $msg = [0x46,0x52,0x4a,0x00,0x15,0x03,0x73,0x00,0x03,0xb4,0x10,
                0x00,0x00,0xb3,0xe7,0x9c,0xf1,0x32,0x50,0xc7,0x0d,0x83,0x93];
        
        my $second_timeout = 3; # en secondes
        
        my $delai = 5020; #En milliscondes, à utiliser avec le mode trigger
        #sinon valeur undef
        
        #sinon valeur undef
        my $shift = 1; #non nul, gère l'octet de longueur à l'envoi, alciom est faux

        $trx->conn()->send_message($msg,$second_timeout,$delay,$shift);
    }

Exemple d'envoi de trame sous forme de chaine hexa

    #issu des libs applicatives
    
    $appli->message_hexa();

    if ($trx->open() == 0) {
        $trx->set_v2_config("3A","3A",12 );
        my $msg = [0x46,0x52,0x4a,0x00,0x15,0x03,0x73,0x00,0x03,0xb4,0x10,
                0x00,0x00,0xb3,0xe7,0x9c,0xf1,0x32,0x50,0xc7,0x0d,0x83,0x93];
        my $second_timeout = 3; # en secondes
        
        my $delai = 5020; #ne milliscondes, à utiliser avec le mode trigger
        
        my $shift = 1; #non nul, gère l'octetd e longueur à l'envoi, alciom est faux    
        
        $trx->conn()->send_message([$appli->message_hexa()],$second_timeout,undef,$shift);
    }    
    
Exemples de lecture de trames en réception    
    
    #lire des messages en attente sur le trx
    if ($trx->open() == 0) {
        $trx->set_v2_config("3A","3A",12 );
        $trx->read_waiting_message();
    }
    $trx->close();

Autre exemple:
    
    my $trx = Telereleve::COM::Trx->new(config => "path/to/config.cfg");
    #envoi d'un message
    if ($trx->open() == 0) {
        $trx->set_v2_config("3A","3A",12 );
        $trx->send_message([0x46,0x52,0x4a,0x00,0x15,0x03,0x73,0x00,0x03,0xb4,0x10,
             0x00,0x00,0xb3,0xe7,0x9c,0xf1,0x32,0x50,0xc7,0x0d,0x83,0x93],
             2);
    }
    
    $trx->close();

=head2 Erreurs

En cas de problème, le module se confesse et renvoie une erreur sous forme de hash.

Il est donc fortement recommandé d'utiliser un eval... et de vérifier la sortie du eval évidemment.

Exemple

    eval {
        $trx->send_message([0x00, 0x02, 0x05],$timeout,$delai,$shift);
    };
    if ($@) {
        say $@->{message};
        say $@->{error};
    }

=head2 Réception de trames

exemple

    #!/usr/bin/perl

    use strict;
    use feature qw(say);
    use Data::Dumper;
    use lib "lib";
    use Telereleve::COM::Trx;
    use Telereleve::Application::Data;
    use Telereleve::COM::NFC qw(:Flags :Security);
    use BancRF;

    my $rx_channel = '100';
    my $trx = new Telereleve::COM::Trx(config => 'trx_pxi.cfg');

    BancRF::RF_simple_init($trx->banc_pxi);

    my @ports_disponibles = $trx->list_comport();

    say "Ports disponibles";
    foreach my $port (@ports_disponibles) {
        say "\t$port";
    }

    say "txt Ouverture de la connexion vers le TRX ";
    say "txt port : " . $trx->comport;
    $trx->open();
    $trx->get_identifiant(0x00);
    eval {
        $trx->set_v2_config($rx_channel,'100',12 );
        say "txt channel : " . $trx->get_channel($rx_channel) . " ($rx_channel)\n";
        $trx->set_raw_mode('on' );
     };
    if ($@) {
        say Dumper($@);
        exit(1);
    }

    #commandes radio
    $trx->active_state();


    my $delai = 30;
    my $timeout = $ARGV[0] || 600;
    my $fin_delai = time  + $timeout;

    say "txt Attente de la reponse du DdC (delai: $delai secondes)";

    while ($fin_delai > time) {
        my $messages;
        eval {
            #say "txt ".scalar(localtime(time));

            $messages = $trx->read_waiting_message($delai,1);
            #say "txt ". scalar(localtime(time));
            say $messages->[0];
        };
        if ($@) {
            next;
        }
        if ($messages) {
            eval {
                my $data =  new Telereleve::Application::Data(testname => 'nomtest' , mainconfig_file => 'campagne.cfg');
                $data->extract(pack('H*',$messages->[0]));
            };
            if ($@) {
                say Dumper($@);
            }
        }
    }
    
=head2 Octet de longueur

La version 2014 du module Alciom, enlève l'octet de longueur de la trame radio reçue!!

voir doc Alciom SB-CC1120 user guide, version 1D, paragraphe 8.2.6. Lire entre les lignes que Alciom distinguant du message la longueur et le CRC,
 il les enlève de la trame reçue et les ajoutent aux trames envoyées. C'est implicite!

En attendant une évolution du module, un patch a été ajouté pour remettre l'octet de longueur

De la même façon lors de l'émission d'une trame, il faut enlever l'octet de longueur.    

Pour retirer le patch, chercher le motif: PATCH LENGTH ALCIOM

=head1 ATTRIBUTES

=head2 comport

port utilisé

utilise les données du fichier de conf    

=head2 available_comport

Liste des port séries disponibles.

La liste est récupérée via la méthode: list_comport

=head2 Conf du port serie
        
Conf du port série

    user_msg
    error_msg
    baudrate
    parity
    parity_enable
    databits
    stopbits
    handshake

saved_trxconf: nom du fichier temporaire de la conf du port serie

=head2 ident

ident: identifiant du trx

    obtenir la valeur avec $trx->ident()
    définir la valeur avec $trx->ident(0x01)
    has_ident
    clear_ident

=head2 banc_pxi
        
banc_pxi: utilisation ou non du banc PXI

    has_banc_pxi
    clear_banc_pxi
        
=head2     parameters_read

    array des parametres lus via la méthode read_parameter ou read_all
        
=head2     parameters_read_error

    array des éléments en trop trouvés lors de la rechercehde paramètres
        
=head2    message_raw

    Message brut au format binaire tel qu'il est reçu via une commande smartbrick

=head2     message_decoded
        
Message sans protocole smartbrick

array ref des octets reçus

Exemple:    
    
    $trx->message_decoded([0x01,0x02,0x03]);
        
=head2 _smb_raw_message

Message décodé, mais avant nettoyage des éléments smartbrick.

    Array ref d'octets

=head2     mode, accessible via le fichier de conf

permet de bouchonner la réception ou l'envoi de données

    0: repond ok à tout, aucun connexion
    1: se connecte
    2: envoie ou récupère des données
    3: prod, full opérationnel
            
exemple    

    $trx->mode(3) connexion et envoie de données
    $trx->mode(1) connexion, mais pas d'envoi ou de réception de données
        
    Données pour un trx après identification
        protocol_version
        mod_model_msb.mod_model_lsb
        mod_version
        module_name
            has_module_name
            clear_module_name
        classes: classes supportées (string)
        
=head2 channel

Liste des canaux disponibles

    $trx->get_channel()
    $trx->list_channel()
        renvoie la liste clef/valeur des canaux disponibles
            
         "1a" => 169.406250,
         "1b" => 169.418750,
         "2a" => 169.431250,
         "2b" => 169.443750,
         "3a" => 169.456250,
         "3b" => 169.468750,
         "100" => 169.406250,
         "110" => 169.418750,
         "120" => 169.431250,
         "130" => 169.443750,
         "140" => 169.456250,
         "150" => 169.468750

=head2 rssi

rssi reçu dans les trames (dernier octet de la partie smartbrick)
    
Voir la doc Smartbrick, SB-cc1120 User guide, version 1D, paragraphe 8.2.5

=cut

has 'conn' => (
    is => 'rw',
);

has 'comport' => (
    is => 'rw',
    lazy => 1,
    builder => '_load_comport',
);


has 'available_comport' => (
    is => 'rw',
);


has 'user_msg' => ( is => 'rw', default=>1);
has 'error_msg' => ( is => 'rw', default=>1);
has 'baudrate' => ( is => 'rw', default=>115200);
has 'parity' => ( is => 'rw', default=>"none");
has 'parity_enable' => ( is => 'rw', default=>1);
has 'databits' => ( is => 'rw', default=>8);
has 'stopbits' => ( is => 'rw', default=>1);
has 'handshake' => ( is => 'rw', default=>'none');


has 'saved_trxconf' => (is => 'rw', default=>'trx_conf.cfg');

has '_default_config_file' => (
    is => 'ro',    
    required => 1,
    default => 'trx.cfg',
);

has 'config_file' => (
    is        => 'rw',
    init_arg => 'config',
    lazy      => 1,
    default  => 'trx.cfg',
    predicate => 'has_config_file',
    clearer   => 'clear_config_file',
    trigger   => \&_load_config_file,
);

has 'ident' => (
    is     => 'rw',
    predicate => 'has_ident',
    clearer      => 'clear_ident',
);

has 'banc_pxi' => (
    is     => 'rw',
    predicate => 'has_banc_pxi',
    clearer      => 'clear_banc_pxi',
);

has 'rssi' => (
    is => 'rw',
);


has 'config' => (
    is => 'rw',
);

has 'error' => (
    is => 'rw',
);

has 'parameters_read' => (
    is => 'rw',
);

has 'parameters_read_error' => (
    is => 'rw',
);

has 'message' => (
    is => 'rw',
    predicate => 'has_message',    
    clearer => 'clear_message',    
);

has 'message_raw' => (
    is => 'rw',
    predicate => 'has_message_raw',    
    clearer => 'clear_message_raw',
);

has 'message_decoded' => (
    is => 'rw',
    predicate => 'has_message_decoded',
    clearer => 'clear_message_decoded',
);

#message smb brut avant nettoyage
has '_smb_raw_message' => (
    is => 'rw',    
    clearer => '_clear_smb_raw_message',
);

has 'timeout' => (
    is => 'rw',
    lazy => 1,    
    builder => '_load_timeout',    
);

has 'mode' => (
    is         => 'rw',
#    isa     => 'Num',
    lazy => 1,
    builder => '_load_mode',
    predicate     => 'has_mode', 
);

has 'trig_out_enable' => (
    is => 'rw',
    default=>0
);

#existe pour des raisons de compatibilité d'interface avec le nfc
#n'est pas utilisé sur le trx
has 'uid' => (
    is => 'rw',
);

#données pour un trx
=head2 Infos sur le trx

Il est possible d'obtenir des infos sur le TRX avec la commande

get_identifiant

ou

list_smartbrick

Infos disponibles:

    $trx->protocol_version
    $trx->mod_model_msb
    $trx->mod_model_lsb
    $trx->mod_version
    $trx->classes
    $trx->module_name

=cut
has 'protocol_version' => ( is => 'rw');
has 'mod_model_msb' => ( is => 'rw');
has 'mod_model_lsb' => ( is => 'rw');
has 'mod_version' => ( is => 'rw');
has 'classes' => ( is => 'rw');
has 'module_name' => ( 
    is => 'rw',
    predicate => 'has_module_name',
    clearer => 'clear_module_name',
);

#fifo number of message
has 'rx_fifo_message_count' => (
    is => 'rw',
);

has 'tx_fifo_message_count' => (
    is => 'rw',
);

has 'tx_fifo_message_possible' => (
    is => 'rw',
);
has 'current_trigger_mode' => (
    is => 'rw',
);
has 'current_mode' => (
    is => 'rw',
);

has 'nb_message_sent' => (
    is => 'rw',
);


#smartbrick delimiter
sub SAFP () { 0x7E }
sub FESC () { 0x7D }
sub BANG () { 0x21 }

#some useful constant to check mode 
sub CONNEXION () {1}
sub DATAS     () {2}
sub PROD      () {4}

sub DEACTIVATE         () { 0x00 }
sub ACTIVATE         () { 0x01 }
sub FIFO_RX         () { 0x03 }
sub FIFO_TX          () { 0x02 }
sub NO_FIFO_CLEAR      () { 0x00 }
sub PARAM_TX          () { 0x5A }
sub PARAM_RX          () { 0x55 }

sub ERROR_PARAM         ()  { 0x0700 }
sub ERROR_SERIAL_LINK     ()  { 0x0800 }
sub ERROR_CRC             ()  { 0x0900 }
sub ERROR_DECOD         ()  { 0x0A00 }
sub ERROR_TIMEOUT         ()  { 0x0B00 }
sub ERROR_ANSWER         ()  { 0x0C00 }
sub ERROR_ANSWER_SHORT     ()  { 0x0D00 }
sub ERROR_NO_IDENT         ()  { 0x0E00 }

#trx commandes
sub RX_FREQUENCY_X1      () { 0x01 }
sub RX_FREQUENCY_X1K     () { 0x02 }
sub RX_FREQUENCY_X1M     () { 0x03 }
sub RX_FREQUENCY_DEV     () { 0x04 }
sub RX_SYMBOL_RATE_X1        () { 0x05 }
sub RX_SYMBOL_RATE_X1K       () { 0x06 }
sub RX_MODULATION        () { 0x07 }

sub FREE_RUN_CLOCK       () { 0x08 }

sub TX_POWER             () { 0x09 }
sub TX_FREQUENCY_X1      () { 0x0A }
sub TX_FREQUENCY_X1K     () { 0x0B }
sub TX_FREQUENCY_X1M     () { 0x0C }
sub TX_FREQUENCY_DEV     () { 0x0D }
sub TX_SYMBOL_RATE_X1        () { 0x0E }
sub TX_SYMBOL_RATE_X1K       () { 0x0F }
sub TX_MODULATION        () { 0x10 }

sub LEGACY_MODULATION         () { 0x11 }
sub CRC_DISABLE          () { 0x12 }
sub RAW_MODE             () { 0x12 }

sub TRIGGER_MODE_AUTONOMOUS () { 0x00 }
sub TRIGGER_MODE_EXTERNAL     () { 0x01 }
sub TRIGGER_MODE_REPLY         () { 0x02 }
sub TRIGGER_MODE_ABSOLUTE     () { 0x03 }

sub TRIGGER_OUT_MODE_NOPULSE     () { 0x00 }
sub TRIGGER_OUT_MODE_AFTER_TX     () { 0x01 }
sub TRIGGER_OUT_MODE_BEFORE_RX     () { 0x02 }
sub TRIGGER_OUT_MODE_AFTER_RX     () { 0x03 }

=head1 Error codes du TRX

Réponses du TRX pour chaque messages obtenus du TRX.

    TRX_MESSAGE_OK
        0x00
        
    TRX_NO_MESSAGE    
        0x40 => ['No message available now','Read message','RX FIFO is empty'],
    
    TRX_RX_MESSAGE_LOST 
        0x41 => ['RX message lost','Read message','Indicates that there was no free slot in RX FIFO for the arriving message OR the message received was too long. This message was ignored.'],

    TRX_UNSUPPORTED_SETTING_NUMBER
        0x30 => ['Unsupported setting number','Write Settings','Additional data : offending setting number'],
    
    TRX_UNSUPPORTED_SETTING_VALUE
        0x31 => ['Unsupported setting value','Write Settings','Additional data : offending setting number and value'],    

    TRX_TX_MESSAGE_LOST    
        0x44 => ['TX message rejected','Write Message','Indicates that there is no free slot in TX FIFO for the message asked to transmit OR the message is too long. This message is ignored.'],
    
    TRX_TRIGGER_MODE_UNSUPPORTED
        0x50 => ['Unsupported trigger mode','Set Trigger Mode','Additional data : offending trigger mode'],
        
    TRX_TRIGGER_OUTPUT_MODE_UNSUPPORTED    
        0x51 => ['Unsupported trigger output mode','Set Trigger Mode','Additional data : offending trigger output mode'],
    
    TRX_UNSUPPORTED_ACTION_COMMAND
        0x60 => ['Unsupported action number','Execute Action','Additional data : offending action number'],
        
    TRX_CANNOT_EXECUTE_COMMAND    
        0x70 => ['Cannot execute command','','Module is busy'],
=cut

sub TRX_MESSAGE_OK             () { 0x00 }
sub TRX_UNSUPPORTED_SETTING_NUMBER     () { 0x30 }
sub TRX_UNSUPPORTED_SETTING_VALUE     () { 0x31 }
sub TRX_NO_MESSAGE             () { 0x40 }
sub TRX_RX_MESSAGE_LOST         () { 0x41 }
sub TRX_TX_MESSAGE_LOST         () { 0x44 }
sub TRX_TRIGGER_MODE_UNSUPPORTED     () { 0x50 }
sub TRX_TRIGGER_OUTPUT_MODE_UNSUPPORTED () { 0x51 }
sub TRX_UNSUPPORTED_ACTION_COMMAND     () { 0x60 }
sub TRX_CANNOT_EXECUTE_COMMAND         () { 0x70 }


=head2 channel

Tableau (hash) des canaux avec l'identifiant comme clef.

Methodes associées:

    my $canal = $trx->get_channel('100');

    
    for my $pair ( $trx->list_channel ) {
      print "$pair->[0] = $pair->[1]\n";
    }
    
=cut
has 'channel' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {
     "1a" => 169.406250,
     "1b" => 169.418750,
     "2a" => 169.431250,
     "2b" => 169.443750,
     "3a" => 169.456250,
     "3b" => 169.468750,
     100 => 169.406250,
     110 => 169.418750,
     120 => 169.431250,
     130 => 169.443750,
     140 => 169.456250,
     150 => 169.468750     
  } },
  handles   => {
      get_channel     => 'get',
      list_channel         => 'kv',
  },
);

=head2 modulation

    Paramètres de modulation disponibles

      FSK
      GFSK
      ASK/OOK
      4FSK
      4GFSK
      MSK
      GMSK

=cut
has 'modulation' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {
      "FSK"     => 0,
      "GFSK"    => 1,
      "ASK/OOK" => 2,
      "4FSK"    => 3,
      "4GFSK"   => 4,
      "MSK"     => 5,
      "GMSK"    => 6
  } },
  handles   => {
      get_modulation     => 'get',
  },
);

=head2 on_off

Méthode
    
    get_on_off("on" ou "off")
        

=cut
has 'on_off' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {
      "on" => 1,
      "off"=> 0
  } },
  handles   => {
      get_on_off     => 'get',
  },
);

=head2 parameters

Paramètres internes au trx disponibles
    
Utilisé en général lors d'une lecture de paramètre sur le trx avec les commandes
    
    my ($params,$errors) = $trx->read_all()
    ou
    my $param = $trx->read_parameter('TX_POWER');

    RX_FREQUENCY_X1 => 0x01,
    RX_FREQUENCY_X1K => 0x02,
    RX_FREQUENCY_X1M => 0x03,
    RX_FREQUENCY_DEV => 0x04,
    RX_SYMBOL_RATE_X1 => 0x05,
    RX_SYMBOL_RATE_X1K => 0x06,
    RX_MODULATION => 0x07,
    FREE_RUN_CLOCK => 0x08,
    TX_POWER => 0x09,
    TX_FREQUENCY_X1 => 0x0A,
    TX_FREQUENCY_X1K => 0x0B,
    TX_FREQUENCY_X1M => 0x0C,
    TX_FREQUENCY_DEV => 0x0D,
    TX_SYMBOL_RATE_X1 => 0x0E,
    TX_SYMBOL_RATE_X1K => 0x0F,
    TX_MODULATION => 0x10,
    LEGACY_MODULATION => 0x11,
#    CRC_DISABLE => 0x12,
    RAW_MODE => 0x12,

pour obtenir la valeur 

    $trx->get_parameter('TX_FREQUENCY_X1M');

    $trx->get_parameter_by_id(0x01);
    
=cut
has 'parameters' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {
    RX_FREQUENCY_X1 => 0x01,
    RX_FREQUENCY_X1K => 0x02,
    RX_FREQUENCY_X1M => 0x03,
    RX_FREQUENCY_DEV => 0x04,
    RX_SYMBOL_RATE_X1 => 0x05,
    RX_SYMBOL_RATE_X1K => 0x06,
    RX_MODULATION => 0x07,
    FREE_RUN_CLOCK => 0x08,
    TX_POWER => 0x09,
    TX_FREQUENCY_X1 => 0x0A,
    TX_FREQUENCY_X1K => 0x0B,
    TX_FREQUENCY_X1M => 0x0C,
    TX_FREQUENCY_DEV => 0x0D,
    TX_SYMBOL_RATE_X1 => 0x0E,
    TX_SYMBOL_RATE_X1K => 0x0F,
    TX_MODULATION => 0x10,
    LEGACY_MODULATION => 0x11,
    RAW_MODE => 0x12,
  } },
  handles   => {
      get_parameter     => 'get',
  },
);

has 'parameters_by_id' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {
        0x01 => 'RX_FREQUENCY_X1',
        0x02 => 'RX_FREQUENCY_X1K',
        0x03 => 'RX_FREQUENCY_X1M',
        0x04 => 'RX_FREQUENCY_DEV',
        0x05 => 'RX_SYMBOL_RATE_X1',
        0x06 => 'RX_SYMBOL_RATE_X1K',
        0x07 => 'RX_MODULATION',
        0x08 => 'FREE_RUN_CLOCK',
        0x09 => 'TX_POWER',
        0x0A => 'TX_FREQUENCY_X1',
        0x0B => 'TX_FREQUENCY_X1K',
        0x0C => 'TX_FREQUENCY_X1M',
        0x0D => 'TX_FREQUENCY_DEV',
        0x0E => 'TX_SYMBOL_RATE_X1',
        0x0F => 'TX_SYMBOL_RATE_X1K',
        0x10 => 'TX_MODULATION',
        0x11 => 'LEGACY_MODULATION',
        0x12 => 'RAW_MODE',
  } },
  handles   => {
      get_parameter_by_id     => 'get',
  },
);

has 'error_messages' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {
        0x30 => ['Unsupported setting number','Write Settings','Additional data : offending setting number'],
        0x31 => ['Unsupported setting value','Write Settings','Additional data : offending setting number and value'],
        0x40 => ['No message available now','Read message','RX FIFO is empty'],
        0x41 => ['RX message lost','Read message','Indicates that there was no free slot in RX FIFO for the arriving message OR the message received was too long. This message was ignored.'],
        0x44 => ['TX message rejected','Write Message','Indicates that there is no free slot in TX FIFO for the message asked to transmit OR the message is too long. This message is ignored.'],
        0x50 => ['Unsupported trigger mode','Set Trigger Mode','Additional data : offending trigger mode'],
        0x51 => ['Unsupported trigger output mode','Set Trigger Mode','Additional data : offending trigger output mode'],
        0x60 => ['Unsupported action number','Execute Action','Additional data : offending action number'],
        0x70 => ['Cannot execute command','','Module is busy'],
   } },
  handles   => {
      get_error_message     => 'get',
  },
); 

has 'generic_error_messages' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {
    0x01 => "No module at this address Byte 1 : Address of the last module found in the tree is sent after the error code",
    0x02 => "Unsupported message type None",
    0x03 => "Unsupported command class None Command class doesn't match with the module class and is not the generic 0x00 class",
    0x04 => "Unsupported command code None This specific command is not supported by the module for this requested class",
    0x05 => "Wrong command length Byte 1 MSB of the command length Byte 2 : LSB of the command length",
    0x06 => "Illegal parameter value in command Byte 1 : Position of the offending parameter",
    0x07 => "Illegal command in that context Module dependent",
    0x09 => "Message too long When the received message is longer than the buffer size",
    0x0A => "Transmission ended before complete reception",
    0x0B => "CRC error",
    0x1E => "Critical error, module resetted Module dependant A critical error has happened either during the execution of the command or before receiving the command. The node has resetted itself and will access next commands however more messages may have been lost",
   } },
  handles   => {
      get_generic_error_message     => 'get',
  },
); 

has 'status_messages' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {
        0x00    => "none",
        0x01    => "module busy",
        0x02    => "module correctly configured",
        0x04    => "module armed",
        0x08    => "module triggered",
        0x10    => "specific 4",
        0x20    => "specific 5", 
        0x40    => "specific 6", 
        0x80    => "Module in error"
   } },
  handles   => {
      get_status_message     => 'get',
      list_status_message      => 'kv',
  },
); 

=head2 Paramètres de configuration

Ces paramètres internes à la librairie sont initialisés par le fichier conf
et peuvent être modifiés à volonté.

    rx_frequency_deviation
    tx_frequency_deviation
    rx_symbol_rate
    tx_symbol_rate
    rx_modulation
    tx_modulation
    rx_channel
    tx_channel
    legacy_modulation
    tx_power
#    crc_disable
    
Ils sont utilisés par la méthode set_v2_config.
    
=cut

has 'rx_frequency_deviation' => ( 
    is => 'rw',
);

has 'tx_frequency_deviation' => ( 
    is => 'rw',
);

has 'rx_symbol_rate' => ( 
    is => 'rw',
);

has 'tx_symbol_rate' => ( 
    is => 'rw',
);

has 'rx_modulation' => ( 
    is => 'rw',
);

has 'tx_modulation' => ( 
    is => 'rw',
);

has 'rx_channel' => (
    is => 'rw',
);
has 'tx_channel' => (
    is => 'rw',
);

has 'legacy_modulation' => ( 
    is => 'rw',
);

has 'tx_power' => ( 
    is => 'rw',
);

has 'crc_disable' => ( 
    is => 'rw',
);

has 'raw_mode' => ( 
    is => 'rw',
);

has 'raw_mode_cfg' => ( 
    is => 'rw',
);

=head2 identifiants

Liste des identifiants fournis pour vérification

=cut

has 'identifiants' => (
    is => 'rw',
);


=head1 SUBROUTINES/METHODS


=head2 _display_comport

liste les ports séries disponibles.

    parametre
      aucun
    
    
=cut

sub _display_comport
{
    if ($^O eq "MSWin32")
    {  
        my ($string,$major,$minor,$build,$id) = Win32::GetOSVersion();
    
        # Win31 ...
        die "$string is nor supported by this script\n" if ($id == 0);
    
        #print "$VERSION\n";
    
        print "The declared serial port are : \n";
        if ($id == 2) # NT plateforms ...
        {
          my $hkey_local_machine = new Win32::TieRegistry  "LMachine" ;
          my $subKey = $hkey_local_machine->Open("Hardware/DEVICEMAP/SERIALCOMM",{Delimiter => "/"}) or die;
    
          #my @ports = $subKey->ValueNames;
    
          my %ports;
    
          foreach ($subKey->ValueNames)
          {
              $ports { $subKey->GetValue($_) }  = $_ ;
          }
    
          my @coms = (sort keys %ports);
          #my $OUT  = $term->OUT || "STDOUT";
          my $com_selected = 0;
    
          for (my $i=0;$i <= $#coms;$i++)
          {
              $_ = $coms[$i];
              print " - ".($i + 1)." - ".$_." ".$ports{$_}."\n";
          }
        }
        else
        {
            print "feature not implemented yet\n";
            return 0;
        }
    }
    else
    {
        print "feature not implemented yet\n";
        return 1;
    }
    return 1;
}


=head2 open

Etonnament, ouvre une connexion vers un trx

    parametre
        1 pour no scansmartbrick
            A utiliser avec drupence pour le debug, le scan permet de définir l'identifiant du trx
    
    
    
=cut

sub open {
    my ($self,$noscan) = @_;
    if ($self->mode() & CONNEXION) {
        my $connexion = SerPort->new ($self->comport())
                or confess({error => ERROR_SERIAL_LINK, 
                    message => 
                "[open] Unable to open the port [". $self->comport() ."] $@"});
        $self->conn($connexion);
        $self->_configure();
        $self->scan_smartbrick() unless defined $noscan;
    }
    return 0;
}

=head2 send_message

Envoie un message au trx qui se débrouille pour l'envoyer dans les airs.

Action réalisées

    check_fifo
    clear_fifo_tx

Reply mode
    
    Si le trigger_mode est en mode 2 donc actif, laisse la réception active

    Trigger mode 2 correspond au reply mode

    Sinon ferme la réception.    
    
Paramètres:

    Message: 
            reférence de tableau de valeurs
            ou
            référence d'une chaine hexa
            
    timeout (integer) en secondes (undef ou entier, valeur par défaut 1)
    
    delay (integer) en milliseconds, entre 0 et 65535
        lié  l'usage du trigger
        
exemple:
    
    $trx->send_message(
        [0x46,0x52,0x4a,0x00,0x15,0x03,0x73,0x00,0x03,0xb4,0x10,
         0x00,0x00,0xb3,0xe7,0x9c,0xf1,0x32,0x50,0xc7,0x0d,0x83,0x93],
         2,
         undef
    );
        
ou

    $trx->send_message(
        ['46524A001503730003B4100000B3E79CF13250C70D8393'],
         2,
         undef
    );
    
Retourne

    0 si tout va bien
    
Autre exemple:
    
    $trx->send_message(
                    [0x21, 0x58, 0x54],
                    undef,
                    3
                    );
    
Exemple avec reply mode actif

Ouverture de la connexion

    eval {
        $trx->open();
        $trx->get_identifiant(0x00);
        $trx()->set_v2_config(hex($self->rx()),hex($self->tx()),12 );
        $trx()->set_raw_mode('on');
        
        #initialisation du mode trigger
        $trx()->set_trigger_mode(02,00);
        
    };
    my $delay_en_millisecondes_avant_reponse = 5016;
    $trx->send_message(
                    [0x21, 0x58, 0x54],
                    3,
                    $delay_en_millisecondes_avant_reponse
                    );
    
se confesse en cas d'erreur, donc utiliser eval peut être une idée intéressante pour avoir
une idée de l'ampleur des dégats.


=cut
sub send_message {
    my ($self,$message,$second_timeout,$delay)=@_;
    $delay ||= 0;
    $second_timeout ||= 1;
    $self->check_fifo();
    $self->clear_fifo_tx();
    #$self->clear_fifo_rx();
    $self->write_datas($message,$delay);
    my $timeout = $self->_get_tick_count() + ($second_timeout*1000); # set timout seconds
    $self->active_state();
    do {
        $self->check_fifo();
        usleep(10000);
    } while(($self->tx_fifo_message_count()!=0) && ($self->_get_tick_count() < $timeout));
    $self->current_trigger_mode() == 2 ? $self->active_state() : $self->deactive_state();
    return 0;
}

sub send_trigger_message {
    my ($self,$message,$second_timeout,$delay)=@_;
    $self->set_trigger_mode(02,00);
    $delay ||= 0;
    $second_timeout ||= 1;
    $self->check_fifo();
    $self->clear_fifo_tx();
    $self->write_datas($message,$delay);
    my $timeout = $self->_get_tick_count() + ($second_timeout*1000); # set timout seconds
    $self->active_state();
    do {
        $self->check_fifo();
        usleep(10000);
    } while(($self->tx_fifo_message_count()!=0) && ($self->_get_tick_count() < $timeout));
    return 0;
}

=head2 send_message_fast

Envoie un message au trx qui se débrouille pour l'envoyer dans les airs

Même chose que send_message, mais sans timeout, sans vérification, brut
    
Paramètres:

        Message: reférence de tableau de valeurs
        delay (integer) en milliseconds, entre 0 et 65535
    
Exemple:
    
        $trx->send_message_fast(
            [0x46,0x52,0x4a,0x00,0x15,0x03,0x73,0x00,0x03,0xb4,0x10,
             0x00,0x00,0xb3,0xe7,0x9c,0xf1,0x32,0x50,0xc7,0x0d,0x83,0x93],
             undef
        );
        $trx->send_message_fast(
            ['46524A'],
             undef
        );        
    
Retourne:

    0 si tout va bien
    
se confesse en cas d'erreur, donc utiliser eval peut être une idée intéressante pour avoir
une idée de l'ampleur des dégats.


=cut
sub send_message_fast {
    my ($self,$message,$delay)=@_;    
    $delay ||= 0;
    $self->deactive_state();
    $self->write_datas($message,$delay);
    $self->active_state();
    return 0;
}

=head2 read_waiting_message

Attend des messages à lire
    
parametre

    int: Delai d'attente en secondes
    
    $return_string_hexa: valeur non nulle pour recevoir la réponse sous forme de chaîne hexa
    
Retourne:
    
    array ref ***des*** messages réceptionnés, tableau de valeurs

    genre
    
    Avec $return_string_hexa non nul
    
    [
        ['6d6573736167652031'],    #reponse 01
        ['6d6573736167652032'],    #reponse 02
    ]
    
    sinon
    
    [
        [0x6d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0x20, 0x31],    #reponse 01
        [0x6d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0x20, 0x32],    #reponse 02
    ]    

=cut
sub read_waiting_message {
    my ($self,$second_timeout,$return_string_hexa) = @_;
    $self->clear_message_raw();
    $second_timeout ||= 1;
    my $status = $self->get_module_status();
    #$self->deactive_state() if $status->{"ActiveMode"} ==  ACTIVATE;
    #$self->clear_fifo(NO_FIFO_CLEAR);
    $self->active_state();
    my $timeout = $self->_get_tick_count() + ($second_timeout*1000); # set timout seconds
    do {
        $self->check_fifo();
        usleep(10000);
    } while ( $self->rx_fifo_message_count() == 0 && $self->_get_tick_count() < $timeout );
    $self->deactive_state() if $status->{"ActiveMode"} ==  DEACTIVATE;
    #On peut recevoir plusieurs messages différents dee sources différentes
    #donc renvoie une liste de messages correspond à un ensemble smb séparé par 26 (decimal)
    my @messages;
    for (my $i =0; $i < $self->rx_fifo_message_count(); $i++ ) {
        push( @messages, $self->read_fifo() );
    }
    #clean message
    my $tmp_cleaned_messages = $self->clean_messages(\@messages);
    my $cleaned_messages = [];
    foreach my $cleaned ( @{ $tmp_cleaned_messages }) {
        push(@$cleaned_messages, ( join '' , map { sprintf("%02X",$_) } @$cleaned) );
    }
    if ($return_string_hexa) {
        return $cleaned_messages;
    } else {
        return $tmp_cleaned_messages;
    }
}

sub read_response_waiting_message {
    my ($self,$second_timeout) = @_;
    $self->clear_message_raw();
    $second_timeout ||= 1;
    my $status = $self->get_module_status();
    #$self->deactive_state() if $status->{"ActiveMode"} ==  ACTIVATE;
    #$self->clear_fifo(NO_FIFO_CLEAR);
    $self->active_state();
    my $timeout = $self->_get_tick_count() + ($second_timeout*1000); # set timout seconds
    do {
        $self->check_fifo();
        usleep(10000);
    } while ( $self->rx_fifo_message_count() == 0 && $self->_get_tick_count() < $timeout );
    $self->deactive_state() if $status->{"ActiveMode"} ==  DEACTIVATE;
    #On peut recevoir plusieurs messages différents de sources différentes
    #donc renvoie une liste de messages correspond à un ensemble smb séparé par 26 (decimal)
    my @messages;
    for (my $i =0; $i < $self->rx_fifo_message_count(); $i++ ) 
    {
        my $response = new Trx::Response();
        $response->raw_frame($self->read_fifo());
        $response->clean_message($self->raw_mode);
        push( @messages, $response );
    }
    return @messages;
}

=head2 read_messages

Fait la même chose que read_waiting_message, mais avec une liste de messages sosu forme d'objet TRX::Response



=cut
sub read_messages {
    my ($self,$second_timeout) = @_;
    $self->clear_message_raw();
    $second_timeout ||= 1;
    my $status = $self->get_module_status();
    #$self->deactive_state() if $status->{"ActiveMode"} ==  ACTIVATE;
    #$self->clear_fifo(NO_FIFO_CLEAR);
    $self->active_state();
    my $timeout = $self->_get_tick_count() + ($second_timeout*1000); # set timout seconds
    do {
        $self->check_fifo();
        usleep(10000);
    } while ( $self->rx_fifo_message_count() == 0 && $self->_get_tick_count() < $timeout );
    $self->deactive_state() if $status->{"ActiveMode"} ==  DEACTIVATE;
    my @messages;
    for (my $i =0; $i < $self->rx_fifo_message_count(); $i++ ) {
        my $response = new Trx::Response();
        $response->raw_frame($self->read_fifo());
        $response->clean_message($self->raw_mode);
        push( @messages, $response );
    }
    return \@messages;
}

=head2 read_message

Lit un message de la FIFO.    

Paramètres:

    second_timeout: entier

Retourne:

    un objet TRX::Response

=cut
sub read_message {
    my ($self,$second_timeout) = @_;
    $self->clear_message_raw();
    $second_timeout ||= 1;
    my $status = $self->get_module_status();
    #$self->deactive_state() if $status->{"ActiveMode"} ==  ACTIVATE;
    #$self->clear_fifo(NO_FIFO_CLEAR);
    $self->active_state();
    my $timeout = $self->_get_tick_count() + ($second_timeout*1000); # set timout seconds
    do {
        $self->check_fifo();
        usleep(10000);
    } while ( $self->rx_fifo_message_count() == 0 && $self->_get_tick_count() < $timeout );
    $self->deactive_state() if $status->{"ActiveMode"} ==  DEACTIVATE;
    #if ($self->rx_fifo_message_count() == 0) 
    #{
    #    say("self->rx_fifo_message_count() = 0");
    #}
    my $response = new Trx::Response();
    $response->raw_frame($self->read_fifo());
    $response->clean_message($self->raw_mode);
    return $response;
}

=head2 read_all

Lit les paramètres du trx
    
voir liste des paramètres disponibles dans l'attribut parameters
    
Retourne:

    un array ref des valeurs obtenues
    my ($params,$errors) = $trx->read_all();
    $params est un hashref
    $params = {
        RX_FREQUENCY_X1 => 'valeur lue'
    }
    
Infos aussi disponibles

    $trx->parameters_read()
        Renvoie une référence de hash des paramètres lus
    
    $trx->parameters_read_error()
        Renvoie une référence de tableau des paramètres en trop
        
=cut
sub read_all {
    my ($self) = @_;
    $self->parameters_read({});
    $self->parameters_read_error([]);    
    my $msg =[
        0x80, $self->ident, 0xCA, 0x30, 0x09, RX_FREQUENCY_X1, RX_FREQUENCY_X1K, RX_FREQUENCY_X1M,
        RX_FREQUENCY_DEV, RX_SYMBOL_RATE_X1, RX_SYMBOL_RATE_X1K, RX_MODULATION, FREE_RUN_CLOCK, TX_POWER,
        TX_FREQUENCY_X1, TX_FREQUENCY_X1K, TX_FREQUENCY_X1M, TX_FREQUENCY_DEV, TX_SYMBOL_RATE_X1,
        TX_SYMBOL_RATE_X1K, TX_MODULATION, LEGACY_MODULATION, RAW_MODE    
        ];
    my $encoded = $self->_encode_smb($msg);
    $self->send( $encoded );
    $self->receive();
    $self->_decode_smb();
    my $received = $self->message_decoded();
    my %res;
    my @errors;
    for (my $i = 6; $i < scalar(@$received) - 2; $i += 3 ) 
    {
        if ( $self->get_parameter_by_id($received->[$i]) ) 
        {
                    $res{ $self->get_parameter_by_id($received->[$i]) } = 
                            ($received->[$i+1] << 8 ) +($received->[$i+2]);
        }
        else 
        {
                    push(@errors, $received->[$i]);
        }
    }
    $self->parameters_read(\%res);
    $self->parameters_read_error(\@errors);
    return ( $self->parameters_read() , $self->parameters_read_error());
}

=head2 read_parameter

Lit un paramètre du trx
    
Paramètre: 

    param_name
    
Voir liste des paramètres disponibles dans l'attribut parameters
    
Retourne:

    la valeur du paramètre lu
    
    my $value = $trx->read_parameter('RX_FREQUENCY_X1');
    
    Info aussi disponible via parameters_read
    my $paramread = $trx->parameters_read();
    print $paramread->{'RX_FREQUENCY_X1'};
        Renvoie une référence de hash des paramètres lus
    
    $trx->parameters_read_error()
        Renvoie une réference de tableau des paramètres en trop

        
=cut
sub read_parameter {
    my ($self,$param_name) = @_;
    $self->parameters_read({});
    $self->parameters_read_error([]);        
    my $msg =[
        0x80, $self->ident, 0xCA, 0x30, 0x09 ,$self->get_parameter($param_name)    
        ];
    my $encoded = $self->_encode_smb($msg);
    $self->send( $encoded );
    $self->receive();
    $self->_decode_smb();
    my $received = $self->message_decoded();
    my %res;
    my @errors;
    for (my $i = 6; $i < scalar(@$received) - 2; $i += 3 ) 
    {
        if ( $self->get_parameter_by_id($received->[$i]) ) 
        {
            $res{ $self->get_parameter_by_id($received->[$i]) } = 
            ($received->[$i+1] << 8) + ($received->[$i+2]);
        } else {
            push(@errors, $received->[$i]);
        }
    }
    $self->parameters_read(\%res);
    $self->parameters_read_error(\@errors);    
    return ( wantarray ? values %res : (values %res)[0] );    
}

=head2 scan_smartbrick

Pour une liste d'identifiants, vérifie si un trx répond, teste dans l'ordre et s'arrête au premier trx qui répond correctement.
    
Si un identifiant est disponible dans $trx->get_ident, celui-ci est testé en premier.
    
Paramètre:

    array ref list d'identifiant hexa décimal
        
En cas d'absence de liste ou d'absence d'identifiant trx: confession

Si un identifiant a été trouvé, il est accessible via get_ident
    
    Exemple:
    
    $trx->scan_smartbrick([0x00, 0x01, 0x02,0x03]);
    $trx->get_ident()

=cut
sub scan_smartbrick {
    my ($self,$list) = @_;
    $list =  $self->identifiants() if !$list || @$list == 0;
    unshift(@$list, $self->ident) if $self->has_ident();
    confess({error => ERROR_NO_IDENT, message => "[scan_smartbrick] pas d'identifiant smartbrick"}) if !$list || ( defined($list) && @$list == 0);
    for (my $i=0;$i < @$list ;$i++) {
        eval { $self->get_identifiant($list->[$i]) };
        next if $@;
        $self->ident($list->[$i]);
        last if defined($self->has_ident()) || $self->has_ident() >= 0;
    }
    confess({error => ERROR_NO_IDENT, message => "[scan_smartbrick] pas d'identifiant smartbrick"}) if !$self->has_ident();
    return 0;
}

=head2 list_smartbrick

Pour une liste d'identifiants, vérifie si un trx répond, teste dans l'ordre et s'arrête au premier trx qui répond correctement.
    
Si un identifiant est disponible dans $trx->get_ident, celui-ci est testé en premier.
    
Paramètres:

        array ref list d'identifiant hexa décimal
        display: 1 ou undef
            Permet d'afficher les éléments d'identifications
Retourne

        Array des identifiants trouvés

Si la liste fournie est vide: confession.
        
=cut
sub list_smartbrick {
    my ($self,$list,$display) = @_;
    $list =  $self->identifiants() if !$list || @$list == 0;
    unshift(@$list, $self->ident) if $self->has_ident();
    confess({error => ERROR_NO_IDENT, message => "[list_smartbrick] pas d'identifiant smartbrick"}) if @$list == 0;
    my @list_ident;
    #my $old_ident = $self->ident();
    my %done = ();
    for (my $i=0;$i < @$list ;$i++) {
        next if $done{$list->[$i]};
        eval { $self->get_identifiant($list->[$i]) };
        next if $@;
        push( @list_ident, $list->[$i]);
        if ($display && $display == 1) {
            say "identifiant        : " . sprintf("%#X", $list->[$i] );
            say "Version protocole    : " .$self->protocol_version();
            say "ident module code    : " . $self->mod_model_msb() . "." . $self->mod_model_lsb();
            say "Version module        : " . $self->mod_version();
            say "Nom du module        : " . $self->module_name();
            say "Classes supportées : " . $self->classes();
        }
        $done{$list->[$i]} = 1;
        #$self->clear_ident();
    }
    #$self->ident($old_ident);
    return @list_ident;
}

=head2 reset_module

Fait risette au module.

=cut

sub reset_module {
    my ($self) = @_;
    $self->clear_message_raw();
    $self->clear_message_decoded();
    $self->clear_message();
    $self->clear_module_name();    
    confess({error => ERROR_NO_IDENT, message =>"[reset_module] pas d'identifiant trx, veuillez scan_smartbricker avant toute chose"}) unless $self->has_ident();
    my $encoded = $self->_encode_smb([0x80, $self->ident() , 0x00, 0x00, 0x02]);
    $self->send( $encoded );
    $self->receive();
    $self->_decode_smb();
    my $received = $self->message_decoded();
    if( defined($received->[5]) ) {
        if(($received->[5]==0x00)||($received->[5]==0x70)) {
          return $received->[6];
        } else {
          confess({ 
                error =>  sprintf( "%02X",$received->[5] ) , 
                message => "[reset_module] : erreur dans le message du trx [@$received] "
                } );
        }
    }    
}

=head2 set_rx_wm_modulation

Changement de la modulation pour la réception

Paramètre:

        modulation: 00h 01h 02h

=cut
sub set_rx_wm_modulation {
    my ($self,$new_modulation) = @_;
    my ($symbol_rate,$freq_deviation,$modulation);
    #modulation 2400
    if (hex($new_modulation) == 0) {
            $symbol_rate = 2400;
            $freq_deviation = 2400;
            $modulation = "GFSK";
    #modulation 4800    
    } elsif (hex($new_modulation) == 1) {
            $symbol_rate = 4800;
            $freq_deviation = 2400;
            $modulation = "GFSK";
    #modulation HSPEED    
    } elsif (hex($new_modulation) == 2) {
            $symbol_rate = 3200; # bitrate = 6400bps
            $freq_deviation = 3200;
            $modulation = "4GFSK";
    } else {
            return 0;
    }
    $self->set_rx_symbol_rate($symbol_rate);
    $self->set_rx_frequency_deviation($freq_deviation);
    $self->set_rx_modulation($modulation);
    return 0;
}

=head2 set_tx_wm_modulation

Changement de la modulation pour la transmission

Paramètre:

        modulation: 00h 01h 02h

=cut

sub set_tx_wm_modulation {
    my ($self,$new_modulation) = @_;
    my ($symbol_rate,$freq_deviation,$modulation);
    #modulation 2400
    if (hex($new_modulation) == 0) {
            $symbol_rate = 2400;
            $freq_deviation = 2400;
            $modulation = "GFSK";
    #modulation 4800    
    } elsif (hex($new_modulation) == 1) {
            $symbol_rate = 4800;
            $freq_deviation = 2400;
            $modulation = "GFSK";
    #modulation HSPEED
    } elsif (hex($new_modulation) == 2) {
            $symbol_rate = 3200; # bitrate = 6400bps
            $freq_deviation = 3200;
            $modulation = "4GFSK";
    } else {
            return 0;
    }
    $self->set_tx_symbol_rate($symbol_rate);
    $self->set_tx_frequency_deviation($freq_deviation);
    $self->set_tx_modulation($modulation);
    return 0;
}


=head2 get_module_status

retourne le statut du module

=cut

sub get_module_status {
    my ($self) = @_;
    $self->clear_message_raw();
    $self->clear_message_decoded();
    $self->clear_message();
    $self->clear_module_name();    
    confess({error => ERROR_NO_IDENT, message =>"[get_module_status] pas d'identifiant trx, veuillez scan_smartbricker avant toute chose"}) unless $self->has_ident();
    my $encoded = $self->_encode_smb([0x80, $self->ident() , 0x00, 0x00, 0x03]);
    $self->send( $encoded );
    $self->receive();
    $self->_decode_smb();
    my $received = $self->message_decoded();
    
    if( defined($received->[5]) ) {
        if(($received->[5]==0x00)||($received->[5]==0x70)) {
            my $i=-1;
            return {
                    "message"  => join( " ", 
                                    map{ $i++; "[$i:" .$self->get_status_message($_ << $i)."]" }
                                    split //, unpack "b8"  , pack("H*",$received->[6])
                                    ),
                    'RXMsgCount' => hex($received->[10]),
                    'TXMsgCount' => hex($received->[11]),
                    'TXMsgAvailable' => hex($received->[12]),
                    'TriggerMode' => sprintf("%02X",$received->[13]),
                    'ActiveMode' => hex($received->[14]),
                    'RawMsg' => $received,
                    }; 
          #return $received->[6];
        } else {
          confess({ 
                error =>  sprintf( "%02X",$received->[5] ) , 
                message => "[get_module_status] erreur dans le message du trx [@$received] " . $self->get_generic_error_message($received->[5])
                } );
        }
    }    
}

=head2 ping

Je refuse d'expliquer ce que fait un ping. Si vous ne savez pas ce que vous faites, vous feriez mieux de retourner à l'école.

Retourne:

    0 if ok
    
confession dans les autres cas

=cut
sub ping {
    my ($self) = @_;
    $self->clear_message_raw();
    $self->clear_message_decoded();
    $self->clear_message();
    $self->clear_module_name();    
    confess({error => ERROR_NO_IDENT, message =>"[ping] pas d'identifiant trx, veuillez scan_smartbricker avant toute chose"}) unless $self->has_ident();
    my $encoded = $self->_encode_smb([0x80, $self->ident() , 0x00, 0x00, 0x02]);
    $self->send( $encoded );
    $self->receive();
    $self->_decode_smb();
    my $received = $self->message_decoded();
    if( defined($received->[5]) ) {
        if(($received->[5]==0x00)||($received->[5]==0x70)) {
          return $received->[6];
        } else {
          confess({ 
                error =>  sprintf( "%02X",$received->[5] ) , 
                message => "[ping] erreur dans le message du trx [@$received] " . $self->get_generic_error_message($received->[5])
                } );
        }
    }
}

=head2 get_identifiant

Pour un identifiant donné, vérifie si le trx contacté correspond
    
Paramètre:
    
    identifiant hexadécimal d'un trx (exemples: 0x00 ou 0x01)
    
pour les informations renvoyées par cette commande, voir decode_ident
        
=cut
sub get_identifiant {
    my ($self,$smb_dest) = @_;
    $self->clear_message_raw();
    $self->clear_message_decoded();
    $self->clear_message();
    $self->clear_module_name();    
    #$self->ident($smb_dest);
    my $encoded = $self->encode_ident($smb_dest);
    $self->send( $encoded );
    if ($self->receive() == 0) {
        $self->_decode_smb();
        $self->decode_ident();
    }
    return 0;
}

=head2 deactive_state
    
Désactive le trx, à utiliser après la fin de l'émisison d'un message


=cut

sub deactive_state {
    my ($self) = @_;
    return $self->set_activation_state(DEACTIVATE);
}

=head2 active_state

Active le trx, indispensable avant l'envoi de message.

=cut
sub active_state {
    my ($self) = @_;
    return $self->set_activation_state(ACTIVATE);
}

=head2 clear_fifo_rx

vide la fifo réception du trx

=cut
sub clear_fifo_rx {
    my ($self) = @_;
    return $self->clear_fifo(FIFO_RX);
}

=head2 clear_fifo_tx

vide la fifo transmission du trx

=cut
sub clear_fifo_tx {
    my ($self) = @_;
    return $self->clear_fifo(FIFO_TX);
}

=head2 set_fifo_clear

Vide la fifo du TRX.

Pour vider la fifo, le TRX doit être dans l'état desactivé. Si le TRX est activé, la méthode le désactive, vide la fifo, puis le réactive en sortie.

Paramètre:

        0x03     =>    FIFO_RX             
        0x02    =>     FIFO_TX              
        0x00    =>     NO_FIFO_CLEAR        

    8000FF303002 clear TX FIFO
    8000FF303003 clear RX FIFO
    
voir aussi

        clear_fifo_rx
        clear_fifo_tx

=cut
sub clear_fifo {
    my ($self,$param) = @_;
    return 0 if defined($param) && $param == NO_FIFO_CLEAR;
    confess({error => ERROR_PARAM, message => "[clear_fifo] error clear fifo param, expected 0x03 / 0x02 / 0x00"}) if !defined($param) || ( ($param!=FIFO_RX) && ($param!=FIFO_TX) );
    my $status = $self->get_module_status();
    $self->deactive_state() if $status->{"ActiveMode"} ==  ACTIVATE;
    my $msg =[0x80, $self->ident, 0xFF, 0x30, 0x30, $param];
    my $encoded = $self->_encode_smb($msg);
    $self->send( $encoded );
    $self->receive();
    $self->_decode_smb();
    my $received = $self->message_decoded();
    $self->active_state() if $status->{"ActiveMode"} ==  ACTIVATE;    
    if ( $received->[5] ) {
        if( ($received->[5]==0x00) || ($received->[5]==0x70) ) {
          return 0;
        } else {
          confess({
            error => sprintf( "%02X",$received->[5] ) , 
            message => "[clear_fifo] fifo not clear - " . join(" " ,@{$self->get_error_message($received->[5])})
            });
        }
    }
    return 0;
}

=head2 check_fifo

Vérifie si le trx est pret à parler, Ja!

Paramètres: aucun
    
Retourne 0 si tout va bien

Mais surtout se confesse dans les autres cas, 
    
Réponses obtenues
    
    $trx->rx_fifo_message_count();
    $trx->tx_fifo_message_count();
    $trx->tx_fifo_message_possible();
    $trx->current_trigger_mode();
    $trx->current_mode();

  # 8000FF0003 get status
  # answer : 00 80 FF 00 83 00 82 00 30 05 00 00 04 00 00

    # [08] 0x30            Flag indicating class 30 specific status data
    # [09] 0x05            Length, in byte, of the class 30 status record
    # [10] RXMsgCount      1 byte, MSB first, providing the number of messages
    #                 available in memory (RX FIFO) through the Read Message command
    # [11] TXMsgCount      1 byte, MSB first, providing the number of output messages
    #                 still in memory (TX FIFO), waiting to be sent
    # [12] TXMsgAvailable  1 byte, providing the number of messages the TX FIFO can still host (free slots)
    # [13] TriggerMode     1 byte, current trigger mode (cf Set-Trigger-Mode command)
    # [14] ActiveMode      1 byte, current mode (message processing on or off)
    #        

=cut
sub check_fifo {
    my ($self) = @_;
    my $msg =[
        0x80, $self->ident, 0xFF, 0x00, 0x03
        ];
    my $encoded = $self->_encode_smb($msg);
    $self->send( $encoded );
    $self->receive();
    $self->_decode_smb();
    my $received = $self->message_decoded();    
    confess( {error => ERROR_ANSWER, message => "[check_fifo] Unable to verify the FIFO" }) unless defined($received->[14]);

    $self->rx_fifo_message_count($received->[10]);
    $self->tx_fifo_message_count($received->[11]);
    $self->tx_fifo_message_possible($received->[12]);
    $self->current_trigger_mode($received->[13]);
    $self->current_mode($received->[14]);
    return 0;
}

=head2 _encode_smb

Encodage smartbrick
    
Paramètre:

        array ref hexa du message à envoyer
        
Retour:

        array ref du message         

=cut
sub _encode_smb {
  my ($self,$buffer) = @_;
  confess({error => ERROR_PARAM, 
        message =>
        "[_encode_smb] pas de buffer, pas de décodage, veuillez vérifier vos données!"}) unless defined($buffer);
  confess({error => ERROR_NO_IDENT, message =>"[_encode_smb] Manque certainement un identifiant"}) unless defined($buffer->[0]);
  my $dest = [SAFP];
  my $j=1;
  my $crc = Digest::CRC::crc16_xmodem_ccitt( join "", map {chr($_)} @$buffer );
  push( @$buffer , ($crc >> 8) , ($crc & 0xFF) );
  for (my $i= 0;$i < @$buffer; $i++) {
    if (    $buffer->[$i] == SAFP
         || $buffer->[$i] == FESC
         || $buffer->[$i] == BANG
    ) {
      $dest->[$j++] = FESC;
      $dest->[$j] = $buffer->[$i] ^ 0x40;
    }
    else {
        $dest->[$j]=$buffer->[$i];
    }
    $j++; 
  }
  push(@$dest, SAFP);
  return $dest;
}

=head2 _decode_smb

Decode la trame reçu d'un trx
    
La trame décodée est disponible sous forme de référence de tableau d'octets via
    
    $trx->message_decoded();

=cut
sub _decode_smb {
    my ($self) = @_;
    my @buf = unpack ('C*', $self->message_raw() );
    
    my @dest = ();
     my ($i,$j,$crc_r,$crc_c);
     my $len = scalar(@buf);
     confess({error => ERROR_DECOD,message => "[_decode_smb] Erreur decodage"}) if ($buf[0] != SAFP);
      $i=1;
      $j=0;
      do {
        if ( $buf[$i] == FESC) {
          $i = $i+1;
          $dest[$j] = $buf[$i] ^ 0x40;
        } else {
          $dest[$j] = $buf[$i];
        }
        $i = $i+1;
        $j = $j+1;
      } while( ($i<$len) && ($buf[$i] != SAFP) );
      $crc_r = $dest[$j-2] << 8;
      $crc_r += $dest[$j-1];
      my @dest_a_decoder = @dest;
      splice(@dest_a_decoder,-2); #remove octets du CRC du smb
      $crc_c = Digest::CRC::crc16_xmodem_ccitt( join "", map {chr($_)} @dest_a_decoder );
      $self->message_decoded(\@dest_a_decoder);
      confess(  { message =>  "[_decode_smb] Erreur decodage" , error => (ERROR_DECOD | $i) } ) if  $buf[$i] != SAFP;      
      confess(  { message =>  "[_decode_smb] Erreur crc" , error => (ERROR_CRC | $i) } ) if $crc_r != $crc_c;      
      return 0;
}

=head2 send

Envoi de données au trx
    
Parametre:
    
    array ref du message encodé avec le protocole smartbrick
    
voir _encode_smb pour l'encodage

=cut

sub send {
    my ($self,$message) = @_;
    my ($blk, $in, $out, $err);
    confess( {error => ERROR_PARAM,message =>"[send] pas de message, pas d'envoi" }) if @$message == 0;
    if ($self->mode() & CONNEXION) 
    {
      my $msg = join "" , map { pack( 'C', $_ ) } @$message;
      eval {
        my $cnt_out = $self->conn()->write($msg);
        if ($cnt_out != length($msg))
        {
            warn "write incomplete\n";
        }
      };
      if ($@) {
        confess( {error => ERROR_PARAM, message => "[send] $@" });
      }
      else 
      {
          #$self->conn()->write_done(0);
          ($blk, $in, $out, $err) = $self->conn()->status;
          if ($err != 0 ) 
          {
              warn "Serial interface error: ".$err."\n";    
          }
          
      }
    }
    return 0;
}

=head2 receive

Reçoit des données par le module radio

Les données binaires reçues sont stockées dans $trx->message_raw


=cut

sub receive {
    #my ($self,$testname) = @_;
    my ($self) = @_;
    $self->message_raw('');
    unless ($self->has_mode()) {
        $self->message_raw( pack("H",'00'));
    }
    if ($self->mode & DATAS && !($self->mode & PROD)) {
        my($blk, $in, $out, $err); # serial port management
        my $tmpbuf="";
        my $buf ="";
        my $timeout;
        my $tick_count;
        ($blk, $in, $out, $err) = $self->conn()->status;
        
        $tick_count = $self->_get_tick_count();
        $timeout = $tick_count + $self->timeout();
        
        while( ($in == 0) && ($tick_count < $timeout)) {
            usleep(5000);
            ($blk, $in, $out, $err) = $self->conn()->status;
            $tick_count = $self->_get_tick_count();
        }
        #confess( {error => ERROR_TIMEOUT, message => "[receive] timeout pas de reponse du trx"}) if $self->_get_tick_count() >= $timeout;
        if ( $tick_count >= $timeout )
        {
            #$self->conn()->reset_error;
            #$self->conn()->lookclear;
            #$self->conn()->restart($self->saved_trxconf);
            confess( {error => ERROR_TIMEOUT, message => "[receive] timeout pas de reponse du trx"});
        }
        $tmpbuf = $self->conn()->input;
        $tick_count = $self->_get_tick_count();
        do {
                usleep(5000);
                $buf .= $tmpbuf;
                $tmpbuf = $self->conn()->input;
                ($blk, $in, $out, $err) = $self->conn()->status;
                $tick_count = $self->_get_tick_count();
        } while ( (length($tmpbuf)!=0) && ($tick_count < $timeout) ) ;
        #confess( {error => ERROR_TIMEOUT, message =>"[receive] timeout toujours pas de reponse du trx"}) if $self->_get_tick_count() >= $timeout;
        if ( $tick_count >= $timeout )
        {
            $self->conn()->lookclear;
            confess( {error => ERROR_TIMEOUT, message => "[receive] timeout toujours pas de reponse du trx"});
        }
        
        $self->message_raw($buf);
        ($blk, $in, $out, $err) = $self->conn()->status;          
        if ($err == 0x8){
              $self->conn(undef);
              $self->conn( SerPort->start ($self->saved_trxconf())) or confess( "[receive] Can't start ".$self->saved_trxconf().": $!");
              confess({error => ERROR_SERIAL_LINK, message =>"[receive][error lors de la connexion avec le trx] " });
        }
        return( ERROR_SERIAL_LINK ) if  $err != 0 ;
        return 0;      
    }
    return 0;
}


=head2 close

Supprime le fichier conf temporaire lié à la liaison vers le port série.


=cut
sub close {
    my ($self) = @_;
    unless ($self->has_mode()) {
        $self->conn(undef);
        if (-e $self->saved_trxconf()) {
            unlink $self->saved_trxconf();
        }        
    }
    return 0;
}

=head1 Initialisations

=head2 set_config

Configure le trx
    
    Paramètres (optionnels):
        identifiant trx
        identifiant channel rx : voir liste des channel
        identifiant channel tx : voir liste des channel
        power
        
Optionnels s'ils sont définis au préalable dans un fichier de conf
        
    Exemple
    $trx->set_v2_config(  0x00,      "3A",          "3A",          12     );
        ==                 $smb_dest,$channel_rx,$channel_tx,$power
                    #ident
                    
Initialise les valeurs suivantes:
    
    set_frequency_deviation : valeur par défaut 2400
        Pour utiliser une autre valeur, initialiser au préalable set_frequency_deviation
        $trx->set_frequency_deviation(4800);
        
    set_symbol_rate : valeur par défaut 2400
        Pour utiliser une autre valeur, initialiser au préalable symbol_rate
        $trx->symbol_rate(4800);    
        
    set_rftx_power
        Pour utiliser une autre valeur, initialiser au préalable power
        $trx->tx_power(12);
        
    set_modulation : valeur par défaut "GFSK"    
        Pour utiliser une autre valeur, initialiser au préalable 
        $trx->rx_modulation("GFSK");    
        $trx->tx_modulation("GFSK");    
        voir liste dans l'attribut modulation
    
    set_legacy_modulation : valeur par défaut "OFF"        
        Pour utiliser une autre valeur, initialiser au préalable legacy_modulation
        $trx->legacy_modulation("OFF");

    set_crc_disable : valeur par défaut "OFF"        
        Pour utiliser une autre valeur, initialiser au préalable crc_disable
        $trx->crc_disable("OFF");

    set_raw_mode : valeur par défaut "OFF"        
        Pour utiliser une autre valeur, initialiser au préalable raw_mode
        $trx->raw_mode("OFF");        
    
=cut

sub set_config {
    my ($self,$channel_rx,$channel_tx,$power) = @_;    
    confess("[set_config] pas d'identifiant trx, veuillez scan_smartbricker avant toute chose") unless $self->has_ident();
    $self->deactive_state();
    $channel_tx ||= $self->tx_channel();
    if(!defined($self->get_channel(lc $channel_tx )) ) {
        confess({ message => "[set_config] bad channel [$channel_tx]",error => ERROR_PARAM});
    } else {
        $self->tx_channel($channel_tx);
        $self->set_rf_frequency($self->get_channel(lc $channel_tx),PARAM_TX);
    }
    $self->set_frequency_deviation( $self->tx_frequency_deviation() || 2400,PARAM_TX);
    $self->set_symbol_rate($self->tx_symbol_rate() || 2400,PARAM_TX);
    $self->set_modulation($self->tx_modulation() || "GFSK",PARAM_TX);
    $self->set_rftx_power($power || $self->tx_power());
    #rx now
    $channel_rx ||= $self->rx_channel();
    if (!defined($self->get_channel(lc $channel_rx)) ) {
        confess({ message => "[set_config] bad channel [$channel_rx]",error => ERROR_PARAM});
    } else {
        $self->rx_channel($channel_rx);
        $self->set_rf_frequency($self->get_channel(lc $channel_rx),PARAM_RX);
    }
    $self->set_frequency_deviation( $self->rx_frequency_deviation() || 2400,PARAM_RX);
    $self->set_symbol_rate($self->rx_symbol_rate() || 2400,PARAM_RX);
    $self->set_modulation($self->rx_modulation() || "GFSK",PARAM_RX);
    $self->set_legacy_modulation($self->legacy_modulation() || "OFF");
    #$self->set_crc_disable($self->crc_disable() || "OFF");
    $self->set_raw_mode($self->raw_mode() || "OFF");
}

=head2 set_v1_config
    
Configure le trx en mode V1
    
    Valeurs fixes
    
    channel : 130 => 169.443750,
    
    frequency_deviation: 2400

    symbol_rate: 2400
    
    modulation: GFSK
    
    legacy_modulation: ON
    
=cut
sub set_v1_config {
  my ($self,$power)=@_;
    confess("[set_v1_config] pas d'identifiant trx, veuillez scan_smartbricker avant toute chose") unless $self->has_ident();
    
    $self->tx_channel( $self->get_channel(130) );    #130 => 169.443750,
    $self->rx_channel( $self->get_channel(130) );    #130 => 169.443750,
    
    $self->tx_frequency_deviation(2400);
    $self->rx_frequency_deviation(2400);
    
    $self->tx_symbol_rate(2400);
    $self->rx_symbol_rate(2400);

    $self->tx_modulation("GFSK");
    $self->rx_modulation("GFSK");
    
    $self->legacy_modulation("ON");

    $self->set_config(undef,undef,$power);    
}

=head2 set_v2_config

    Configure le trx en mode V2

    voir set_config

=cut

sub set_v2_config {
    my ($self,$channel_rx,$channel_tx,$power) = @_;    
    $self->set_config($channel_rx,$channel_tx,$power);
}


=head2 set_activation_state

Commande activation désactivation du trx, indispensable pour l'envoi d'un message.

Voir la spécification smartbrick (class 0x30) à ce sujet (paragraphe 2.4)

Ne pas utiliser directement, voir les méthodes deactive_state et active_state

    #  $err=smb_set_activation_state($smb_dest,DEACTIVATE);
    #  printf("smb deactivate error = %04X\n",$err) if($err);

    # 8000FF302101 activation ON
    # 8000FF302100 activation OFF

Paramètre

        Etat : 0x00 (DEACTIVATE)  / 0x01 (ACTIVATE) 

=cut

sub set_activation_state {
    my ($self,$state) = @_;
    confess({error => ERROR_NO_IDENT, message =>"[set_activation_state] pas d'identifiant trx, veuillez scan_smartbricker avant toute chose"}) unless $self->has_ident();
    my $encoded = $self->_encode_smb([0x80, $self->ident() , 0xFF, 0x30, 0x21, $state]);
    $self->send( $encoded );
    $self->receive();
    $self->_decode_smb();
    my $received = $self->message_decoded();
    if( defined($received->[5] ) ) {
        if(($received->[5]==0x00)||($received->[5]==0x70)) {
          return 0;
        } else {
          confess({ 
            error =>  sprintf( "%02X",$received->[5] ) , 
            message => "[set_activation_state] ($state): erreur dans l$self->conn()e message du trx [@$received] " . join(" " ,@{$self->get_error_message($received->[5])})
            } );
        }
    }
}

=head2 set_trigger_mode

Change le mode trigger sur le trx, permet d'envoyer un message avec un délai précis. Pour rappel, la valeur par défaut du paramètre ech_rx_length est de 20ms.

Les champions de la détente peuvent essayer à la main, les autres profiteront des avantages accordés par le système.

Différentes valeurs et leur signification

    #Trigger mode
    00 for autonomous mode (default)
    01 for external trigger mode
    02 for reply mode
    03 for absolute time mode
    
    #Trigger out mode
    00 : don't output trigger pulses
    01 : output pulses after each transmission
    02 : output pulses before each transmission
    03 : output pulses after each reception


paramètres:

        mode: 0x00 / 0x01 / 0x02 / 0x03
        
        out_mode: 0x00 / 0x01 / 0x02 / 0x03

=cut
sub set_trigger_mode {
    my ($self,$mode, $out_mode) = @_;
    confess({error => ERROR_NO_IDENT, message =>"[set_trigger_mode] pas d'identifiant trx, veuillez scan_smartbricker avant toute chose"}) unless $self->has_ident();
    my $encoded = $self->_encode_smb([0x80, $self->ident() , 0xFF, 0x30, 0x20, $mode, $out_mode]);
    $self->send( $encoded );
    $self->receive();
    $self->_decode_smb();
    my $received = $self->message_decoded();
    if( defined($received->[5] ) ) {
        if(($received->[5]==0x00)||($received->[5]==0x70)) {
          return 0;
        } else {
          confess({ 
                error =>  sprintf( "%02X",$received->[5] ) , 
                message => "[set_trigger_mode] ($mode): erreur dans le message du trx [@$received] " .join(" " ,@{$self->get_error_message($received->[5])})
                } );
        }
    }
}

=head2 set_rx_channel

Change le canal de réception en utilisant le numéro du canal
    
Paramètre:

        $rx_channel (en hexa ou en décimal, voir ATTRIBUTES)

=cut
sub set_rx_channel {
    my ($self,$rx_channel) = @_;
    $self->rx_channel($rx_channel);
    $self->set_rf_frequency( $self->get_channel(lc $rx_channel) ,PARAM_RX);
}

=head2 set_tx_channel

Change le canal  de transmission en utilisant le numéro du canal
    
Paramètre:

        $tx_channel (en hexa ou en décimal, voir ATTRIBUTES)

=cut

sub set_tx_channel {
    my ($self,$tx_channel) = @_;
    $self->tx_channel($tx_channel);
    #say("In set_tx_channel: tx_channel= ". $tx_channel);
    #say("In set_tx_channel: get_channel= ". $self->get_channel(lc $tx_channel));
    $self->set_rf_frequency( $self->get_channel(lc $tx_channel) ,PARAM_TX);    
}

=head2 set_rx_frequency

Change la fréquence de transmission en passant directement la valeur de la fréquence
    
Paramètre:

        fréquence

=cut
sub set_rx_frequency {
    my ($self,$rf_freq) = @_;
    return $self->set_rf_frequency($rf_freq,PARAM_RX);    
}

=head2 set_rx_frequency

Change la fréquence de réception en passant directement la valeur de la fréquence
    
Paramètre:

        fréquence

=cut

sub set_tx_frequency {
    my ($self,$rf_freq) = @_;    
    return $self->set_rf_frequency($rf_freq,PARAM_TX);        
}

=head2 set_rf_frequency

Modifie la fréquence sur un trx
    
Paramètre:

    frequency
    transmission (0x5A ) ou réception (0x55)
        
voir aussi les méthodes 

    set_rx_frequency
    set_tx_frequency
    
    set_rx_channel
    set_tx_channel

=cut
sub set_rf_frequency {
    my ($self,$rf_freq,$rxtx) = @_;
    my ($mhz_freq,$khz_freq,$hz_freq);    
    confess("[set_rf_frequency] pas d'identifiant trx, veuillez scan_smartbricker avant toute chose") unless $self->has_ident();
    if ( ($rxtx != PARAM_RX) && ($rxtx!=PARAM_TX)) {
        confess({error => ERROR_PARAM, message => "[set_rf_frequency] Rx/tx choice error in frequency set" });
    }
    $mhz_freq = int($rf_freq);
    $rf_freq = ($rf_freq - $mhz_freq) * 1000;
    $khz_freq = int($rf_freq);
    $rf_freq = ($rf_freq - $khz_freq) * 1000;
    $hz_freq = int($rf_freq);    
    my $msg =[
        0x80, $self->ident, 0xCF, 0x30,0x08,
        ($rxtx==PARAM_RX ? RX_FREQUENCY_X1M : TX_FREQUENCY_X1M), 
        ($mhz_freq >> 8),
        ($mhz_freq & 0xFF),
        ($rxtx==PARAM_RX ? RX_FREQUENCY_X1K : TX_FREQUENCY_X1K), 
        ($khz_freq >> 8),
        ($khz_freq & 0xFF),
        ($rxtx==PARAM_RX ? RX_FREQUENCY_X1    : TX_FREQUENCY_X1), 
        ($hz_freq >> 8),
        ($hz_freq & 0xFF)
    ];
    my $encoded = $self->_encode_smb($msg);
    $self->send( $encoded );
    return $self->_check_answer("channel");
}

=head2 set_frequency_deviation

Modifie la fréquency deviation sur un trx
    
voir aussi

    set_rx_frequency_deviation
    set_tx_frequency_deviation
    
Paramètre:

    frequency deviation
    transmission (0x5A ) ou réception (0x55)

=cut
sub set_frequency_deviation {
    my ($self,$freq_dev,$rxtx) = @_;
    confess("[set_frequency_deviation] pas d'identifiant trx, veuillez scan_smartbricker avant toute chose") unless $self->has_ident();
    if ( ($rxtx!=PARAM_RX) && ($rxtx!=PARAM_TX)) {
        confess({error => ERROR_PARAM, message => "[set_frequency_deviation] rx/tx choice error in freq dev set" });
    }
    confess({error => ERROR_PARAM, message => "[set_frequency_deviation] deviation error" })
        if(($freq_dev<976)||($freq_dev>7812));    
    my $msg =[
        0x80, $self->ident, 0xCF, 0x30,0x08,
        ($rxtx==PARAM_RX ? RX_FREQUENCY_DEV : TX_FREQUENCY_DEV),
        ($freq_dev >> 8),
        ($freq_dev & 0xFF)
        ];
    my $encoded = $self->_encode_smb($msg);
    $self->send( $encoded );
    return $self->_check_answer("frequency deviation");
}

=head2 set_rx_frequency_deviation

Modifie la fréquency deviation  en réception sur un trx

Paramètre:

    frequency deviation

=cut
sub set_rx_frequency_deviation {
    my ($self,$freq_dev) = @_;
    $self->rx_frequency_deviation($freq_dev);    
    return $self->set_frequency_deviation($freq_dev,PARAM_RX);
}

=head2 set_tx_frequency_deviation

Modifie la fréquency deviation en transmission sur un trx

Paramètre:

    frequency deviation

=cut
sub set_tx_frequency_deviation {
    my ($self,$freq_dev) = @_;
    $self->tx_frequency_deviation($freq_dev);    
    return $self->set_frequency_deviation($freq_dev,PARAM_TX);
}

=head2 set_symbol_rate

Modifie le symbol rate sur un trx
    
Paramètre:

    symbol rate
    transmission (0x5A ) ou réception (0x55)

=cut
sub set_symbol_rate {
    my ($self,$symbol_rate,$rxtx) = @_;
    confess("[set_symbol_rate] pas d'identifiant trx, veuillez scan_smartbricker avant toute chose") unless $self->has_ident();
    confess({error => ERROR_PARAM, message => "[set_symbol_rate]  Rx/tx choice error in bit rate" })
        if(($rxtx!=PARAM_RX) && ($rxtx!=PARAM_TX));
    confess({error => ERROR_PARAM, message => "[set_symbol_rate]  symbol_rate error" })
        if(($symbol_rate<123) || ($symbol_rate>62500));
        
    my $ksymbol_rate = int($symbol_rate / 1000);
    $symbol_rate = $symbol_rate - ($ksymbol_rate*1000);
    
    my $msg =[
        0x80, $self->ident, 0xCF, 0x30,0x08,
        ($rxtx==PARAM_RX ? RX_SYMBOL_RATE_X1 : TX_SYMBOL_RATE_X1),
        ($symbol_rate >> 8),
        ($symbol_rate & 0xFF),
        ($rxtx==PARAM_RX ? RX_SYMBOL_RATE_X1K : TX_SYMBOL_RATE_X1K),
        ($ksymbol_rate >> 8),
        ($ksymbol_rate & 0xFF),
        ];
    my $encoded = $self->_encode_smb($msg);
    $self->send( $encoded );
    return $self->_check_answer("symbol_rate");
}

=head2 set_rx_symbol_rate

Modifie le symbol rate réception sur un trx
    
Paramètre:

    symbol rate

=cut
sub set_rx_symbol_rate {
    my ($self,$symbol_rate) = @_;
    $self->rx_symbol_rate($symbol_rate);
    return $self->set_symbol_rate($symbol_rate,PARAM_RX);
}

=head2 set_tx_symbol_rate

Modifie le symbol rate transmission sur un trx
    
Paramètre:

    symbol rate

=cut
sub set_tx_symbol_rate {
    my ($self,$symbol_rate) = @_;
    $self->tx_symbol_rate($symbol_rate);
    return $self->set_symbol_rate($symbol_rate,PARAM_TX);
}

=head2 set_modulation

Modifie la modulation sur un trx
    
Paramètre:

    modulation: voir ATTRIBUTES
    transmission (0x5A ) ou réception (0x55)

=cut
sub set_modulation {
    my ($self,$modu_text,$rxtx) = @_;
    confess("[set_modulation] pas d'identifiant trx, veuillez scan_smartbricker avant toute chose") unless $self->has_ident();
    confess({error => ERROR_PARAM, message => "[set_modulation] Rx/tx choice error in modulation set" })
        if ($rxtx!=PARAM_RX) && ($rxtx!=PARAM_TX);
    confess({error => ERROR_PARAM, message => "[set_modulation] Modulation is wrong" })
        if !defined( $self->get_modulation($modu_text)  );
    my $modu_bin = $self->get_modulation($modu_text);
    my $msg =[
        0x80, $self->ident, 0xCF, 0x30,0x08,
        ($rxtx==PARAM_RX ? RX_MODULATION : TX_MODULATION),
        ($modu_bin >> 8),
        ($modu_bin & 0xFF)
        ];
    my $encoded = $self->_encode_smb($msg);
    $self->send( $encoded );
    return $self->_check_answer("modulation");
}

=head2 set_rx_modulation

Modifie la modulation de réception sur un trx
    
Paramètre:

    modulation: voir ATTRIBUTES

=cut
sub set_rx_modulation {
    my ($self,$modu_text) = @_;
    $self->rx_modulation($modu_text);
    return $self->set_modulation($modu_text,PARAM_RX);
}

=head2 set_tx_modulation

Modifie la modulation de transmission sur un trx
    
Paramètre:

    modulation: voir ATTRIBUTES

=cut
sub set_tx_modulation {
    my ($self,$modu_text) = @_;
    $self->tx_modulation($modu_text);
    return $self->set_modulation($modu_text,PARAM_TX);
}


=head2 set_rftx_power

Modifie la puissance sur un trx
    
Paramètre:

    puissance (entre 12 et 22)

=cut
sub set_rftx_power {
    my ($self,$rftx_power) = @_;
    $self->tx_power($rftx_power);
    confess("[set_rftx_power] pas d'identifiant trx, veuillez scan_smartbricker avant toute chose") unless $self->has_ident();
    confess({error => ERROR_PARAM, message => "[set_rftx_power] RF power is wrong" })
        if ($rftx_power<12) || ($rftx_power>22);
    my $msg =[
        0x80, $self->ident, 0xCF, 0x30,0x08,
        TX_POWER,
        ($rftx_power >> 8),
        ($rftx_power & 0xFF)
        ];    
    my $encoded = $self->_encode_smb($msg);
    $self->send( $encoded );
    return $self->_check_answer('power');
}

=head2 set_legacy_modulation

Modifie le legacy modulation sur un trx
    
Paramètre:

    legacy modulation: on/off

=cut
sub set_legacy_modulation {
    my ($self,$bit_text) = @_;
    $self->legacy_modulation($bit_text);
    confess("[set_legacy_modulation] pas d'identifiant trx, veuillez scan_smartbricker avant toute chose") unless $self->has_ident();
    confess({error => ERROR_PARAM, message => "[set_legacy_modulation] legacy_modulation error" })
        if (!defined($self->get_on_off(lc $bit_text)));
        
    my $bit_bin = $self->get_on_off(lc $bit_text);
    
    my $msg =[
        0x80, $self->ident, 0xCF, 0x30,0x08,
        LEGACY_MODULATION,
        0,
        ($bit_bin & 0xFF)
        ];    
    my $encoded = $self->_encode_smb($msg);
    $self->send( $encoded );
    return $self->_check_answer('legacy_modulation');
}

=head2 set_crc_disable

Modifie la valeur crc auto sur un trx
    
Paramètre:

    crc auto valeur (string) : on/off

=cut
sub set_crc_disable {
    my ($self,$crc_text) = @_;
    $self->crc_disable($crc_text);
    confess("[set_crc_disable] pas d'identifiant trx, veuillez scan_smartbricker avant toute chose") unless $self->has_ident();
    confess({error => ERROR_PARAM, message => "[set_crc_disable] crc_disable error" })
        if (!defined($self->get_on_off(lc $crc_text)));

    my $crc_bin = $self->get_on_off(lc $crc_text);
    
    my $msg =[
        0x80, $self->ident, 0xCF, 0x30,0x08,
        CRC_DISABLE,
        0,
        ($crc_bin & 0xFF)
        ];    
    my $encoded = $self->_encode_smb($msg);
    $self->send( $encoded );
    return $self->_check_answer('crc_disable');
}

=head2 set_raw_mode

Modifie la valeur de raw mode sur un trx
    
Paramètre:

    raw mode valeur (string) : on/off

=cut
sub set_raw_mode {
    my ($self,$raw_text) = @_;
    $self->raw_mode($raw_text);
    confess("[set_raw_mode] pas d'identifiant trx, veuillez scan_smartbricker avant toute chose") unless $self->has_ident();
    confess({error => ERROR_PARAM, message => "[set_raw_mode] raw_mode error" })
        if (!defined($self->get_on_off(lc $raw_text)));

    my $raw_bin = $self->get_on_off(lc $raw_text);
    
    my $msg =[
        0x80, $self->ident, 0xCF, 0x30,0x08,
        RAW_MODE,
        0,
        ($raw_bin & 0xFF)
        ];    
    my $encoded = $self->_encode_smb($msg);
    $self->send( $encoded );
    return $self->_check_answer('raw_mode');
}


=head2 reset_free_running_clock

fait ce que dit son nom!

no parameter

=cut
sub reset_free_running_clock {
    my ($self) = @_;
    confess("[reset_free_running_clock] pas d'identifiant trx, veuillez scan_smartbricker avant toute chose") unless $self->has_ident();
    my $msg =[
        0x80, $self->ident, 0xCF, 0x30,0x08,
        0x08, 0x00,0x00
        ];    
    my $encoded = $self->_encode_smb($msg);
    $self->send( $encoded );
    return $self->_check_answer('reset_free_running_clock');
}

sub _check_answer {
    my ($self,$param_name) = @_;
    my $ans= [$self->ident, 0x80, 0xCF, 0x30, 0x88, 0x00];
    $self->receive();
    $self->_decode_smb();
    my $received = $self->message_decoded();    
    my $i=0;
    my $err=0;
    my $error ;
    do {
        if ($received->[$i] != $ans->[$i]) {
            $err=$i;
            $error = $received->[$i];
        }
        $i++;
    } while ( $i< @$ans && $err==0 );
    if ($err != 0) {
        my $message_error = $self->get_error_message($error)->[2];
        confess({
                error => ($err + ERROR_ANSWER),
                message => "error check answer on $param_name ($error: $message_error)",
            });
    }
    return 0;
}

=head2 encode_ident

Paramètre
    
    valeur (integer) de l'identifiant à tester

=cut
sub encode_ident {
  my ($self,$smb_dest) = @_;
  #get identification class 0 message
  return $self->_encode_smb([0x80, $smb_dest, 0x00, 0x00, 0x01]);
}

=head2 decode_ident

Decode le message renvoyé par le trx lors d'une commande d'identification
    
Initialise les valeurs suivantes:
    
    $trx->protocol_version();
    $trx->mod_model_msb();
    $trx->mod_model_lsb();
    $trx->mod_version();

    $trx->classes()
        liste des classes trx disponibles
    
    $trx->module_name();

=cut
sub decode_ident {
    my ($self) = @_;
    my $decoded = $self->message_decoded;
    my $len = scalar(@$decoded) - 2;  
    my $i=5;    
    if ($len <13) {
        confess( { error   => ERROR_ANSWER_SHORT,
                 message => "ident returned too short"
                 });
    }
    
    my $error_code = $decoded->[$i++];    #6
    if ($error_code!=0) {
        confess( { error   => ERROR_ANSWER,
                 message => "ident returned error code"
            });    
    }
    $self->protocol_version($decoded->[$i++]);    #7
    $self->mod_model_msb($decoded->[$i++]);        #8
    $self->mod_model_lsb($decoded->[$i++]);        #9
    $self->mod_version($decoded->[$i++]);        #10
    
    my $num_classes = $decoded->[$i++];
    my $classes='';
    while($num_classes > 0) {
        $classes .= sprintf("%02X ", $decoded->[$i++]);
        $num_classes--;
    }
    $self->classes($classes);
    
    my $module_name='';
    while( defined($decoded->[$i])  && $i < $len) {
        my $char = $decoded->[$i++];
        $module_name .= $char != 0 ? sprintf("%c", $char) : $char;
    }
    $self->module_name($module_name);
    if ($i < $len) {
        confess( { error   => ERROR_ANSWER,
                 message => "message length too long"
                });    
    }
    return 0;
}

=head2 clean_messages

Enleve les smartbriqueries pour ne garder que l'essence du message.

Patch:

    oui, mais Alciom s'étant mis à la programmation implicite, il manque l'octet de longueur qui est donc à rajouter, s'il manque.
    Il faut donc le remettre avant de renvoyer la trame
    
En gros,
 
    9 au début 
    
Paramètre:

        message (array ref integer)  
    
retourne:

        message (array ref) - les éléments supprimés
        
=cut
sub clean_messages {
    my ($self,$messages)=@_;
    my $copie;
    my $cleaned = [];
    foreach my $message (@$messages) {
        my @raw = @$message;
        push(@$copie,\@raw);
        my (@removed) = splice(@$message,0,9);    #remove 9 premiers octets
                                #l'octet neuf correspond au rssi
        $self->rssi(pop(@removed));    
        #attention, 
        #PATCH LENGTH ALCIOM
        if ($self->raw_mode =~ m/ON/i) {
            #si le crc est contrôlé, Alciom enlève tout, le bas et le haut
            my $longueur =  scalar(@$message);
            unshift(@$message,$longueur);
        }
        #END PATCH LENGTH ALCIOM
        push( @$cleaned, $message);
    }
    $self->_smb_raw_message($copie);
    return $cleaned;
}

=head2 write_datas

Ecriture d'un message sur la fifo du trx.
    
Paramètres:

    message (array ref integer) 

    delay or absolute time (integer), see smartbirck specifications.
        Message peut être envoyé plus tard selon le délai donné et la configuration du mode trigger
        
voir méthodes send_message et send_message_fast
    
=cut
sub write_datas {
    my ($self,$message,$delay) = @_;
    if (scalar(@$message) == 1)  {
        my @tmp = map {  hex $_  }  $message->[0] =~ m/([A-Fa-f0-9]{2})/ig;
        $message = \@tmp;
    }
    #PATCH LENGTH ALCIOM
    #Lors des envois, Alciom envoie aussi longueur et CRC
##    shift(@$message);
    #splice(@$message,-2);
    #END PATCH LENGTH ALCIOM
    my $msg =[
        0x80, $self->ident, 0xFF, 0x30, 0x14,
        ( ($delay>>8) & 0xFF ),
        ( ($delay) & 0xFF ),
        @$message
        ];     
    
    my $encoded = $self->_encode_smb($msg);
    # FIXME: Debug here
#    my $message_len = scalar @$message;
#    my $format = 'H2 H6 H8 H'. $message_len*2 .'H4 H2';
#    my $str = join ' ', unpack($format, pack('C*',@$encoded)); 
#    print "Encoded: $str\n";
    
    $self->send( $encoded );
    $self->receive();
    $self->_decode_smb();
    my $received = $self->message_decoded();
    if (defined $received->[5]) {
        if(($received->[5]==0x00) || ($received->[5]==0x70)) {
            return 0;
        } else {
            confess({
                error => sprintf( "%02X",$received->[5] ), 
                message => "[write_datas] pb envoi message - ". join(" " ,@{$self->get_error_message($received->[5])})
            });
        }
    }
    return 0;
}

=head2 read_fifo

Lit le contenu de la fifo du trx

    retourne:
        array ref integer

=cut
sub read_fifo {
    my ($self) = @_;
    my $msg =[ 0x80, $self->ident, 0xFF, 0x30, 0x18    ];
    my $encoded = $self->_encode_smb($msg);
    $self->send( $encoded );
    $self->receive();
    $self->_decode_smb();
    my $received = $self->message_decoded();
    return $received;
}

=head2 list_comport

Obtenir la liste des ports disponibles
    
Renvoie un tableau des ports disponibles
    
    my @ports_disponibles = $trx->list_comport();

=cut
sub list_comport {
    my ($self) = @_;
    my @coms;
    if ($^O eq "MSWin32")
    {
        my ($string,$major,$minor,$build,$id) = Win32::GetOSVersion();
        confess( "$string is nor supported by this script\n") if $id == 0;
        if ($id == 2) {    # NT plateforms ...
            my $hkey_local_machine = new Win32::TieRegistry  "LMachine" ;
            my $subKey = $hkey_local_machine->Open("Hardware/DEVICEMAP/SERIALCOMM",{Delimiter => "/"}) 
                        or confess("pas de serial comm en vue: $! ");
            my %ports;
            foreach ($subKey->ValueNames) {
                $ports { $subKey->GetValue($_) }  = $_ ;
            }
            @coms = (sort keys %ports);
        }
    }
    return @coms;
}

=head2 get_available_comport

Recherche un port série disponible.

Vérifie que le port est connecté à un module TRX
    Teste l'ouverture du port

Si le script est lié au banc pxi, vérifie que le port correspond à un élément du banc pxi
    Boucle sur les identifiants supérieurs à 0
    Si la réponse est différente de 0, le port série correspond à un élément du banc_pxi.


=cut
sub get_available_comport {
    my ($self) = @_;
    my @coms = $self->list_comport();
    $self->available_comport(\@coms);

    say Dumper(\@coms);    
    for my $com (@coms) {
        say "$com";
        $self->comport($com);
        eval {
            my $connexion = SerPort->new ($self->comport()) 
                    or confess({error => ERROR_SERIAL_LINK, 
                        message => 
                    "[open] Unable to open the port [". $self->comport() ."] $@"});
            $self->conn($connexion);
            $self->_configure(1);
        };
        if ($@) {
            say "$com not open";
            say Dumper($@);
            next;
        }
        eval {
            say "verif identifiant";
            $self->list_smartbrick([0x00,0x10,0x11],1);
        };
        if ($@) {
            say "no read";
            say Dumper($@);
            next;
        };
        $self->close();
    }

}


#private! privé! réservé au personnel habilité!
#On frappe avant d'entrer et on n'entre pas sans y être autorisé.
#en tout cas les gens polis

#configuration du port série only
sub _configure {
    my ($self,$timeout) = @_;
    $self->conn()->user_msg($self->user_msg());
    $self->conn()->error_msg($self->error_msg());
    $self->conn()->baudrate($self->baudrate());
    $self->conn()->parity($self->parity());
    $self->conn()->parity_enable($self->parity_enable());
    $self->conn()->databits($self->databits());
    $self->conn()->stopbits($self->stopbits());
    $self->conn()->handshake($self->handshake());
    $self->conn()->write_settings;

    if ($timeout) {
        $self->conn()->read_char_time(100);
        $self->conn()->read_const_time(500);
        $self->conn()->read_interval(100);
        $self->conn()->write_char_time(100);
        $self->conn()->write_const_time(500);        
    }
    my $conftrx = $self->saved_trxconf();
    my $port = $self->comport();
    $self->saved_trxconf("./$port-$conftrx");
    $self->conn()->save($self->saved_trxconf());    
}


sub _load_config_file {
    my ($self,$new_config_file,$old) = @_;
    unless ( $new_config_file ) {
            $new_config_file = $self->_default_config_file();
    }
    confess("File doesn't exist! $! : " . $new_config_file ) unless -e $new_config_file;
    my $config;
    
    my $wm_modulation;
    my $symbol_rate;
    my $freq_deviation;
    my $modulation;
    eval {
        $self->config( Config::Tiny->read( $new_config_file ) ); 
        die "Error in conf file [$new_config_file] ".$Config::Tiny::errstr if $Config::Tiny::errstr;
        confess("COM or ttyUSB port not found") unless $self->config()->{main}->{comport};
        $self->comport( $self->config()->{main}->{comport} );
        $self->timeout( $self->config()->{main}->{timeout} );
        
        if ($self->config()->{main}->{identifiants}) 
        {
            my @list = map { hex($_) } split(/,/,$self->config()->{main}->{identifiants});
            $self->identifiants( \@list );
        }    
        $self->banc_pxi( $self->config()->{main}->{banc_pxi} || 0 );    
        
        $self->rx_channel( $self->config()->{smartbrick}->{RX_CHANNEL} ) if $self->config()->{smartbrick}->{RX_CHANNEL};
        
        $self->tx_channel( $self->config()->{smartbrick}->{TX_CHANNEL} ) if $self->config()->{smartbrick}->{TX_CHANNEL};
        
        $self->tx_power( $self->config()->{smartbrick}->{TX_POWER} ) if $self->config()->{smartbrick}->{TX_POWER};    
        #$self->crc_disable( $self->config()->{smartbrick}->{RAW_MODE} ) if $self->config()->{smartbrick}->{CRC_DISABLE};    
        $self->raw_mode( $self->config()->{smartbrick}->{RAW_MODE} ) if $self->config()->{smartbrick}->{RAW_MODE};
        $self->raw_mode_cfg($self->raw_mode() || "OFF");
        
        $self->legacy_modulation( $self->config()->{smartbrick}->{LEGACY_MODULATION} ) if $self->config()->{smartbrick}->{LEGACY_MODULATION};            
       
        $self->trig_out_enable( $self->config()->{smartbrick}->{TRIGGER_OUT} ) if $self->config()->{smartbrick}->{TRIGGER_OUT};   

        # RX modulation 2400 and default
        $symbol_rate = 2400;
        $freq_deviation = 2400;
        $modulation = "GFSK";
        
        if ( defined($self->config()->{smartbrick}->{RX_WM_MODULATION}) )
        {
            $wm_modulation = hex($self->config()->{smartbrick}->{RX_WM_MODULATION});          
            #modulation 4800    
            if ($wm_modulation == 1) 
            {
                $symbol_rate = 4800;
                $freq_deviation = 2400;
                $modulation = "GFSK";
            #modulation HSPEED    
            } 
            elsif ($wm_modulation == 2) 
            {
                $symbol_rate = 3200; # bitrate = 6400bps
                $freq_deviation = 3200;
                $modulation = "4GFSK";
            }
            else {}
        }
        else 
        {
            $modulation = ($self->config()->{smartbrick}->{RX_MODULATION}) if defined($self->config()->{smartbrick}->{RX_MODULATION});
            $freq_deviation = ($self->config()->{smartbrick}->{RX_FREQUENCY_DEVIATION}) if defined($self->config()->{smartbrick}->{RX_FREQUENCY_DEVIATION});
            $symbol_rate = ($self->config()->{smartbrick}->{RX_SYMBOL_RATE}) if defined($self->config()->{smartbrick}->{RX_SYMBOL_RATE});
        }                

        $self->rx_modulation($modulation);
        $self->rx_frequency_deviation($freq_deviation);
        $self->rx_symbol_rate($symbol_rate);
        
        
        # TX modulation 2400 and default
        $symbol_rate = 2400;
        $freq_deviation = 2400;
        $modulation = "GFSK";
        
        if ( defined($self->config()->{smartbrick}->{TX_WM_MODULATION}) )
        {
            $wm_modulation = hex($self->config()->{smartbrick}->{TX_WM_MODULATION});
            #modulation 4800    
            if ($wm_modulation == 1) 
            {
                $symbol_rate = 4800;
                $freq_deviation = 2400;
                $modulation = "GFSK";
            #modulation HSPEED    
            } 
            elsif ($wm_modulation == 2) 
            {
                $symbol_rate = 3200; # bitrate = 6400bps
                $freq_deviation = 3200;
                $modulation = "4GFSK";
            }
            else {}
        }
        else 
        {
            $modulation = ($self->config()->{smartbrick}->{TX_MODULATION}) if defined($self->config()->{smartbrick}->{TX_MODULATION});
            $freq_deviation = ($self->config()->{smartbrick}->{TX_FREQUENCY_DEVIATION}) if defined($self->config()->{smartbrick}->{TX_FREQUENCY_DEVIATION});
            $symbol_rate = ($self->config()->{smartbrick}->{TX_SYMBOL_RATE}) if defined($self->config()->{smartbrick}->{TX_SYMBOL_RATE});
        } 
        $self->tx_modulation($modulation);
        $self->tx_frequency_deviation($freq_deviation);
        $self->tx_symbol_rate($symbol_rate);        
        
        #confs serial port
        $self->user_msg( $self->config()->{serial}->{user_msg}  ) or confess("param user_msg is missing") unless defined $self->config()->{serial}->{user_msg};
        $self->error_msg( $self->config()->{serial}->{error_msg}  ) or confess("param error_msg is missing") unless defined $self->config()->{serial}->{error_msg};
        $self->baudrate( $self->config()->{serial}->{baudrate}  ) or confess("param baudrate is missing") unless $self->config()->{serial}->{baudrate};
        $self->parity( $self->config()->{serial}->{parity}  ) or confess("param parity is missing") unless defined $self->config()->{serial}->{parity};
        $self->parity_enable( $self->config()->{serial}->{parity_enable} || 0 ) or confess("param parity_enable is missing") unless defined $self->config()->{serial}->{parity_enable};
        $self->databits( $self->config()->{serial}->{databits}  ) or confess("param databits is missing") unless defined $self->config()->{serial}->{databits};
        $self->stopbits( $self->config()->{serial}->{stopbits}  ) or confess("param stopbits is missing") unless defined $self->config()->{serial}->{stopbits};
        $self->handshake( $self->config()->{serial}->{handshake}  ) or confess("param handshake is missing") unless defined $self->config()->{serial}->{handshake};
        
        #$self->config()->{main}->{mode} = 7 if $self->config()->{main}->{mode} eq '' || !$self->config()->{main}->{mode};
        $self->mode( $self->config()->{main}->{mode} );
        #charge un test
            
    };
    if ($@) {
            confess("[_load_config_file] $@ : config file [" . $self->config_file . "]");
    }    
    return $new_config_file;
}

sub _load_comport {
    my ($self) = @_;
    $self->_load_config_file();
    return $self->comport(); 
}

sub _load_mode {
    my ($self) = @_;
    $self->_load_config_file();
    $self->mode(7) unless Scalar::Util::looks_like_number( $self->mode() ) ;    
    return $self->mode(); 
}

sub _load_timeout {
    my ($self) = @_;
    $self->_load_config_file();
    return $self->timeout(); 
}

sub _get_tick_count{
    if ($^O eq "MSWin32")
    {
        return Win32::GetTickCount();
    }
    elsif ($^O eq "linux")
    {
        return SerPort->get_tick_count;
    }
    else
    {    
        return 0;
    }
}

=head2 Exemple de fichier de conf

Le contenu de cette conf est aussi disponible à la racine du module.

    exemple-configuration.cfg

    [main]
    comport=COM6
    mode=3
    timeout=8000
    identifiants=0x00,0x01,0x02,0x10,0x11,0x12

    [smartbrick]
    LEGACY_MODULATION=OFF
    RAW_MODE=ON
    TX_POWER=12

    RX_CHANNEL=100
    RX_SYMBOL_RATE=2400
    RX_MODULATION=4GFSK
    RX_FREQUENCY_DEVIATION=2400

    TX_CHANNEL=100
    TX_SYMBOL_RATE=2400
    TX_MODULATION=4GFSK
    TX_FREQUENCY_DEVIATION=2400

    [serial]
    user_msg=1
    error_msg=1
    baudrate=115200
    parity=none
    parity_enable=1
    databits=8
    stopbits=1
    handshake=none
    saved_fileconf=saveconfigfilecom.cfg

    [tests]
    #nom du test et données renvoyées ;)
    #script_numtest=trame

    [receiving]
    timeout=2000
    retry=3
    tempo=2000


=cut

=head1 AUTHOR

phv, C<< <philippe.devisme at suez-env.com> >>

=head1 BUGS

Please report any bugs or feature requests to Ondeo Systems.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Telereleve::COM::Trx

=head1 ACKNOWLEDGEMENTS

Jean-René Herbron, qui a analysé la doc smartbrick et réalisé le script de connexion au trx à partir duquel ce module a été réalisé et sans lequel ça aurait été nettement plus difficile.

Benjamin Jannier, essuyeur de plâtres, pour avoir testé le module sur le banc et remonté bugs et demandes d'évolution sans jamais râler (enfin presque).

=head1 LICENSE AND COPYRIGHT

Copyright 2014-2015 Ondeo Systems.

This program is NOT free software; you canNOT redistribute it and/or modify it.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;

package Trx::Response;

use Moose;

=head1 Telereleve::COM::Trx::Response

=head1 NAME

Telereleve::COM::Trx::Response - Messages lus avec tout ce qui va bien

=head2 Remarque

Ne s'utilise pas directement. Réponse renvoyée par read_message.

=cut

=head2 raw_frame

Trame brute

=cut
has 'raw_frame' => (
    is => 'rw',
);

=head2 message

Message reçu, si le code erreur est à 0

chaîne héxa

=cut
has 'message' => (
    is => 'rw',
);

=head2 data

Array de entier, si le code erreur est à 0


=cut
has 'data' => (
    is => 'rw',
);

=head2 RSSI

RSSI trouvé dans la trame, si le code erreur est à 0

entier

=cut
has 'RSSI' => (
    is => 'rw',
);

=head2 timestamp

Timestamp trouvé dans la trame, si le code erreur est à 0

entier

=cut

has 'timestamp' => (
    is => 'rw',
);

=head2 error_code

Error code renvoyé par le module

entier

=cut
has 'error_code' => (
    is => 'rw',
);

=head2 clean_message

    00 80 FF 30 98 00  4E F0  4B    46 87 26 06 93 99 99 10 03 B4 10 00 02 78 00 0A 03 2D 5C F3 BB 14 9D 22 FF A4 1A

    00 80 FF 30 98 40

    00    80 FF    protocole base

    30:    classe 30

    98: réponse à une commande de lecture 18 -> 98

    40: error code

    4E: F0 timestamp

    4B: rssi


=cut
sub clean_message {
    my ($self,$raw_mode) = @_;
    my ($smb,$classe,$response_id,$code_retour,$timestamp,$rssi,$message) 
        = unpack("H6 H2 H2 H2 H4 H2 H*", pack("C*", @{$self->raw_frame()})) ;
    $self->RSSI(hex($rssi));
    $self->timestamp(hex($timestamp));
    $self->error_code(hex($code_retour));
    $self->message(uc $message);
    if ($raw_mode =~ m/ON/i && $message) {
        my $longueur =  length($message)/2;
        $self->message(uc( sprintf("%02X",$longueur).$message));
    }
    my @data = map{ hex($_)} $self->message() =~ m/[0-9A-Fa-f]{2}/g;
    $self->data(\@data);
}

no Moose;
__PACKAGE__->meta->make_immutable;

1; # End of Telereleve::COM::Trx
