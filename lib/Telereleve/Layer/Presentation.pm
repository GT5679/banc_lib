package Telereleve::Layer::Presentation;

use Moose::Role;

use Carp;
use feature qw(say);
use Digest::CMAC;
use Crypt::Rijndael;
use integer;
use Time::Piece;
use Time::Local;
use Data::Dumper;

#gestion des formats de trame: exchange/download
with 'Telereleve::Helper::Formats',
    'Telereleve::Layer::Liaison';

=head1 NAME

Telereleve::Layer::Presentation - Couche de présentation / L6

=head1 VERSION

Version 0.50

=cut

our $VERSION = '0.5';

=head1 SYNOPSIS

Role Moose à utiliser à travers une classe spécialisée, telle que

 L<Telereleve::Application|telereleve-application.html>

Actions de Telereleve::Layer::Presentation

=over 4
 
=item *
 
Compose la trame de présentation correspondant au niveau 6 à partir des données reçues des niveaux supérieurs.

=over 4

=item *

reçoit un message sous forme hexadécimal

=item *

le pack (objet binaire)

=back


=item *

Chiffre le cas échéant.

=over 4

=item *

le crypte (ou pas)

=item *

le renvoie sous forme de chaîne héxa

=back    

=back

Pour l'analyse d'une trame reçue, prendre la même procédure, mais en partant de la fin.

    
=head2 Exemples dans un sens, et autre
    
    use Telereleve::Application::Command;
    
    my $appli = Telereleve::Application::Command->new(mainconfig_file => 'campagne.cfg');
    $appli->crypte("message en hexa");
    
    print $appli->crypted();
    
ou à partir d'une trame reçue.

    use Telereleve::Application::Command;
        
    my $appli = Telereleve::Application::Command->new(mainconfig_file => 'campagne.cfg');
    
    $appli->decrypte("$message en hexa");
    
    print $appli->decrypted

=head2 Attributes

Remarque:
    
    Tous les attributs sont initialisables lors de la création de l'objet.

=over 4

=item version

dépend du type de trame

voir la SFTD LAN pour de plus amples informations.

    types: exchange ou download ou nfc ou local

=item has_wts

dépend du champ TStamp

Détermine si la trame contient un champ timestamp
        
Le format de la trame: exchange/download

provient de L<Telereleve::Application|telereleve-application.html>

permet de choisir le template selon le type de la trame
        
=item keysel

type: B<entier>

    initialisé par la lib application
    
=item cpt 

type: B<entier>    

Initialisé par la lib application ou retrouvé lors de l'analyse d'une trame reçue.

=item timestamp

    initialisé par la lib application ou retrouvé lors de l'analyse d'une trame reçue.

    Si la valeur n'est pas initialisée, prend l'heure courante 
    
Méthodes

    vide le timestamp 
    $appli->clear_timetsamp();

    vérifie si a un timestamp
    $appli->has_timestamp    
    

=item kenc

Issu du fichier de configuration.

=item kmac 

Issu du fichier de configuration
    
Les attributs suivants sont utilisés par les trames download

=item dwnBNum

initialisé par l'appli

=item hashklog

généré
    
=back

=cut

has 'version' => ( 
    is => 'rw',
    default => 0,
    predicate => 'has_version',
);

has '_exversion_value' => ( 
    is         => 'rw', 
    default => 0,
);
 
has '_downversion_value' => ( 
    is         => 'rw', 
    default => 0,
); 

has '_nfcversion_value' => ( 
    is         => 'rw', 
    default => 0,
); 

has 'NFCversion' => (
    is => 'rw',
    default => 0,
);
 
has 'wts' => ( 
        is => 'rw',
        default => '1',
        predicate => 'has_wts',
        );
        
has 'Opr' => ( 
        is => 'rw',
        isa => 'Str',
        default => '01',
);
        
has 'App' => ( 
    is => 'rw',
    isa => 'Str',
    default => '00',
);

=head2 keysel

Clef de la kenc à utiliser pour le chiffrement.

A chaque changement, fait appel à </update_kenc>
        
=cut        
has 'keysel' => ( 
    is => 'rw', 
    predicate => 'has_keysel',
    #trigger => \&update_kenc,
);

=head2 timestamp

Timestamp des trames, voir sftd

=cut
has 'timestamp' => ( 
        is => 'rw',
        predicate => 'has_timestamp',
        clearer => 'clear_timestamp'
 );
 
=head2 kenc

kenc

    kenc courante
    
kencs

    tableau des kencs disponibles
    Rempli à partir du fichier de campagne

    my $kenc_courante = $appli->get_kenc(1);
    
    $appli->all_kencs();
    
    $appli->set_kenc(1, 'kenc chaine hexa');
    
    $appli->set_kenc(1, 'kenc chaine hexa');
    
    $appli->has_kencs();
    
    $appli->count_kencs();
    
    $appli->has_no_kencs();
    
=cut
has 'kenc' => ( is => 'rw' ); 
has 'kencs' => (
        traits  => ['Array'],
        is      => 'ro',
        isa     => 'ArrayRef[Str]',
        default => sub { [] },
        handles => {
            all_kencs    => 'elements',
            add_kenc     => 'push',
            get_kenc     => 'get',
            set_kenc     => 'set',
            count_kencs  => 'count',
            has_kencs    => 'count',
            has_no_kencs => 'is_empty',
        },
    );


has 'hashkenc' => ( is => 'rw' );

=head2 hashkenc_error

Initialisé en cas d'erreur lors du contrôle de hashkenc à la réception d'une trame.

=cut
has 'hashkenc_error' => ( is => 'rw', default => 0 );


has 'kmac' => ( is => 'rw' );
has 'kmacs' => (
        traits  => ['Array'],
        is      => 'ro',
        isa     => 'ArrayRef[Str]',
        default => sub { [] },
        handles => {
            all_kmacs    => 'elements',
            add_kmac     => 'push',
            get_kmac     => 'get',
        set_kmac     => 'set',
            count_kmacs  => 'count',
            has_kmacs    => 'count',
            has_no_kmacs => 'is_empty',
        },
    );
has 'hashkmac' => ( is => 'rw' );

=head2 hashkmac_error

Initialisé en cas d'erreur lors du contrôle de hashkmac à la réception d'une trame.

=cut
has 'hashkmac_error' => ( is => 'rw', default => 0 );

        
#partie download        
has 'klog' => ( is => 'rw' );         
has 'hashklog' => ( is => 'rw' ); 
has 'downbnum' => ( is => 'rw' );  

#partie nfc/local
has 'kmob' => ( 
    is => 'rw',
    
); 
has 'hashkmob' => ( is => 'rw' );
has 'tx_freq_offset' => ( is => 'rw' );

has 'epoch' => ( is => 'rw' );

=head2 hashkmob_error

Initialisé en cas d'erreur lors du contrôle de hashkmob à la réception d'une trame.

=cut
has 'hashkmob_error' => ( is => 'rw', default => 0 );

has 'ack' => ( is => 'rw' );  
has 'nfc_uid' => (
    is => 'rw',
    #default => hex(0xf000000a)
);



=head2 Tableau des templates pour pack

Pour chacun des formats de trame: exchange ou download, le tableau détermine le template utilisé par la commande perl pack pour générer ou décomposer une chaine binaire.

Données issues de la SFTD LAN.

Méthodes

    get_presentation_template(format);
    
    presentation_template_pairs
    
        Permet d'obtenir la liste des templates disponibles

va de pair avec presentation_length, quelques lignes plus bas,

La longueur de la trame est égale à la longueur de ces différents éléments fixes + la longueur (variable) du message

Les éléments fixes ayant besoin d'être depackés de façon précise, on obtient un longueur qui doit être reportée dans le hash gérant les longueurs.

Le tout est utilisé par la méthode interne _get_total_length qui s'occupe de déterminer la longueur de la trame à crypter.

=cut

has 'presentation_template' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef[Str]',
  default   => sub { {
        'exchange'     => "H2 H4",
        'download'     => "H2 H6",
        'nfc'         => "",        
        'local'        => "",            
  } },
  handles   => {
      get_presentation_template     => 'get',
      presentation_template_pairs   => 'kv',
  },
);

=head2 Tableau des longueurs de trame présentation

Longueurs avec le timestamp, mais sans le message (qui est de longueur variable)

Si le timestamp est vide: diminuer la longueur de 2 octets.
    
nécessaire pour le calcul des ktruc, voir schema 8.1
    
Longueurs en octet début 2014

    exchange = 3
        1 ctrl
        2 cpt
        
        4 L6Hashkenc
        2 L6Tstamp, si pas de tstamp, enlèvera 2 octets
        2 L6Hashkmac
    
    local (nfc) = 1
        1 version
    
    download = 4
        1 version
        3 downbnum
        
        4 L6Hshklog

Méthodes
    
    get_presentation_length
        Paramètre: exchange ou download
    
    presentation_length_pairs

=cut
has 'presentation_length' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef[Str]',
  default   => sub { {
        'exchange' => 11,
        'download' => 4, 
        'nfc' => 0, 
        'local' => 0,             
  } },
  handles   => {
      get_presentation_length     => 'get',
  },
);

=head2 iv_template

Templates pour la génération des init value pour le cryptage aes. Les valeurs proviennent de la SFTD LAN.
    
dépend du format utilisé (exchange ou download)
    
Methodes disponibles:
    
    get_iv_template
        
        paramètres: exchange ou download
    
    pairs_iv_template
        
        Liste des templates

=cut
has 'iv_template' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef[Str]',
  default   => sub { {
        'exchange'     => "H2 H2 H4 H12 H2 H2",            
        'download' => "H6 H6" 
  } },
  handles   => {
      get_iv_template     => 'get',
      pairs_iv_template   => 'kv',
  },
);

=head2 aes_callback et vector_callback

AVERTISSEMENT:

    Attributs à utiliser avec Prudence, Précaution, Parcimonie, Circonspection et mieux encore si vous savez et comprenez ce que vous faites. Dans le cas contraire, il est préférable de s'attaquer au préalable à des choses plus faciles.

Ces attributs permettent de définir les éléments nécessaires aux cryptage d'une trame selon son type et sans avoir à modifier tout le code à chaque fois.

le callback par défaut est _init_crypt_exchange en union libre avec _get_exchange_init_vector.

Le callback pour un type de trame est défini dans la librairie correspondante.

Méthodes selon les types de trames:

=over 4

=item exchange

    _init_crypt_exchange
    _get_exchange_init_vector

=item  local
    
    _init_crypt_nfc
    _get_nfc_init_vector

    devrait s'appeler local

=item download

    _get_download_init_vector
    _init_crypt_download

=back

Ces méthodes sont initialisées dans les librairies de haut-niveau correspondantes.

    Telereleve::Application::Download
    
    has '+aes_callback' => (
        default => sub { \&Telereleve::Layer::Presentation::_init_crypt_download } 
    );    
    
    Telereleve::Application::Local

    has '+aes_callback' => (
        default => sub { \&Telereleve::Layer::Presentation::_init_crypt_nfc } 
    );
    
Pour gérer un cryptage différent (clé utilisée, paramètres du vecteur initial spécifique, etc ), il faut créer deux méthodes  sépécifiques. Le copier/coller est autorisé, la relecture et les tests sont obligatoires.

Nommage: _init_crypt_portnawak et _get_portanawak_init_vector

Puis l'utiliser ainsi:

    has '+aes_callback' => (
        default => sub { \&Telereleve::Layer::Presentation::_init_crypt_portnawak } 
    );
    
    ou
    
    aes_callback(sub { \&Telereleve::Layer::Presentation::_init_crypt_portnawak });

Ca devrait fonctionner ;)

Bien secouer avant usage, si des boulons tombent, resserrer et recommencer!

=cut
has 'aes_callback' => (
    traits  => ['Code'],
    is      => 'rw',
    isa     => 'CodeRef',
    default =>  sub {
        \&_init_crypt_exchange
    },
    handles => {
      aes_init => 'execute_method',
    },
);

has 'vector_callback' => (
    traits  => ['Code'],
    is      => 'rw',
    isa     => 'CodeRef',
    default =>  sub {
        \&_get_exchange_init_vector
    },
    handles => {
      vector_exec => 'execute_method',
    },
);

=head2 attributs  pour le chiffrement

=over 4

=item ctr

    objet Crypt::Rijndael

=item ciphseq

    Indice de la suite de chiffrement.
    
    0 par défaut
    
    Mais on peut modifier la valeur (pour ceux qui aiment prendre des risques)

=item iv

=back

=cut
has 'ctr' => (
    is => 'rw',
    isa => 'Crypt::Rijndael',
);

has 'ciphseq' => (
    is => 'rw',
    default => 0,
);

has 'iv' => (
    is => 'rw',
);


=head2 cpt

Compteur

Lors du cryptage d'une trame, la valeur est extraite de la conf ou initialisée à la valeur souhaitée, incrémentée ou réinitialisée.

Lors du décryptage, l'information est extraite de la trame reçue.
    
Méthodes:
    
=head3    set_cpt

donne au compteur la valeur souhaitée
    
=head3    inc_cpt

incrémente de 1
    
=head3increment_cpt 

incrémente de 1
    
=head3    reset_cpt 

réinitialise la valeur à 0

=cut

has 'cpt' => (
  traits  => ['Counter'],
  is      => 'ro',
  isa     => 'Num',
  default => 0,
  handles => {
      inc_cpt   => 'inc',
      increment_cpt   => 'inc',
      reset_cpt => 'reset',
      set_cpt   => 'set',
  },
);

=head2 Attributs concernant les données

message, avant cryptage

crypted, après cryptage

decrypted, après décryptage

=cut

#message avant cryptage: hexa
has 'message' => ( is => 'rw',
        predicate => 'has_message');
        
=head2 decrypted

Trame applicative (L7) decryptée au format hexadécimal
        
=cut        
has 'decrypted' => ( is => 'rw',
    predicate => 'has_decrypted'); #message non crypté

        
=head2 crypted

Trame applicative (L7) cryptée au format hexadécimal
        
=cut        
has 'crypted' => ( is => 'rw',
        predicate => 'has_crypted'
        ); #message crypté en hexa

has '_message_aes' => ( is => 'rw',
        ); #message brut crypté en hexa
        

=head1 SUBROUTINES/METHODS

=head2 _set_version

En fonction du type trame (exchange ou download) change la version utilisée

private comme sont _ initial l'indique.

=cut

sub _set_version {
    my ( $self, $format) = @_;
    confess( { error => 0x61, message => "format is missing (exchange or download)"}) unless $format;
    $self->version($self->_exversion_value) if  $format eq "exchange";
    $self->version($self->_downversion_value) if $format eq "download";
    $self->NFCversion($self->_nfcversion_value) if $format eq "nfc" || $format eq "local";    
    confess({ error => 0x61, message => "Unknown format, version missing, check your format [$format]" } ) unless $self->has_version;
}

=head2 crypte

Fonction principale.

Génère une trame complète de la couche de présentation (L6, voir sftd lan, 6.1)
    
Sans chiffrement pour le ping

Pas de chiffrement non plus si la kenc est égale à 0

Paramètre:

    message: string hexa

=cut

sub crypte {
    my ($self,$message) = @_;
    my $error_crypte = "part of byte missing : cannot process message : " ; 
 
    if (length($message) > 0 && (length($message) % 2) == 1) {
    $error_crypte = $error_crypte . length($message);
        $self->logger->fatal($error_crypte);
        confess({ error => 0x61, message => $error_crypte});
    }
    $self->_set_version(  $self->format() );
    $self->logger->debug("L2 before ciphering: $message");
    if ($self->interface() eq "lan") {
        $self->format() && $self->format() eq "exchange" ? 
                            $self->_crypte_exchange($message) : 
                            $self->_crypte_download($message);    
    } else {
        $self->_crypte_nfc($message);
    }
    return 0;
}


=head2 decrypte

Analyse de la partie L6 d'une trame, correspond pour l'essentiel, mais pas seulement, au déchiffrement d'un message reçu au format hexa.
    
Le message provient de la couche liaison (L2) qui a extrait les éléments de la trame brute.

Pour les trames instping et instpong, pas de déchiffrement.

Si la keysel est à 0,  pas de déchiffrement non plus.

Parametre:

    message: string hexa

Retourne:

    0

En cas de souci, le système se confesse, la confession est un hashref.

=cut

sub decrypte {
    my ($self,$message) = @_;
    confess({ error => 0x61, message => "Missing message"}) unless $message;
    $self->_set_version(  $self->format() );
        $self->message($message);
    $self->logger->trace("uncipher : begin");
    if ($self->interface() eq "lan") {
        return $self->format() && $self->format() eq "exchange" ? $self->_decrypte_exchange() : $self->_decrypte_download();
    } else {    
        return $self->_decrypte_nfc($message);
    }
}

######################################
#Libraires privées

sub _crypte_nfc {
    my ($self,$message) = @_;
    confess({ error => 0x61, message => "No message to cipher"}) unless defined($message);
    my $liaison_template = $self->get_liaison_template($self->format());
    my $template = $self->get_presentation_template($self->format());    
    my $cmac_object = Digest::CMAC->new(  pack("H*", substr($self->kmob,0,32) ) );
    
    #my $message_aes =    $self->kmob =~ m/^0+$/ ?
    #                            $message :
    #                            $self->_get_aes_ctr_string_ciphseq($message);
    my $message_aes = $self->_get_aes_ctr_string_ciphseq_nosel($message);
    
    
    
    $self->logger->trace("Ciphered Message: $message_aes" );
    $self->_get_total_length($message_aes);
    my $message_length = length($message_aes);    #pour le template pack
    confess({ error => 0x61, message => "missing length"}) unless $self->length();

    confess({ error => 0x61, message => "missing cfield"}) unless $self->cfield;

    $self->logger()->trace("length: " . $self->length() . " cpt: " . $self->cpt 
                    . " cfield: " . $self->cfield 
                    . " version: " . $self->version);
    
    
    
    #my $plaintext =  pack( $liaison_template->[0].$template . "H" .$message_length,
    #                        sprintf("%02x",$self->length()),
    #                        sprintf("%04x",$self->cpt),
    #                        $self->cfield,
    #                        sprintf("%02x",$self->version),
    #                        $message_aes
    #                        );
                            
                            
    my $plaintext =  pack( "H*",$self->nfc_uid  
                            . sprintf("%02X",$self->length())
                            . sprintf("%04X",$self->cpt)
                            . $self->cfield
                            . sprintf("%02X",$self->version)
                            . $message_aes
                            );

    $self->logger()->debug(  "plaintext : " . unpack("H*",$plaintext)  ) if $plaintext;
    $cmac_object->add($plaintext);    
    if($self->kmob =~ m/^0+$/ ) {
        $self->hashkmob( "00000000"  );
    } else {
        my $hashkmob = $cmac_object->hexdigest;
        $self->hashkmob( substr($hashkmob,0,8)  );
        $self->logger()->debug("hashkmob : $hashkmob");
    }    
    $self->crypted(  $message_aes
                    . $self->hashkmob()
                    );            
}

sub _crypte_exchange {
    my ($self,$message) = @_;
    $self->logger()->debug("begin ");    
    
    my $liaison_template = $self->get_liaison_template($self->format());
    my $template = $self->get_presentation_template($self->format());

    $self->logger->trace("wize_rev : " . $self->wize_rev());
    $self->logger->trace("template : " . $template);
    
    #choisir ou non un tiemstamp, dépend de la conf du fichier de campagne
    if ($self->wts == 1 &&  !$self->has_timestamp) 
    {
        $self->timestamp( $self->epoch_timestamp());
    }


    ############################################################################
    # ciphering
    
    #INSTPING/PONG, cas spécial, sans scryptage et avec la kmac au lieu de la kenc
    if ($self->application() =~ m/INSTPONG/)
    {
        $self->logger->debug("[cipher] INSTPONG frame is plain text" );
    }
    else 
    {
        $self->logger->debug("[cipher] kenc used : " . $self->kenc() );    
    }
    

    my $message_aes = $self->kenc() =~ m/^00000+$/ ?
                                $message :
                                $self->_get_aes_ctr_string_ciphseq($message);

    $self->logger->debug("[cipher] after ciphering : [$message_aes]");

    ############################################################################
    # 
        
    $self->_get_total_length($message_aes);
    my $message_length = length($message_aes);    #pour le template pack
    
    my $ctrl = sprintf "%02X", ( ($self->version << 5) + ($self->wts << 4) + $self->keysel);

    my $plaintext;
    if ($self->wize_rev() == '0.0')
    {
        $plaintext =  pack( $liaison_template->[0].$template . "H" .$message_length,
                            sprintf("%02X",$self->length()),
                            $self->get_appli_hexa($self->application),
                            sprintf("%04X", $self->_reverse_endian(hex($self->id_fabricant))),
                            $self->reverse_afield($self->id_ddc),
                            $self->ci_field,
                            $ctrl,
                            sprintf("%04x",$self->cpt),
                            $message_aes
                            );

    }
    else {
        $plaintext =  pack( $liaison_template->[0].$template . "H" .$message_length,
                            sprintf("%02X",$self->length()),
                            $self->get_appli_hexa($self->application),
                            sprintf("%04X", $self->_reverse_endian(hex($self->id_fabricant))),
                            $self->reverse_afield($self->id_ddc),
                            $self->ci_field,
                            $ctrl,
                            #$self->Opr,
                            sprintf("%02X",$self->Opr()),
                            sprintf("%04x",$self->cpt),
                            $self->App,
                            $message_aes
                            );
        $self->logger()->trace(  "L6NetwId : " . $self->Opr() . " (" . sprintf("0x%02X",$self->Opr()) .")" ); 

    }
    $self->logger()->trace(  "length : " . $self->length() );    
    
    ############################################################################
    #calcul du hashkenc
    my $hashkenc_object = Digest::CMAC->new(  ( $self->application() =~ m/INSTP[IO]NG/
                                                || $self->keysel == 0)
                                                    ? pack("H*",  substr($self->kmac,0,32)) : 
                                                      pack("H*",  substr($self->kenc,0,32))
                                        );

    my $haskenc_FRM;
    if ($self->application() =~ m/INSTPONG/)
    {
        $self->logger->debug("[hashkenc] INSTPONG frame doesn't use hashkenc" );
    }
    else 
    {
        if ($self->wize_rev() == '0.0')
        {
            $haskenc_FRM = $plaintext,
        }
        else
        {
            $haskenc_FRM = pack("H*",
                    sprintf("%04X", $self->_reverse_endian(hex($self->id_fabricant)))
                    .$self->reverse_afield($self->id_ddc)
                    .sprintf("%04X",$self->cpt)
                    ."000000000000"
                    .$message_aes);
        }

        $hashkenc_object->add($haskenc_FRM);
        $self->logger->debug("[hashkenc] frame used : [" . unpack("H*", $haskenc_FRM) . "]" );
        $self->logger->debug("[hashkenc] kenc used : " . ( ($self->keysel == 0)?$self->kmac():$self->kenc() ) );

        if ($self->kenc =~ m/^000+$/) 
        {        
            $self->hashkenc( "00000000"  );    
        } else 
        {
            $self->hashkenc( substr($hashkenc_object->hexdigest,0,8)  );
        }
        
        $self->logger->debug("[hashkenc] HashKenc : " . $self->hashkenc());
    }                            

    ############################################################################

    if ($self->application() =~ m/INSTPONG/)
    {
        #ajout de epoch et de tx_freq_offset  à la trame
=pod
        if ( ! defined $self->epoch() ) 
        {
            $self->epoch(time() - timelocal(0,0,0,1,0,2013));
        }
        else 
        {
            if ( $self->epoch() == 0) 
            {
                $self->epoch(time() - timelocal(0,0,0,1,0,2013));
            }
        }
=cut
        $self->epoch(time() - timelocal(0,0,0,1,0,2013));
        
        $self->logger->trace("[EPOCH] ".$self->epoch() );
        $plaintext .=      pack("H8 H4", $self->epoch(), $self->tx_freq_offset() );
    }
    else 
    {
        $self->logger->trace("[TStamp] ".$self->timestamp() );
        #ajout hashkenc et timestamp à la trame
        $plaintext .=  $self->wts == 1 ? 
                            pack("H8 H4", $self->hashkenc(),$self->timestamp()) :
                            pack("H8", $self->hashkenc())
                            ;
    }
                            
    ############################################################################
    #calcul du hashkmac                        
    my $hashkmac_object = Digest::CMAC->new(  pack("H*", substr($self->kmac,0,32)));
    
    my $hashkmac_FRM;

    if ($self->wize_rev() == '0.0')
    {
        $hashkmac_FRM = $plaintext
    }
    else 
    {    
        $hashkmac_FRM = pack("H*",
                sprintf("%04X", $self->_reverse_endian(hex($self->id_fabricant)))
                .$self->reverse_afield($self->id_ddc)
                ."0000000000000000"
                . $ctrl
                #. $self->Opr()
                . sprintf("%02X",$self->Opr())
                . sprintf("%04X",$self->cpt)
                . $self->App()
                . $message_aes
                );

        if ($self->application() =~ m/INSTPONG/)
        {
            $hashkmac_FRM .= pack("H*",
                    sprintf("%08X",$self->epoch())
                    . sprintf("%04X",$self->tx_freq_offset())
                    );
        }
        else {
            $hashkmac_FRM .= pack("H*",
                    $self->hashkenc()
                    . $self->timestamp()
                    );    
        }
    }
    
    $hashkmac_object->add($hashkmac_FRM);
    $self->logger->debug("[hashkmac] frame used :  [" . unpack("H*", $hashkmac_FRM) . "]" );
    $self->logger->debug("[hashkmac] kmac used : " . $self->kmac() );
    
    if($self->kmac =~ m/^0+$/) {
        $self->hashkmac( "0000"  );
    } else {
        $self->hashkmac( substr($hashkmac_object->hexdigest,0,4)  );
    }        
    $self->logger->debug("[hashkmac] HashKmac : " . $self->hashkmac());
    
    ############################################################################
    #fin    
    if ($self->wize_rev() == '0.0')
    {
        if ($self->application() =~ m/INSTPONG/)
        {
            $self->crypted( $ctrl 
                            . sprintf("%04X",$self->cpt)
                            . $message_aes
                            . sprintf("%08X",$self->epoch())
                            . sprintf("%04X",$self->tx_freq_offset())
                            . $self->hashkmac()
                            );
        }
        else {
            $self->crypted( $ctrl 
                            . sprintf("%04X",$self->cpt)
                            . $message_aes
                            . $self->hashkenc()
                            . ($self->wts == 1 ? $self->timestamp() : '')
                            . $self->hashkmac()
                            );
        }
    }
    else {
        if ($self->application() =~ m/INSTPONG/)
        {
            $self->crypted( $ctrl 
                            #. $self->Opr()
                            . sprintf("%02X",$self->Opr())
                            . sprintf("%04X",$self->cpt)
                            . $self->App()
                            . $message_aes
                            . sprintf("%08X",$self->epoch())
                            . sprintf("%04X",$self->tx_freq_offset())
                            . $self->hashkmac()
                            );
        }
        else {
            $self->crypted( $ctrl 
                            #. $self->Opr()
                            . sprintf("%02X",$self->Opr())
                            . sprintf("%04X",$self->cpt)
                            . $self->App()
                            . $message_aes
                            . $self->hashkenc()
                            . $self->timestamp()
                            . $self->hashkmac()
                            );
        }        
    }
    $self->logger->debug("end => message : " . $self->crypted());            
    return 0;
}


=head2 midnight_seconds

Fonction utilitaire.

Paramètres:

    timestamp (optionnel)

Retourne:

    chaîne hexa, nombre de double secondes depuis minuit (UTC).


=cut
sub midnight_seconds { 
    my @time = gmtime($_[0] || time); 
    my $secs = ($time[2] * 3600) + ($time[1] * 60) + $time[0]; 
    return sprintf("%04X",int($secs/2)); 
}

=head2 epoch_timestamp

Timestamp utilisé dans les trames

Paramètre:

    aucun

Retourne:

    retourne les 2 bits de poids faibles du timestamp DdC sous forme de chaine hexa
    
=cut
sub epoch_timestamp { 
    my ($self) = @_;
    my $gt =  gmtime(time);
    my $dt = $gt->strftime("%Y-%m-%d %H:%M:%S");    
    my $hexa_secondes = $self->date_to_ddc_time($dt);
    return substr($hexa_secondes,-4);
}


sub _crypte_download {
    my ($self,$message) = @_;
    my $msg_length = length(pack("H*" ,$message));
    confess({ error => 0x63, message => "Frame length must be 210 bytes and not : $msg_length"}) if  $msg_length != 210;
    my $template = $self->get_presentation_template($self->format());
    
    $self->logger->trace("wize_rev : " . $self->wize_rev());
    $self->logger->trace("template : " . $template);
    
    
    $self->logger->debug("[cipher] klog used : " . $self->kenc() ); 
    
    my $message_aes = $self->kenc() =~ m/^00000+$/ ?
                                $message :
                                $self->_get_aes_ctr_string_ciphseq($message);
    $self->logger->debug("[cipher] after ciphering : [$message_aes]");
    
    $self->_get_total_length($message_aes);
    my $message_length = length($message_aes);
    
    ############################################################################
    #Ajout du hashklog
    my $cmac_object = Digest::CMAC->new( pack("H*", substr($self->klog,0,32)) );
    my $plaintext =  pack( "H6".$template . "H" .$message_length,
                            sprintf("%06X",$self->download_id()),
                            sprintf("%02X",$self->version),
                            sprintf("%06X",$self->downbnum),
                            $message_aes
                            );
    $self->logger->debug("[hashklog] frame used : [" . unpack("H*", $plaintext) . "]" );
    $self->logger->debug("[hashklog] klog used : " . $self->klog() );
    $cmac_object->add($plaintext);                
    $self->hashklog( substr($cmac_object->hexdigest,0,8)  );
    $self->logger->debug("[hashklog] HashKlog : " . $self->hashklog());
    ############################################################################
    #fin
    $self->crypted(  
                    sprintf("%02X",$self->version)
                    . sprintf("%06X",$self->downbnum)
                    . $message_aes
                    . $self->hashklog()
                    );                
    return 0;
}

sub _decrypte_exchange {
    my ($self) = @_;
    $self->logger()->debug("begin");
    confess({ error => 0x62, message => "missing message "}) unless $self->has_message;

    my $binary_string = pack "H*", $self->message;

    my $byte1;
    my $opr;
    my $cpt;
    my $app;
    my $reste;
        
    ($byte1,$reste) = unpack("H2 H*", $binary_string);
    
    $self->analyse_ctrl($byte1);
    
    #$self->version(hex($byte1) >> 5);
    confess({ error => 0x62, message => "Missing Version "}) unless defined($self->version);
    
    my $wize_rev = '0.0';
    if ($self->version == 0 )
    {
        $wize_rev = '0.0';
    }
    elsif ($self->version == 1 )
    {
        $wize_rev = '1.2';
    }
    else
    {
        confess({ error => 0x62, message => "Unknown Wize revision"});
    }

    $self->_update_wize_rev($wize_rev);
    
    #$self->wts((hex($byte1) & 0x10) >> 4);
    #$self->keysel( hex($byte1) & 0x0f  );
    $self->kenc( $self->get_kenc($self->keysel) );
    
    my $template = $self->get_presentation_template($self->format());
    

    $self->logger->trace("wize_rev : " . $self->wize_rev());
    $self->logger->trace("template : $template");
    
    if ($self->wize_rev == '0.0') {
        #my ($byte1, $cpt,$reste);
        ($byte1,$cpt,$reste) = unpack($template . "H*", $binary_string);
        $self->App(0);
        $self->Opr(0);
    }
    else {
        #my ($byte1,$opr, $cpt, $app, $reste);
        ($byte1,$opr,$cpt,$app,$reste) = unpack($template . "H*", $binary_string );
        
        #my $operid = sprintf("%d",$opr);
        my $operid = hex($opr);
        
        $self->logger->trace("L6NetwId : " . $operid . " (" . sprintf("0x%02X",$operid) .")" );
        
        #sprintf("%02X",$self->Opr()),
        #$self->logger()->trace(  "L6NetwId : " . $self->Opr() . " (" . sprintf("0x%02X",$self->Opr()) .")" ); 
        
        if ($operid <= $self->count_kmacs() ) 
        {
            $self->logger->trace("Changing Kmac index to : " . $operid);
            $self->kmac( $self->get_kmac($operid) );
        }
        $self->App($app);
        #$self->Opr($opr);
        $self->Opr($operid);
    }

    $self->logger->trace("wts : " . $self->wts());
    $self->logger->trace("keysel : " . $self->keysel());
    $self->logger->trace("cpt : $cpt");
    
    $self->set_cpt(hex($cpt));
    
    my @reste = split//,$reste;
    my ($hashkenc,$tstamp,$hashkmac);
    
    $self->hashkmac(  join "", splice(@reste, -4,4) );
    $self->timestamp( $self->wts == 1 ? (join"",splice(@reste, -4,4)) : '' );
    $self->hashkenc( join "",splice(@reste, -8,8) );


    if ($self->wize_rev() == '0.0') 
    {
        $self->logger->debug("hashkmac: " . $self->hashkmac());
        $self->check_hashkmac($self->message_binary);
        
        $self->logger->debug("hashkenc: " . $self->hashkenc());
        $self->check_hashkenc( $self->message_binary );
    }
    else 
    {
        my $FRM;
        my $f1;
        my $f2;
        my $f3;
        my $MAfields;
        ($f1, $f2, $MAfields, $f3, $FRM) = unpack("H2 H2 H16 H2 H*", $self->message_binary);
        
        $self->logger->debug("hashkmac: " . $self->hashkmac());
        $self->check_hashkmac(pack("H*", $MAfields . "0000000000000000" . $FRM));
        
        $self->logger->debug("hashkenc: " . $self->hashkenc());
        $self->check_hashkenc(pack("H*", $MAfields . $cpt . "000000000000" . $reste . "0000"));
        #$self->check_hashkenc(pack("H*", $MAfields . $cpt . "000000000000" . $FRM ));
    }
    
    my $decrypted_message = $self->kenc() =~ m/^00000+$/ ?
                                            join "",@reste :
                                            $self->_get_string_from_aes_ctr_ciphseq(join "",@reste);
    $self->decrypted($decrypted_message);
    $self->logger->debug("end => message : " . $self->decrypted());    
    return $self->decrypted();
}

sub check_hashkenc {
    my ($self,$frame) = @_;
    if ($self->keysel == 0) 
    {
            $self->kenc($self->kmac());
    }
    if ($self->kenc() =~ m/^000+$/ )
    {
            $self->logger->debug("kenc is 0. Nothing to do." );
            return;
    }
    $self->logger->debug("kenc used : " . $self->kenc() );
    
    my $cmac_object = Digest::CMAC->new(  pack("H*", substr($self->kenc,0,32)) );
    my ($crypted_message) = unpack("H*",$frame);
    my @crypted_message = split//,$crypted_message;
    
    $self->logger->debug("Full message : $crypted_message");
    splice(@crypted_message, ($self->wts == 1 ? -20 : -16));
    my $plaintext = join "", @crypted_message;
    
    $self->logger->debug("frame used for hashkenc [$plaintext]");
    $cmac_object->add( pack("H*",$plaintext));    
    my $hashkenc_hex = $cmac_object->hexdigest;
    my $hashkenc_calculee = substr($hashkenc_hex,0,8);
    
    $self->logger()->debug("hashKenc received : ". $self->hashkenc ." <=>  $hashkenc_calculee (computed hashkenc) ($hashkenc_hex) "   );
    if (lc($self->hashkenc) ne lc($hashkenc_calculee) ) {
        $self->logger->error("hashkenc check failed : ". $self->hashkenc ." <=>  $hashkenc_calculee (computed hashkenc) ($hashkenc_hex) ");
        $self->hashkenc_error(1);
    }    
}

sub check_hashkmac {
    my ($self,$frame) = @_;
    if ($self->kmac() =~ m/^000+$/ )
    {
            $self->logger->debug("kmac is 0. Nothing to do." );
            return;
    }
    $self->logger->debug("kmac used : " . $self->kmac() );
    
    my $cmac_object = Digest::CMAC->new(  pack("H*", substr($self->kmac,0,32)) );
    my ($crypted_message) = unpack("H*",$frame);
    my @crypted_message = split//,$crypted_message;
    
    $self->logger->debug("Full message : $crypted_message");
    splice(@crypted_message, -8,8);
    my $plaintext = join "", @crypted_message;
    
    $self->logger->debug("frame used for hashkmac [$plaintext]");
    $cmac_object->add( pack("H*",$plaintext));    
    my $hashkmac_hex = $cmac_object->hexdigest;
    my $hashkmac_calculee = substr($hashkmac_hex,0,4);
    
    $self->logger->debug("hashKmac received : ". $self->hashkmac ." <=>  $hashkmac_calculee (computed hashkmac) "   );
    if (lc($self->hashkmac) ne lc($hashkmac_calculee) ) {
        $self->logger->error("hashkmac check failed : hashKmac received : ". $self->hashkmac ." <=>  $hashkmac_calculee (computed hashkmac) ");
        $self->hashkmac_error(1);
    }    
}

sub _decrypte_download {
    my ($self) = @_;    confess({ error => 0x61, message => "message missing"}) unless $self->has_message;
    my $template = $self->get_presentation_template($self->format());    
    #decrypte pas le download
    return $self->message;
}

sub _decrypte_nfc {
    my ($self) = @_;    
    confess({ error => 0x61, message => "message missing"}) unless $self->has_message;
    my $binary_string = pack "H*", $self->message;
    
    my ($crypted_message) = unpack("H*", $binary_string );
    my @crypted_message = split//,$crypted_message;
    $self->hashkmob(  join "", splice(@crypted_message, -8,8) );
    $self->check_hashkmob();
    $self->logger->info("frame before unciphering : " . (join "",@crypted_message)) if @crypted_message;
    #my $decrypted_message = $self->kmob() =~ m/^0+$/ ?
    #                        join "",@crypted_message :
    #                        $self->_get_string_from_aes_ctr_ciphseq(join "",@crypted_message);
    
    my $decrypted_message = $self->kmob() =~ m/^00000+$/      ?
                            join "",@crypted_message :
                            $self->_get_string_from_aes_ctr_ciphseq_local(join "",@crypted_message);
    
    
    $self->decrypted($decrypted_message);
    $self->logger->debug("unciphered frame : $decrypted_message") if $decrypted_message;
    return $decrypted_message;
}

sub check_hashkmob {
    my ($self) = @_;
    return if $self->kmob() =~ m/^00000+$/;
    my $cmac_object = Digest::CMAC->new(  pack("H*", substr($self->kmob,0,32)) );
    my ($crypted_message) = unpack("H*",$self->message_binary);
    my @crypted_message = split//,$crypted_message;
    $self->logger->debug("Full message : $crypted_message");
    splice(@crypted_message, -12,12);
    my $plaintext = join "", @crypted_message;
    $self->logger->debug("full frame used for hashkmob [$plaintext]");
    #$cmac_object->add( pack("H*",$plaintext));
    $cmac_object->add( pack("H*", $self->nfc_uid . $plaintext));
    my $hashkmob_hex = $cmac_object->hexdigest;
    my $hashkmob_calculee = substr($hashkmob_hex,0,8);
    $self->logger()->debug("hashkmob received : ". $self->hashkmob ." <=>  $hashkmob_calculee (computed hashkmob) "   );
    if (lc($self->hashkmob) ne lc($hashkmob_calculee) ) {
        $self->logger->error("hashkmob check failed : hashkmob received : ". $self->hashkmob ." <=>  $hashkmob_calculee (computed hashkmob) ");
        $self->hashkmob_error(1);
    }
}

=head2 _get_aes_ctr_string

Méthode privée

Cryptage d'une message.

S'appuie sur aes_callback

Valeur par défaut : méthode _init_crypt_exchange

En fonction du type de données, il est possible de changer le callback

Disponibles dans cette lib
    
    _init_crypt_download
    
    _init_crypt_nfc
    
Mais il est possible d'ajouter n'importe quell callback
    
Par exemple: 
    
    has '+aes_callback' => (
        default => sub { \&Telereleve::Layer::Presentation::_init_crypt_nfc } 
    );
    
=cut

sub _get_aes_ctr_string {
    my ($self,$message) = @_;
    my $aes_message;
    return $message if $self->application() =~ m/INSTP[IO]NG/ || $self->keysel == 0;
    $self->aes_init();
    my $pad_length = 32 - length($message) % 32 ;
    $aes_message = unpack("H*" , $self->ctr()->encrypt( pack "H*", $message 
                                                . ('0' x $pad_length) 
                                                ));
    $aes_message = substr($aes_message,0,($self->get_max_length_message( $self->format() ) * 2 ));                                            
    return $aes_message;
}

sub _get_aes_ctr_string_ciphseq {
    my ($self,$message) = @_;
    no warnings;
    my $aes_message;
    return $message if $self->application() =~ m/INSTP[IO]NG/ || $self->keysel == 0;
    $self->aes_init();
    my $ciphseq = $self->ciphseq();
    my $data = $message;
    my $msg;
    while (length($data) > 0) {
        my $reste = 0;
        $reste = 32 - length($data) % 32  if length($data) < 32;
        my $plaintext_tmp = pack("H32", substr($data,0,32).'0'x$reste);
        $self->vector_exec($ciphseq,$reste);            
        $msg .= unpack("H".(32-$reste), $self->ctr()->encrypt($plaintext_tmp));
        $data = substr($data,32);
        $ciphseq++;
    }    
    $aes_message = $msg;
    $aes_message = substr($aes_message,0,($self->get_max_length_message( $self->format() ) * 2 ));    
    $self->_message_aes($aes_message);
    return $aes_message;
}

sub _get_aes_ctr_string_ciphseq_nosel {
    my ($self,$message) = @_;
    no warnings;
    my $aes_message;
    $self->aes_init();
    my $ciphseq = $self->ciphseq();
    my $data = $message;
    my $msg;
    while (length($data) > 0) {
        my $reste = 0;
        $reste = 32 - length($data) % 32  if length($data) < 32;
        my $plaintext_tmp = pack("H32", substr($data,0,32).'0'x$reste);
        $self->vector_exec($ciphseq,$reste);            
        $msg .= unpack("H".(32-$reste), $self->ctr()->encrypt($plaintext_tmp));
        $data = substr($data,32);
        $ciphseq++;
    }    
    $aes_message = $msg;
    $aes_message = substr($aes_message,0,($self->get_max_length_message( $self->format() ) * 2 ));    
    $self->_message_aes($aes_message);
    return $aes_message;
}

sub _get_string_from_aes_ctr {
    my ($self,$message) = @_;
    my $decrypted_message;
    return $message if $self->application() =~ m/INSTP[IO]NG/ || $self->keysel == 0;
    $self->aes_init();
    $decrypted_message = unpack "H*", $self->ctr()->decrypt( pack("H*",$message));
    $decrypted_message = substr($decrypted_message,0,($self->get_max_length_message( $self->format() ) *2));
    return $decrypted_message;
}

sub _get_string_from_aes_ctr_ciphseq {
    my ($self,$message) = @_;
    no warnings;
    my $decrypted_message;
    $self->crypted($message);
    return $message if $self->application() =~ m/INSTP[IO]NG/ || $self->keysel == 0;
    $self->aes_init();
    my $ciphseq = $self->ciphseq();
    my $data = $message;
    my $msg;
    while (length($data) > 0) {
        my $reste = 0;
        $reste = 32 - length($data) % 32  if length($data) < 32;
        my $plaintext_tmp = pack("H32", substr($data,0,32).'0'x$reste);
        $self->vector_exec($ciphseq,$reste);            
        $msg .= unpack("H".(32-$reste), $self->ctr()->decrypt($plaintext_tmp));
        $data = substr($data,32);
        $ciphseq++;    
    }
    $decrypted_message = $msg;
    $decrypted_message = substr($decrypted_message,0,($self->get_max_length_message( $self->format() ) * 2));
    return $decrypted_message;
}

sub _get_string_from_aes_ctr_ciphseq_local {
    my ($self,$message) = @_;
    no warnings;
    my $decrypted_message;
    $self->crypted($message);
    $self->aes_init();
    my $ciphseq = $self->ciphseq();
    my $data = $message;
    my $msg;
    while (length($data) > 0) {
        my $reste = 0;
        $reste = 32 - length($data) % 32  if length($data) < 32;
        my $plaintext_tmp = pack("H32", substr($data,0,32).'0'x$reste);
        $self->vector_exec($ciphseq,$reste);            
        $msg .= unpack("H".(32-$reste), $self->ctr()->decrypt($plaintext_tmp));
        $data = substr($data,32);
        $ciphseq++;    
    }
    $decrypted_message = $msg;
    $decrypted_message = substr($decrypted_message,0,($self->get_max_length_message( $self->format() ) * 2));
    return $decrypted_message;
}

#####################################
#
#        exchange cryptage
#
#####################################
sub _init_crypt_exchange {
    my ($self) = @_;
    $self->logger()->trace("initialisation");
    $self->_get_crypt_ctr("kenc");
    $self->logger->debug("kenc used : " . $self->kenc() );
    $self->logger->debug("m-field "  . lc $self->id_fabricant ." and reverse: " . lc sprintf("%04X", $self->_reverse_endian(hex($self->id_fabricant))) );
    $self->logger->debug("a-field: " . lc $self->id_ddc       ." and reverse: " . lc $self->reverse_afield($self->id_ddc));
    $self->logger->debug("L6cpt: " . $self->cpt . " C-field: " . $self->cfield);    
    $self->iv(
            lc sprintf("%04X", $self->_reverse_endian(hex($self->id_fabricant)))
            # $self->id_fabricant
            . lc $self->reverse_afield($self->id_ddc)
            . sprintf("%04X",$self->cpt)
            . $self->cfield
            . ('0' x 6)
            . sprintf("%04X", $self->ciphseq())
            );    
    $self->logger->debug("IV: " . $self->iv());        
    $self->_get_exchange_init_vector($self->ciphseq(),12);
    $self->vector_callback(\&_get_exchange_init_vector);                    
}

sub _get_exchange_init_vector {
    my ($self,$ciphseq,$reste) = @_;
    $self->ctr()->set_iv(pack("H4 H12 H4 H2 H6 H4",
                        sprintf("%04X", $self->_reverse_endian(hex($self->id_fabricant))),
                        $self->reverse_afield($self->id_ddc),
                        sprintf("%04X",$self->cpt),
                        $self->cfield,
                        ('0' x $reste),
                        sprintf("%04X", $ciphseq),
                        ));
}


#####################################
#
#            download cryptage
#
#####################################
sub _init_crypt_download {
    my ($self) = @_;
    $self->logger()->trace("initialisation");    
    $self->_get_crypt_ctr("klog");
    $self->logger->debug("klog used : " . $self->klog() );
    $self->logger->debug("download_id " . $self->download_id() );
    $self->logger->debug("downbnum : " . $self->downbnum() );
    $self->iv(
            sprintf("%06X", $self->download_id)
            . sprintf("%06X",$self->downbnum)
            . ('0' x 8)
            . sprintf("%04X", $self->ciphseq()));
    
    $self->logger->debug("IV: " . $self->iv());
    $self->_get_download_init_vector($self->ciphseq(),16);
    $self->vector_callback(\&_get_download_init_vector);                    
}

sub _get_download_init_vector {
    my ($self,$ciphseq,$reste) = @_;
    $self->ctr()->set_iv(pack("H6 H6 H16 H4",
                        sprintf("%06X", $self->download_id),
                        sprintf("%06X",$self->downbnum),
                        ('0' x $reste),
                        sprintf("%04X", $ciphseq),
                        ));    
}


#####################################
#
#            nfc cryptage
#
#####################################
sub _init_crypt_nfc {
    my ($self) = @_;    
    $self->_get_crypt_ctr("kmob");
    $self->logger->debug("kmob used : " . $self->kmob());
    $self->logger->debug( "nfc uid: " . $self->nfc_uid . " - cpt: ".sprintf("%04x",$self->cpt));
    $self->_get_nfc_init_vector($self->ciphseq(),6);
    $self->vector_callback(\&_get_nfc_init_vector);        
}

sub _get_nfc_init_vector {
    my ($self,$ciphseq,$reste) = @_;
    $self->ctr()->set_iv(pack("H16 H4 H6 H6",
                        $self->nfc_uid,
                        sprintf("%04X",$self->cpt),
                        ('0' x $reste),
                        sprintf("%06X", $ciphseq),
                        ));    
}

sub _get_crypt_ctr {
    my ($self,$key) = @_;
    $self->ctr(new Crypt::Rijndael pack("H*",substr($self->$key(),0,32)), Crypt::Rijndael::MODE_CTR);        
}


=head2 update_kenc

Trigger utilisé quand on modifie le paramètre keysel.

Initialise l'attribut kenc avec la clef choisie.

Voir </keysel>

=cut
sub update_kenc {
    my ( $self, $keysel, $old_keysel ) = @_;
    $self->kenc( $self->get_kenc($keysel) );
}

=head2 analyse_ctrl

Analyse du champs L6Ctrl pour en extraire les données.

Paramètre

    l6ctrl: octet sous forme de chaîne héxa

Paramètres initialisés:

    version, toujours à 0, mias on sait jamais

    wts, toujours à 1, mias on sait jamais

    keysel 

=cut
sub analyse_ctrl {
    my ($self,$ctrl) = @_;
    $self->version( hex($ctrl) >> 5 );    
    $self->wts( (hex($ctrl) & 0x10) >> 4 );    
    $self->keysel( hex($ctrl) & 0x0f  );
}

=head2 _get_total_length

Méthode privée, mais c'est utile pour l'info

Longueur totale des trames de 2 à 7
    
utilisé pour calculer les hashk(enc|log|mob|truc)
Où la principale inconnue est la longueur du message, alias L7
    
Où la seconde inconnue est le champ timestamp qui est vide ou non en fonction des pahses de la lune et divers paramètres ésotériques.

Le caractère vide ou non du timestamp dépend de la valeur du wts, alias bit 6 du champ de contrôle.
    
Voir la doc lan (8.1) qui explique le cheminement de la chose, la valeur étant par défaut à 1 dans la version 2013-2014 de la sftd, mais pouvant changer plus tard en cas de nécessité ou non.
    
Pour faire bref, les fluctuations de longueurs nécessitent quelques contrôles et donc une méthode affectée à la chose.
    
Eléments nécessaires
    
    presentation_length: qui pour chaque type de trame donne la longueur en L6
    
        Methode associée: get_presentation_length
    
    Liaison_length: qui pour chaque type de trame donne la longueur en L2
    
        Méthode associée: get_liaison_length (voir lib Layer::Liaison)
    
Paramètre: 

    message à renvoyer, alias trame L7
    
Cette méthode va donc chercher les différentes longueurs des différentes trames.
    
    
Initialise
    
        $obj->length()
        
qui est utilisé par la trame L6 (présente libaririe) pour la calcul des clés cmac

=cut
sub _get_total_length {
    my ($self,$message) = @_;
    my $length_message = length(pack("H*" ,$message));
    my $length_presentation = $self->get_presentation_length($self->format);
    $length_presentation -= 2 unless $self->has_wts;
    $length_presentation += $length_message;
    #Ce qui change est la longueur du message, mais il est déjà contrôlé dans Liaison
    #115, voir sftd lan 6.1 (début 2014)
    $self->length( $self->get_liaison_length($self->format) + $length_presentation );
}


=head1 AUTHOR

phv, C<< <philippe.devisme at suez-env.com> >>

=head1 BUGS

Please report any bugs or feature requests to Ondeo Systems.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Telereleve::Layer::Presentation


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013-2015 Ondeo Systems.

This program is not free software; you cannot redistribute it nor modify it.

=cut


1; # End of Telereleve::Layer::Presentation
