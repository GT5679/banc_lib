package Telereleve::Layer::Liaison;

use Carp;

use Moose::Role;
use feature qw(say);
use Digest::CRC;
use Error::Correction::RS;

use Data::Dumper;

#gestion des formats de trame: exchange/download
with 'Telereleve::Helper::Formats';

=head1 NAME

Telereleve::Layer::Liaison - Gestion de la couche de liaison (L2)

=head1 VERSION

Version 0.5

=cut

our $VERSION = '0.5';


=head1 SYNOPSIS
    
Cette librairie est un rôle Moose à utiliser à travers une classe spécialisée.

    voir L<Telereleve::Application|telereleve-application.html>

Elle s'occupe de génèrer la trame de liaison à partir des données issues de la trame de présentation.
    
2 fonctions principales:

=over 4 

=item compose
    
    Compose la trame de liaison correspondant au niveau 2 à partir des données reçues des niveaux supérieurs.

=item decompose
    
    decompose la partie L2 d'une trame reçue

=back
    
=head2 exemple d'utilisation
    
    use Telereleve::Layer::Liaison;
    use Telereleve::Application;
    
    my $appli = Telereleve::Application->new(mainconfig_file => 'campagne.cfg');
    
    #message non crypté
    $appli->compose("message en hexa");
    
    print $appli->message_hexa
    
    print unpack("B*", $appli->message_binary);

=head1 SUBROUTINES/METHODS/ATTRIBUTES

=head2 Attributes

Voir les applications (Telereleve::Application and co)
    
    my $app = new Telereleve::Application::Command(testname => 'nomtest' , mainconfig_file => 'campagne.cfg');
    $app->extract("trame au format binaire");
    
Accès aux attributs de la couche de liaison
    
longueur (de la trame) optionnel selon type de trame
    
        $app->length
    
type de appli ou c-field    : initialisé par la lib application qui connait l'appli
    
        $app->cfield
        
Format des trames exchange ou download
    template selon type de trame
    
        $app->format
        
template

template pack utilisé pour packer, dépacker
    
        $app->get_liaison_template($app->format);
    
id_fabricant: initialisé par la lib application optionnel selon type de trame
    ou récupéré lors de l'analyse d'une trame reçue.
    Attention il doit toujouyrs être en MSB
    
id ddc            : initialisé par lib application optionnel selon type de trame
    ou récupéré lors de l'analyse d'une trame reçue.
    
ci_field        : constant optionnel selon type de trame
    
CRC                : généré / obtenu
    
message_binary  : généré
    
message_hexa    : généré
    
download_num
        utilisé pour les trames de download
    
Parité RS
    
=cut

has 'length' => ( is => 'rw' );



has 'liaison_application_name' => (
    is => 'rw',
    #trigger: initialise le format de trame
    trigger => \&_build_format_application_name,
);

sub _build_format_application_name {
    my ($self,$value,$old_value) = @_;
    $self->format(  $self->get_application_format($value) );
    $self->cfield(  $self->get_appli_hexa($value) );
    $self->_set_ci_field();
}

=head2 identifiant hexa d'une application

Methodes
    
    get_appli_hexa(application: INSTPING/INSTPONG)
    
    $obj->get_appli_hexa($self->application);
    
    set_appli_hexa('APPLICATION' => 0x25)

    appli_hexa_pairs()
    
Liste des applications disponibles
    
=cut

has 'appli' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef[Str]',
  default   => sub { {
        'INSTPING'     => '46',
        'INSTPONG'     => '06',
        'DATA'         => '44',
        'COMMAND'    => '43',
        'RESPONSE'    => '08',
        'DOWNLOAD'    => 'FF',        
  } },
  handles   => {
      set_appli_hexa     => 'set',
      get_appli_hexa     => 'get',
      exists_appli_hexa  => 'exists',
      appli_hexa_pairs   => 'kv',
  },
);

=head2 BADCRC

En cas d'erreur de CRC, BADCRC == 1

=cut
has 'BADCRC' => (
        is => 'rw'
);

has 'cfield' => ( is => 'rw' );

=head2 Tableau des templates pour pack

Pour chacun des formats de trame: exchange ou download, renvoie le template utilisé 

par la commande perl pack

pour composer ou décomposer une chaine binaire.

Methodes
    
    get_liaison_template(format);
    
    liaison_template_pairs
    
        liste des templates disponibles
    
=cut

has 'liaison_template' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {
        'exchange' => ["H2 H2 H4 H12 H2", "H4"],
        'download' => ["H2 H6","H2"], 
        'nfc'      => ["H2 H4 H2 H2","H4"],#deprecated
        'local'    => ["H2 H4 H2 H2","H4"],        
  } },
  handles   => {
      get_liaison_template     => 'get',
      liaison_template_pairs   => 'kv',
  },
);

has 'liaison_response' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef[Str]',
  default   => sub { {
  } },
  handles   => {
      get_liaison_response     => 'get',
      set_liaison_response     => 'set',
      liaison_response_pairs   => 'kv',
  },
);

=head2 liaison_length

Elements de la couche de laiison utilisés pour calculer la longueur du hashk(enc|log|mob|etc)

La longueur varie en fonction du timestamp
    
voir presentation_length pour la partie l6
    
Voir la doc dans Telereleve::Presentation
    
voir la doc de Telereleve::Presentation::_get_total_length
qui explique ce qui se passe.

Longueurs en octet début 2014

    exchange = 11

        1 cfield
        2 mfield
        6 afield
        1 ci-field
        2 + le crc
        
    #Attention: l'octet de longueur est calculé sans la longueur mais avec le CRC 
        
    nfc = 8
        2 cpt
        1 cfield
        1 nfcversion
        
        4 hashkmob
    
    Attention: l'octet de longueur est calculé sans l'octet de longueur et sans le CRC 
    
    download = 4
        1 lfield
        3 download_id

Méthode:
    
    get_liaison_length(type de trame: exchange/download/local)
    
    $length = $objet->get_liaison_length('local');
        
    
=cut
has 'liaison_length' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef[Str]',
  default   => sub { {
        'exchange' => 12,
        'download' => 4,
        'nfc'      => 8,        #deprecated, remplacé par local
        'local'    => 8,    #cpt(2) + cfield(1) + nfcver(1) + hashkmob(4)    
  } },
  handles   => {
      get_liaison_length     => 'get',
      liaison_length_pairs   => 'kv',
  },
);
    
has 'id_fabricant' => ( 
    is => 'rw',
 );

has 'id_ddc' => ( 
    is => 'rw',
    );


has 'ci_field' => ( 
    is         => 'rw', 
    predicate => 'has_ci_field',
    clearer   => 'clear_ci_field',
);

=head2 _ci_field_value

Variable privée, mais si on veut pêter kekchose la valeur est en écriture
    
donc on peut quand même changer la valeur ;)

=cut
has '_ci_field_value' => ( 
    is         => 'rw', 
    default => 'b4',
);

has 'download_id' => ( 
    is         => 'rw',
);

#has 'CRC' => ( is => 'rw' );

#valeur nulle par défaut, mais modifiable à volonté
has 'CRC_alteration' => (
    is => 'rw',
    predicate => 'has_CRC_alteration',
);

has 'message_binary' => ( 
    is => 'rw',
    predicate => 'has_message_binary',
);

has 'message_hexa' => ( 
    is => 'rw',
    predicate => 'has_message_hexa',
);


sub _set_ci_field {
    my ( $self, $ci_field, $old_ci_field ) = @_;
    $self->clear_ci_field() if  $self->format() eq "download";      
    $self->ci_field($self->_ci_field_value) if $self->format() eq "exchange";
}

=head2 compose

Compose la trame de liaison à partir des données reçues de la trame de présentation (voir Telereleve::Layer::Presentation)

La trame reçue est une chaine hexa
    
Parametre: 

    trame L6 cryptee, formattée et sous forme de chaine héxadécimale
    
Les éléments composants la trame sont initialisés lors du chargement du fichier de configuration
    
Le résultat est disponible dans
    
    $object->message_hexa
    #ou
    $object->message_binary
    
=cut

sub compose {
    my ($self,$message) = @_;
    if ($self->interface() eq "lan") {
        $self->format() && $self->format() eq "exchange" ? 
                $self->_compose_exchange($message) : $self->_compose_download($message);    
    } else {    
        $self->_compose_nfc($message);
    }
    $self->logger->debug("L2 frame : " . $self->message_hexa);
    return 0;
}

sub _compose_nfc {
    my ($self,$message) = @_;
    my $template = $self->get_liaison_template($self->format());
    #génère_crc    : 
    #Digest::CRC::crc16_en13757
    #longueur donnée au crc =  de lfield  à hashkmob et sans le CRC
    #l-field
    my $longueur = length(pack( "H*", sprintf("%04x",$self->cpt) .
                                $self->cfield .
                                sprintf("%02x", $self->NFCversion).
                                $message ));
    my $msg2encode = sprintf("%02x", $longueur).
                                sprintf("%04x",$self->cpt).
                                $self->cfield.
                                sprintf("%02x", $self->NFCversion).
                                $message    ;        #voir couche présentation = version + datas  + hashkmob                            
    my $crc = Digest::CRC::crc16_en13757(
                                    join "", 
                                        map { chr($_) } 
                                        map { hex($_) } 
                                        ($msg2encode =~ m/([a-fA-F0-9]{2})/g)                        
                                );
    $self->logger->trace("ms2encode: $msg2encode " . sprintf( "%4x",$crc));                                
    if ($self->has_CRC_alteration ) {
        $self->logger->info("alteration du CRC");
        $crc += $self->CRC_alteration();
    }
    
    my $message_length = length($message);
    #longueur tout - lfield (1)
    $self->message_binary(pack("$template->[0] H$message_length $template->[1]",
                            sprintf("%02x", ($longueur)),
                            sprintf("%04x",$self->cpt),
                            $self->cfield,
                            sprintf("%02x", $self->NFCversion),
                            $message,
                            sprintf( "%4x",$crc)
                            )
                        );                    
    $self->message_hexa( unpack("H*", $self->message_binary() )  );    
}

sub _compose_exchange {
    my ($self,$message) = @_;
    confess({error => 0x22, message => "Message trop long [" . length( pack("H*",$message) ) . "]" }) 
            if  length( pack("H*",$message) ) > $self->get_max_length_message( $self->format() );    
    my $template = $self->get_liaison_template($self->format());
    $self->logger()->debug( "message recu : $message" );
    #longueur totale pour le crc: tout y compris L-field -  crc (2)
    my $longueur = length(pack( "H*", $self->cfield.
                                $self->id_fabricant.    
                                $self->id_ddc.
                                $self->ci_field.
                                $message ))  + 2; # 2 pour la longueur du CRC                    
    #génère_crc    : 
    #Digest::CRC::crc16_en13757
    my $msg2encode = sprintf("%02x", $longueur).
                                    $self->cfield.
                                    sprintf("%04X", $self->_reverse_endian(hex($self->id_fabricant))) .
                                    $self->reverse_afield($self->id_ddc).
                                    $self->ci_field.
                                    $message;
                                    
    my $crc = unpack("H*", pack("H4" ,sprintf( "%4x",
                                Digest::CRC::crc16_en13757(
                                    join "", 
                                        map { chr($_) } 
                                        map { hex($_) } 
                                        ($msg2encode =~ m/([a-fA-F0-9]{2})/g)                
                                )
                        )));    
    
    my $message_length = length($message);
    #longueur ajoutée = tout y compris crc - lfield
    $self->message_binary(pack("$template->[0] H$message_length $template->[1]",
                            sprintf("%02x", ($longueur)),
                            $self->cfield,
                            sprintf("%04X", $self->_reverse_endian(hex($self->id_fabricant))) ,
                            $self->reverse_afield($self->id_ddc),
                            $self->ci_field,
                            $message,
                            $crc
                            )
                        );                        
    $self->message_hexa( unpack("H*", $self->message_binary() )  );
}

sub _compose_download {
    my ($self,$message) = @_;
    confess({error => 0x23, message => "[".$self->format()."] Mauvaise longueur [" . length( pack("H*",$message) ) . "]"}) 
            if  length( pack("H*",$message) ) != ($self->get_max_length_message( $self->format() ) 
                                                + $self->get_presentation_length( $self->format() )
                                                + 4 #pour Hashklog
                                                );        
    my $template = $self->get_liaison_template($self->format());
    #génère_crc    : 
    #Digest::CRC::crc16_xmodem_ccitt
    
    $self->logger()->debug("crc datas: length=" . $self->length );
    my $msg2encode = 
        $self->get_appli_hexa($self->application())
        . sprintf("%06x",$self->download_id)
        . $message;

    my $crc = unpack("H*", 
                pack("H4" ,
                    sprintf( "%4x",
                        Digest::CRC::crc16_en13757(
                            join "", 
                            map { chr($_) } map { hex($_) } ($msg2encode =~ m/([a-fA-F0-9]{2})/g)                            
                            )
                        )
                    )
                );
    my $message_length = length($message);
    my $hex_tmp = sprintf("%06x",$self->download_id)
                            .$message
                            .$crc
                            ;
    my $rs = new Error::Correction::RS(degree => 8,length => 255,
                            capability => 223,parity => 32);
    #my $rs = new Error::Correction::RS(degree => 8,length => 255,
    #                        capability => 32,parity => 223);
    my @msg = map { hex($_)  } $hex_tmp =~ m/([0-9a-fA-F]{2})/g;
    if ( !$rs->encode(\@msg) ) {
        my $message_length = length($rs->msg_hex() );
        $self->message_binary(    pack("H2 H$message_length" ,  
                                $self->get_appli_hexa($self->application()),
                                $rs->msg_hex())
                                );
        $self->message_hexa( $self->get_appli_hexa($self->application()) .$rs->msg_hex()  );    
    } else {
        confess({error => 0x22, message => "[_compose_download] L'encodage RS est parti en vrille"});
    }

}

=head2 decompose

Décompose une trame brute reçue d'un ddc ou d'un concentrateur
    
Le message est un objet binaire à dépacker

Informations récupérées
    
    length
    
    cfield
    
    id_fabricant
    
    id_ddc
    
    ci_field
    
Le CRC est de type dnp, voir la doc Digest::CRC
    
paramètre: 

    trame au format binaire
    
retourne: 

    la trame de présentation (L6 pour les intimes) au format hexadecimal
    
=cut

sub decompose {
    my ($self,$message) = @_;
    confess({error => 0x20, message => "Missing Message"}) unless $message;
    $self->message_binary($message);
    $self->logger->debug("received frame [interface:".$self->interface()."]: " . unpack("H*",$message));
    if ($self->interface() eq "lan") {
        return $self->format() && $self->format() eq "exchange" ? $self->_decompose_exchange() : $self->_decompose_download();    
    } else {    
        return $self->_decompose_nfc();
    }    
    return 0;
}

sub _decompose_exchange {
    my ($self) = @_;
    confess({error => 0x22, message => "Missing Message"}) unless $self->has_message_binary;
    my $template = $self->get_liaison_template($self->format());
    my ($length,$cfield,$mfield,$afield,$cifield,$reste) = unpack($template->[0] . "H*",$self->message_binary);
    
    $self->length( hex($length) );
    
    #vérifier que le cfield correspond, sinon confession
    $self->cfield($cfield);
    
    #sprintf("%04X", $self->_reverse_endian(hex($self->id_fabricant)))

    $self->id_fabricant(  sprintf("%04X", $self->_reverse_endian(hex($mfield)))  );
    #$self->id_fabricant(   $mfield  );
    $self->id_ddc($self->reverse_afield($afield));
    $self->ci_field($cifield);
    
    my @reste = split(//,$reste);
    $self->CRC( join '', splice(@reste,-4,4) );
    $reste = join "", @reste;
    $self->logger()->debug("length: $length - cfield: $cfield - mfield: $mfield - afield: $afield - cifield: $cifield");
    #vérifier crc
    my $msg2encode = uc(sprintf("%02x", ($self->length)).
                                $self->cfield.
                                $mfield.
                                $afield.
                                $self->ci_field.
                                (join "", @reste)
                                );
    my $crc =  Digest::CRC::crc16_en13757(
                                join "", 
                                map { chr($_) } 
                                map { hex($_) } 
                                ($msg2encode =~ m/([a-fA-F0-9]{2})/g)
                                );    

    my $crc_str_hexa = sprintf("%04X",$crc);                    

    $self->logger()->debug( "crc received : " . $self->CRC() . " <=> $crc_str_hexa (computed)");

    $self->logger()->trace( "L6 : " . (join "", @reste) );    
    if ($crc != hex($self->CRC()) ) {
        $self->logger->warn("BADCRC: computed crc : $crc_str_hexa <=> " . $self->CRC() );
        $self->BADCRC(1);
        #confess({error => 0x22, message => "CRC computed is not same as the one in frame : $crc_str_hexa != ". $self->CRC() }) ;
    }
    else
    {
        $self->BADCRC(0);
    }
    $self->set_liaison_response( 
                        'C-field' => $self->cfield , 
                        'L-field' => $length,
                        'A-field' => $self->id_ddc,
                        'Cl-field' => $self->ci_field,                        
                        'M-field' => $self->id_fabricant,
                        'CRC' => $self->CRC(),
                        );
    
    return (join "", @reste);
}

sub _decompose_download {
    my ($self) = @_;
    confess({error => 0x23, message => "message missing"}) unless $self->has_message_binary;
    my $template = $self->get_liaison_template($self->format());
    my ($length,$download_id,$reste) = unpack("$template->[0] H*",$self->message_binary);
    $self->length($length);
    confess({error => 0x23, message => "frame length missing"}) unless defined($self->length);
    $self->download_id($download_id);
    my @reste = split(//,$reste);
    $self->CRC( join '', splice(@reste,-38) );    
    return (join "", @reste);
}

sub _decompose_nfc {
    my ($self) = @_;
    confess({error => 0x21, message => "message missing"}) unless $self->has_message_binary;
    $self->logger->trace(" begin");
    my $template = $self->get_liaison_template($self->format());
    my ($length,$cpt,$cfield,$ack,$reste) = unpack("$template->[0] H*",$self->message_binary);
    $self->length($length);
    confess({error => 0x21, message => "frame length missing"}) unless defined($self->length);
    $self->set_cpt(hex($cpt));
    $self->cfield($cfield);
    $self->logger()->debug("c-field $cfield");
    $self->ACK($ack);
    $self->logger()->debug("ACK $ack");
    my @reste = split(//,$reste);
    #$self->logger()->debug("reste: ".@reste);
    $self->CRC( uc( join '', splice(@reste,-4,4)) );
    $self->logger()->debug("CRC: " . $self->CRC());
    #Ajouter contrôle du crc, mais vérifier avant ce qu'on trouve dans le CRC
    my ($trame) = unpack("H*",$self->message_binary);
    
    my $check_part = substr($trame,0,-4);
    $self->logger()->debug("data used for crc: [$check_part]");
    my $crc =  Digest::CRC::crc16_en13757(
                                    join "", 
                                        map { chr($_) } 
                                        map { hex($_) } 
                                        ($check_part =~ m/([a-fA-F0-9]{2})/g                            
                        ));        
    my $crc_str_hexa = sprintf("%04X",$crc);
    if ($crc_str_hexa ne $self->CRC() ) {
        $self->logger->warn("CRC ERROR: computed crc: $crc_str_hexa <=> " . $self->CRC() . " crc obtenu");
        $self->BADCRC(1);
        confess({error => 0x21, message => "CRC computed is not same as the one in frame :  $crc_str_hexa ne". $self->CRC() }) ;
    }
    return (join "", @reste);
}

sub _reverse_endian
{
    my ($self,$i) = @_;
    return (($i & 0xff00) >> 8) | (($i & 0xff) << 8);
}

=head2 reverse_afield

Reverse le champ A-Field à partir du radio_number et lycée de Versailles.

Respecte la norme EN13757-4, voir sftd LAN pour de plus amples précision et si vous n'êtes pas déjà informé sur le sujet.

Parametre:

    radio_number : chaine hexa
    
Retourne:

    a-field : chaine hexa

=cut
sub reverse_afield {
    my ($self,$radio_number) = @_;
    #code mi-Perl, mi-C, on peut faire plus perlien, mais on verra plus tard.
    my ($hexnum,$ver,$device) = unpack( "H8 H2 H2" , pack("H*", $radio_number)  );
    my $num = hex($hexnum);

    my $n2 = ($num & 0xff) <<24
        | ($num & 0xff00) <<8
        | ($num & 0xff0000) >>8
        | ($num & 0xff000000) >>24 ;

    return sprintf("%08X$ver$device", $n2);
}

=head1 AUTHOR

phv, C<< <philippe.devisme at suez-env.com> >>

=head1 BUGS

Please report any bugs or feature requests to Ondeo Systems.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Telereleve::Layer::Liaison

=head1 ACKNOWLEDGEMENTS

Telereleve System

JR Herbron

LJ Noyel

=head1 LICENSE AND COPYRIGHT

Copyright 2013-2015 Ondeo systems.

This program is not free software; you cannot redistribute it nor modify it.

=cut
1; # End of Telereleve::Layer::Liaison
