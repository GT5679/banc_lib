package Telereleve::Helper::CheckDatas;

use Moose::Role;

use Carp;
use Moose::Util::TypeConstraints;

use feature qw(say);

use Data::Dumper;

=head1 NAME

Telereleve::Helper::CheckDatas - CheckDatas

=head1 VERSION

Version 0.5

=cut

our $VERSION = '0.5';

=head1 SYNOPSIS

Rôle Moose

Librairie dont l'objet est de vérifier que les données reçues correspondent à ce qu'on peut en attendre.

CheckDatas est utilisé par les librairies ayant besoin de contrôler des données:

L<Telereleve::Application::Local|telereleve-application-local.html> pour les accès locaux en NFC.	

L<Telereleve::Application::Response|telereleve-application-response.html> pour les accès distants par radio.

=head2 Actions possibles
	
Actions à effectuer:

=over 4

=item Récupérer une trame par tout moyen à votre disposition.

=item Décomposer la dite trame pour en extraire la substantifique moëlle, alias la couche L7, alias les données applicatives.

=item Demander gentiment à CheckDatas de vérifier si les données sont celles attendues

=back

Contrôles possibles

=over 4

=item * 

Vérifier que le statut attendu (ACK/L7ErrorCode) est celui qui est attendu.

Exemple:

ACK NFC attendu: FFh

ACK nfc reçu du Ddc: 00h

Le module confesse une erreur.

=item * 

Vérifier que la valeur du paramètre reçu correspond bien à la valeur attendue

Concerne souvent les lectures de paramètres.

Exemple:

Valeur attendue pour CURRENT_STATUS = 01h

Valeur reçue  04h

Le module confesse une erreur.

=item * 

Vérifier que la valeur du paramètre reçu est valide

Exemple:

Valeurs attendues pour CURRENT_STATUS entre 00h et 05h

Valeur reçue  FFh

Le module confesse une erreur.

=item * 

Vérifier que la valeur du paramètre reçu correspond aux valeurs enregistrées dans les fichier de configuration (campagne.cfg)

Certaines valeurs sont propres à un équipement, meter ou radio number, id fabricant, etc.

Ces informations sont stockées dans le fichier de configuration associé (campagne.cfg) et enregistrées au lancement de l'application dans l'atrribut correspondant.

Exemple:

Le fichier de configuration contient:

METER_NUMBER=010203

L'attribut $objet->METER_NUMBER contiendra 010203

La valeur reçue devra être égale à la valeur attendue.

En l'absence de correspondance, le module confesse une erreur.

=back

=head2 Fonctionnement
	
Les contrôles sont faits à partir de subtypes Moose, voir la doc correspondante pour en comprendre le fonctionnement.
Aucune remarque ne sera acceptée sans une lecture attentive de la doc correspondante.
	
Principe
	
Chaque subtype gère un type de données
	
	Exemple
	
	enum_hexa_04: 0x01 0x02 0x03 0x04
		Vérifie que le paramètre contient 1 des 4 valeurs hexa
		
	bits64
		Vérifie que le paramètre est un entier sur 64 bits
		reçoit une chaine hexa et renvoie 1 si c'est ok, sinon râle
	
	unchecked
		Renvoie toujours 1 donc OK, non véfifié pour diverses raisons
	
	dans le cas de contrôle de données issues de la conf, les atrributs utilisent des triggers
	
	
Chaque paramètre à vérifier possède un attribut (en majuscule) du type attendu. Le nom de l'attribut correspond à celui des SFTD LAN et DDC (en gros tout est en majuscule)
 (à noter que dans les SFTD le paramètre module_type n'est pas en majuscule, mais l'est dans le code).

Exemple:

	has 'METER_NUMBER' => (
		'is' => 'rw', 
		'isa' => 'conf'
	);
	
Appel du paramètre:
	
	my $param_name = 'METER_NUMBER';
	$object->$param_name("valeur extraite de la trame");
	if ($@) {
		confess( {error => 1, message => $@});
		return 1;
	}

Si aucune erreur
	return 0;


Ajouter des contrôles consiste simplement à ajouter un subtype ou à définir un subtype pour un attribut donné
	
=head1 SUBTYPES

La liste des subtypes correspond aux paramètres des SFTD LAN et DdC.
	
En cas de nouveau type, ajouter un subtype, ajouter un test case dans le fichier de test


=cut	

subtype 'unchecked',
        => as 'Str'
       => where { return 1;  }
	   => message {"non vérifié, ok"};	
	   
subtype 'event_log_length'
        => as 'Str'
        => where { 	length(pack("H*",$_)) == 8  }
		=> message {"Résultat attendu 8 octets. Obtenu: $_"};
		
subtype 'bits_64'
        => as 'Str'
        => where { length(pack("H*",$_)) == 8  }
		=> message {"Résultat attendu 8 octets. Obtenu: $_"};
		
subtype 'octets_7'
        => as 'Str'
        => where { length(pack("H*",$_)) == 7  }
		=> message {"Résultat attendu 7 octets. Obtenu: $_"};		
		
subtype 'octets_6'
        => as 'Str'
        => where { length(pack("H*",$_)) == 6  }
		=> message {"Résultat attendu 6 octets. Obtenu: $_"};			
		
subtype 'bits_40'
        => as 'Str'
        => where { length(pack("H*",$_)) == 5  }
		=> message {"Résultat attendu 5 octets. Obtenu: $_"};		

subtype 'bits_32'
        => as 'Str'
        => where { length(pack("H*",$_)) == 4  }
		=> message {"Résultat attendu 4 octets. Obtenu: $_"};

subtype 'bits_16'
        => as 'Str'
        => where { length(pack("H*",$_)) == 2  }
		=> message {"Résultat attendu 2 octet [" . length(pack("H*",$_)) . "]"};		
		
subtype 'bits_8'
        => as 'Str'
        => where { length(pack("H*",$_)) == 1  }
		=> message {"Résultat attendu 1 octet. Obtenu: $_"};
		
subtype 'ping_length'
        => as 'Str'
        => where { 	length(pack("H*",$_)) == 9;  }
		=> message {"Résultat attendu 9 octets"};			

subtype 'octets_13'
        => as 'Str'
        => where { length(pack("H*",$_)) == 13  }
		=> message {"Résultat attendu 13 octets"};	

subtype 'octets_25'
        => as 'Str'
        => where { length(pack("H*",$_)) == 25  }
		=> message {"Résultat attendu 13 octets"};	
		
subtype 'octets_36'
        => as 'Str'
        => where { length(pack("H*",$_)) == 36  }
		=> message {"Résultat attendu 36 octets"};	
		
subtype 'octets_37'
        => as 'Str'
        => where { length(pack("H*",$_)) == 37  }
		=> message {"Résultat attendu 37 octets"};			

		
subtype 'fixe_01'
        => as 'Str'
        => where { hex($_) == 14   }
		=> message {"Résultat attendu différent de 14. Obtenu: " . hex($_)};
		
subtype 'intervalle_01'
        => as 'Str'
        => where { hex($_) > 0x60   }
		=> message {"Résultat attendu inférieur à 0x60. Obtenu: " . $_};

subtype 'intervalle_entier'
        => as 'Str',
        => where { hex($_) < 65535 && hex($_) >= 0   }
		=> message {"Résultat attendu devrait être entre 0 et 65535. Obtenu: " . hex($_)};
		
subtype 'intervalle_signed'
        => as 'Str',
        => where { hex($_) < 32767 && hex($_) > -32768   }
		=> message {"Résultat attendu devrait être entre 32767 et -32768. Obtenu: " . hex($_)};
		
subtype 'intervalle_255'
        => as 'Str'
        => where { hex($_) < 256 && hex($_) >= 0   }
		=> message {"Le Résultat attendu devrait être entre 0 et 256. Obtenu: " . hex($_) };

subtype 'intervalle_0_to_60'
        => as 'Str'
        => where { hex($_) >= 0 && hex($_) <= 60   }
		=> message {"Le Résultat attendu devrait être entre 0 et 60. recu: " . hex($_) . " [hexa: $_]"};	
		
subtype 'intervalle_0_to_99'
        => as 'Str'
        => where { hex($_) >= 0 && hex($_) <= 99   }
		=> message {"Le Résultat attendu devrait être entre 0 et 60. recu: " . hex($_) . " [hexa: $_]"};			

subtype 'intervalle_15'
        => as 'Str'
        => where { hex($_) <= 15 && hex($_) > 0   }
		=> message {"Résultat attendu devrait être entre 0 et 15. Obtenu: " . hex($_)};			
		
subtype 'intervalle_octet_01'
        => as 'Str'
        => where { hex($_) >= 40 &&  hex($_) <=100  }
		=> message {"Résultat attendu devrait être entre 40 et 100. Obtenu: " . hex($_)};

subtype 'intervalle_octet_02'
        => as 'Str'
        => where {  hex($_) >= 50 && hex($_) <=100  }
		=> message {"Résultat attendu devrait être entre 50 et 100. Obtenu: " . hex($_)};
		
		
subtype 'ciph_count'
        => as 'Str'
        => where { hex($_) == 14   }
		=> message {"Résultat attendu devrait être égal à 14. Obtenu: " . hex($_)};		
	

enum 'enum_heure_gaziere' =>  [qw( 1c20 1C20 2328 )];

enum 'enum_02' =>  [qw( 00 01 )];

enum 'enum_03' => [qw( 00 01 02 )];

enum 'enum_04' => [qw( 00 01 02 03 )];

enum 'enum_next_event' => [qw( 00 01 02 7F FF )];

enum 'enum_06' => [qw( 00 01 02 03 04 05 )];

enum 'enum_07' => [qw( 00 01 02 03 04 05 06 )];

enum 'radio_06' => [qw(64 6E 78 82 96 )];


=head1 ATTRIBUTES

Attributs disponibles:

Il existe autant d'attributs que de paramètres.

Auxquels ils faut ajouter certains sous-éléments d'un paramètre, tel que le type et la data de EVENT_LOG_LATEST
	
Pour ajouter un paramètre à contrôler, choisir ou créer le subtype correspondant, 
	
	has 'NOM_DU_PARAMETRE' => (
		'is' => 'rw', 
		'isa' => 'subtype à choisir ou créer'
	);



=cut

has 'params_to_check' => (
	'is' => 'rw', 
);

has 'status_to_check' => (
	'is' => 'rw', 
);

has 'command_name' => (
	'is' => 'rw', 
);


our $VERS_HW_TRX;
subtype 'version_hw_type',
        => as 'Str'
       => where { $VERS_HW_TRX ? uc($_) eq uc($VERS_HW_TRX) : 1  }
	   => message {"
	   obtenu $_
	      	   
	   ***************
	   Verifiez neanmoins la valeur attendue de VERS_HW_TRX dans le fichier de configuration (campagne.cfg)
	   ***************
	   "};	

has 'VERS_HW_TRX' => (
		is => 'rw',
		isa => 'version_hw_type'
		#isa => subtype( 'Str' => where { $VERS_HW_TRX ?  $_ eq $VERS_HW_TRX : 1  } ),
);

has 'set_VERS_HW_TRX' => (
		is => 'rw',
		trigger  => sub { my ($self,$new) = @_; $VERS_HW_TRX = $new;  $self->VERS_HW_TRX($new) }
);

our $VERS_FW_TRX;
subtype 'version_fw_type',
        => as 'Str'
       => where { $VERS_FW_TRX ? uc($_) eq uc($VERS_FW_TRX) : 1  }
	   => message {"
	   obtenu $_
	      	   
	   ***************
	   Verifiez neanmoins la valeur attendue de VERS_FW_TRX dans le fichier de configuration (campagne.cfg)
	   ***************
	   "};	
has 'VERS_FW_TRX' => (
		is => 'rw',
		isa => 'version_fw_type'
		#isa => subtype( 'Str' => where {  $VERS_FW_TRX ? $_ eq $VERS_FW_TRX : 1  } ),
);

has 'set_VERS_FW_TRX' => (
		is => 'rw',
		trigger  => sub { my ($self,$new) = @_; $VERS_FW_TRX = $new;  $self->VERS_FW_TRX($new) }
);

has 'DATEHOUR_LAST_UPDATE' => (
		is => 'rw',
		isa => 'bits_32'
);

has 'RF_UPSTREAM_CHANNEL' => (
		is => 'rw',
		isa => 'radio_06'
);

has 'RF_DOWNSTREAM_CHANNEL' => (
		is => 'rw',
		isa => 'radio_06'
);

has 'RF_UPSTREAM_MOD' => (
		is => 'rw',
		isa => 'enum_03'
);

has 'RF_DOWNSTREAM_MOD' => (
		is => 'rw',
		isa => 'enum_03'
);

has 'TX_POWER' => (
		is => 'rw',
		isa => 'enum_03'
);

has 'TX_DELAY_FULLPOWER' => (
		is => 'rw',
		isa => 'intervalle_entier'
);

has 'TX_FREQ_OFFSET' => (
		is => 'rw',
		isa => 'intervalle_signed'
);

has 'EXCH_RX_DELAY' => (
		is => 'rw',
		isa => 'intervalle_255'
);

has 'EXCH_RX_LENGTH' => (
		is => 'rw',
		isa => 'intervalle_255'
);

has 'EXCH_RESPONSE_DELAY' => (
		is => 'rw',
		isa => 'intervalle_255'
);

has 'EXCH_RESPONSE_DELAY_MIN' => (
		is => 'rw',
		isa => 'intervalle_255'
);

has 'L7TRANSMIT_LENGTH_MAX' => (
		is => 'rw',
		isa => 'intervalle_octet_01'
);

has 'L7RECEIVE_LENGTH_MAX' => (
		is => 'rw',
		isa => 'intervalle_octet_02'
);

has 'CLOCK_CURRENT_EPOC' => (
		is => 'rw',
		isa => 'bits_32'
);

has 'CLOCK_OFFSET_CORRECTION' => (
		is => 'rw',
		isa => 'intervalle_signed'
);

#a revoir
has 'CLOCK_DRIFT_CORRECTION' => (
		is => 'rw',
		isa => 'bits_16'
);


has 'CIPH_CURRENT_KEY' => (
		is => 'rw',
		isa => 'enum_02'
);

has 'CIPH_KEY_COUNT' => (
		is => 'rw',
		isa => 'ciph_count'
);

has 'PING_RX_DELAY' => (
		is => 'rw',
		isa => 'intervalle_0_to_60'
);

has 'PING_RX_LENGTH' => (
		is => 'rw',
		isa => 'intervalle_255'
);

has 'PING_RX_DELAY_MIN' => (
		is => 'rw',
		isa => 'intervalle_0_to_60'
);

has 'PING_RX_LENGTH_MAX' => (
		is => 'rw',
		isa => 'intervalle_255'
);

has 'PING_LAST_EPOCH' => (
		is => 'rw',
		isa => 'bits_32'
);

has 'PING_NBFOUND' => (
		is => 'rw',
		isa => 'intervalle_255'
);

has 'PING_REPLY1' => (
		is => 'rw',
		isa => 'ping_length'
);

has 'PING_REPLY2' => (
		is => 'rw',
		isa => 'ping_length'
);

has 'PING_REPLY3' => (
		is => 'rw',
		isa => 'ping_length'
);

has 'PING_REPLY4' => (
		is => 'rw',
		isa => 'ping_length'
);

has 'PING_REPLY5' => (
		is => 'rw',
		isa => 'ping_length'
);

has 'PING_REPLY6' => (
		is => 'rw',
		isa => 'ping_length'
);

has 'PING_REPLY7' => (
		is => 'rw',
		isa => 'ping_length'
);

has 'PING_REPLY8' => (
		is => 'rw',
		isa => 'ping_length'
);

=head2 verif_ping

Parse une réponse PING_REPLY<N> et renvoie les données sous forme de tableau.

Paramètres:

	chaîne héxa: L7 déchiffrée

Retourne:

	Array de chaînes heaxa
	($L7Concentid,$L7Modemid,$rssi_up,$rssi_down)

=cut
sub verif_ping {
	my ($self,$value) = @_;
	my ($L7Concentid,$L7Modemid,$rssi_up,$rssi_down) 
			= unpack("H12 H2 H2 H2", pack("H*",$value));
	return 0 if !defined($rssi_down);
	return 0 if !defined($rssi_up);
	return ($L7Concentid,$L7Modemid,$rssi_up,$rssi_down);
}

our $RADIO_NUMBER;
subtype 'radio_number_type',
        => as 'Str'
       => where { $RADIO_NUMBER ? uc($_) eq uc($RADIO_NUMBER) : 1  }
	   => message {"
	   obtenu $_
	      	   
	   ***************
	   Verifiez neanmoins la valeur attendue de RADIO_NUMBER dans le fichier de configuration (campagne.cfg)
	   ***************
	   "};	

has 'RADIO_NUMBER' => (
		is => 'rw',
		isa => 'radio_number_type'
		#isa => subtype( 'Str' => where { $RADIO_NUMBER ? uc($_) eq uc($RADIO_NUMBER) : 1  } ),
);

has 'set_RADIO_NUMBER' => (
		is => 'rw',
		trigger  => sub { my ($self,$new) = @_; $RADIO_NUMBER = $new;  $self->RADIO_NUMBER($new) }
);

our $RADIO_MANUFACTURER;

subtype 'radio_manufacturer_type',
        => as 'Str'
       => where { $RADIO_MANUFACTURER ? uc($_) eq uc($RADIO_MANUFACTURER) : 1  }
	   => message {"
	   obtenu $_
	      	   
	   ***************
	   Verifiez neanmoins la valeur attendue de RADIO_MANUFACTURER dans le fichier de configuration (campagne.cfg)
	   ***************
	   "};	

has 'RADIO_MANUFACTURER' => (
		is => 'rw',
		isa => 'radio_manufacturer_type'
#		isa => subtype( 'Str' => where { $RADIO_MANUFACTURER ? uc($_) eq uc($RADIO_MANUFACTURER) : 1},
#						'message' => {"bof bof"} 
#						),
);

has 'set_RADIO_MANUFACTURER' => (
		is => 'rw',
		trigger  => sub { my ($self,$new) = @_; $RADIO_MANUFACTURER = $new;  $self->RADIO_MANUFACTURER($new) }
);

subtype 'unchecked',
        => as 'Str'
       => where { return 1;  }
	   => message {"non vérifié, ok"};

our $METER_NUMBER;

subtype 'meter_number_type',
        => as 'Str'
       => where { $METER_NUMBER ? uc($_) eq uc($METER_NUMBER) : 1  }
	   => message {"
	   obtenu $_
	      	   
	   ***************
	   Verifiez neanmoins la valeur attendue de METER_NUMBER dans le fichier de configuration (campagne.cfg)
	   ***************
	   "};	

has 'METER_NUMBER' => (
		is => 'rw',
		isa => 'meter_number_type'
		#isa => subtype( 'Str' => where { $METER_NUMBER ? uc($_) eq uc($METER_NUMBER) : 1 } ),
);
has 'set_METER_NUMBER' => (
		is => 'rw',
		trigger  => sub { my ($self,$new) = @_; $METER_NUMBER = $new;  $self->METER_NUMBER($new) }
);


our $METER_MANUFACTURER;
#inutile
subtype 'meter_manufacturer_type',
        => as 'Str'
       => where { $METER_NUMBER ? uc($_) eq uc($METER_NUMBER) : 1  }
	   => message {"
	   obtenu $_
	      	   
	   ***************
	   Verifiez neanmoins la valeur attendue de METER_NUMBER dans le fichier de configuration (campagne.cfg)
	   ***************
	   "};	

has 'METER_MANUFACTURER' => (
		is => 'rw',
		isa => 'intervalle_0_to_99'
		#isa => subtype( 'Str' => where {  $_ eq $METER_MANUFACTURER  } ),
);

has 'set_METER_MANUFACTURER' => (
		is => 'rw',
		trigger  => sub { my ($self,$new) = @_; $METER_MANUFACTURER = $new; # $self->METER_MANUFACTURER($new) 
		}
);

our $MASTER_PWD;
has 'MASTER_PWD' => (
		is => 'rw',
		isa => subtype( 'Str' => where { $MASTER_PWD ? uc($_) eq uc($MASTER_PWD) : 1  } ),
);
has 'set_MASTER_PWD' => (
		is => 'rw',
		trigger  => sub { my ($self,$new) = @_; $MASTER_PWD = $new;  $self->MASTER_PWD($new) }
);

our $INTEGRATOR_PWD;
has 'INTEGRATOR_PWD' => (
		is => 'rw',
		isa => subtype( 'Str' => where {  uc($_) eq uc($INTEGRATOR_PWD)  } ),
);
has 'set_INTEGRATOR_PWD' => (
		is => 'rw',
		trigger  => sub { my ($self,$new) = @_; $INTEGRATOR_PWD = $new;  $self->INTEGRATOR_PWD($new) }
);


has 'HEURE_GAZIERE' => (
		is => 'rw',
		isa => 'enum_heure_gaziere'
);

has 'PAS_MESURE' => (
		is => 'rw',
		isa => 'enum_04'
);

has 'TFEN_TELERELEVE' => (
		is => 'rw',
		isa => 'bits_8'
);

has 'NB_FENETRE_JOUR' => (
		is => 'rw',
		isa => 'enum_04'
);

has 'NB_FENETRE_HOR' => (
		is => 'rw',
		isa => 'enum_02'
);

has 'CFGFRAME_PERIOD' => (
		is => 'rw',
		isa => 'enum_04'
);

has 'NB_FENETRE_CFG' => (
		is => 'rw',
		isa => 'enum_02'
);

has 'NB_FENETRE_SUP' => (
		is => 'rw',
		isa => 'enum_02'
);

has 'INTRADAY' => (
		is => 'rw',
		isa => 'enum_02'
);

has 'NB_FENETRE_INTRA' => (
		is => 'rw',
		isa => 'enum_04'
);

has 'TFEN_INTRADAY' => (
		is => 'rw',
		isa => 'bits_40'
);

has 'INDEX' => (
		is => 'rw',
		isa => 'bits_32'
);

has 'VIF' => (
		is => 'rw',
		isa => 'enum_07'
);

has 'ECART_INDEX_LATEST' => (
		is => 'rw',
		isa => 'octets_13'
);

has 'SENSOR_STATUS' => (
		is => 'rw',
		isa => 'enum_03'
);

has 'SURVEILLANCE' => (
		is => 'rw',
		isa => 'enum_02'
);

has 'VECTEUR_ETAT' => (
		is => 'rw',
		isa => 'bits_16'
);

has 'FRAUDE' => (
		is => 'rw',
		isa => 'bits_8'
);

has 'CURRENT_STATE' => (
		is => 'rw',
		isa => 'enum_06'
);

has 'FLAG_DELAY' => (
		is => 'rw',
		isa => 'intervalle_15'
);

has 'INTERFACE_RADIO' => (
		is => 'rw',
		isa => 'enum_02'
);

has 'CFGFRAME_SEND' => (
		is => 'rw',
		isa => 'enum_02'
);

has 'SORTIE_CLIENT' => (
		is => 'rw',
		isa => 'enum_02'
);

has 'BACKUP_METERING' => (
		is => 'rw',
		isa => 'enum_02'
);

has 'BACKUP_LOG' => (
		is => 'rw',
		isa => 'enum_02'
);

has 'BACKUP_TECHNICAL' => (
		is => 'rw',
		isa => 'enum_02'
);

has 'TRACE_MODE' => (
		is => 'rw',
		isa => 'enum_02'
);

has 'BITMAP' => (
		is => 'rw',
		isa => 'bits_8'
);

has 'DAYLIGHT_SAV' => (
		is => 'rw',
		isa => 'enum_02'
);

has 'DAYLIGHT_SAV_MOD' => (
		is => 'rw',
		isa => 'octets_7'
);

has 'EVENT_LOG_LATEST' => (
		is => 'rw',
		isa => 'event_log_length'
);

has 'EVENT_LOG_PART1' => (
		is => 'rw',
		isa => 'octets_36'
);

has 'EVENT_LOG_PART2' => (
		is => 'rw',
		isa => 'octets_36'
);

has 'EVENT_LOG_PART3' => (
		is => 'rw',
		isa => 'octets_36'
);

has 'EVENT_LOG_PART4' => (
		is => 'rw',
		isa => 'octets_36'
);

has 'EVENT_LOG_PART5' => (
		is => 'rw',
		isa => 'octets_36'
);

has 'EVENT_LOG_PART6' => (
		is => 'rw',
		isa => 'octets_36'
);

has 'ECART_INDEX_PART1' => (
		is => 'rw',
		isa => 'octets_37'
);

has 'ECART_INDEX_PART2' => (
		is => 'rw',
		isa => 'octets_37'
);

has 'ECART_INDEX_PART3' => (
		is => 'rw',
		isa => 'octets_37'
);

has 'ECART_INDEX_PART4' => (
		is => 'rw',
		isa => 'octets_37'
);

has 'ECART_INDEX_PART5' => (
		is => 'rw',
		isa => 'octets_37'
);

has 'ECART_INDEX_PART6' => (
		is => 'rw',
		isa => 'octets_37'
);

has 'ECART_INDEX_PART7' => (
		is => 'rw',
		isa => 'octets_25'
);

has 'INSTFRAME_DELAY' => (
		is => 'rw',
		isa => 'bits_8'
);

has 'K_MOB' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'VERSION_REFERENTIEL' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'EPOCH_REFERENTIEL' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'DUREE_REPONSE_INTERFACE' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'MODULE_TYPE' => (
		is => 'rw',
		isa => 'enum_02'
);

has 'INTEGRATION_MODE' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'NEXT_TIME_EVENT' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'NEXT_EVENT' => (
		is => 'rw',
	#	isa => 'enum_next_event'
		isa => 'unchecked',
);

has 'IMMEDIAT_SEEK_TIME' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'TRACE_ENABLE' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'SEND_IMMEDIAT_TEST_FRAME' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'SEND_SEVERAL_TESTS_FRAMES' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'CONT_REC_IMMEDIAT' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'CPT_REC' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'USE_KEY_ENC_TEST' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'USE_KMAC_TEST' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'CPT_RESET' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'RAZ_DEFAUT' => (
		is => 'rw',
		isa => 'unchecked'
);

#paramètres des autres commandes, ping, etc

has 'L7DwnldId' => (
    is => 'rw',
);

has 'L7Klog' => (
    is => 'rw',
);

has 'L7HwVersion' => (
    is => 'rw',
);

has 'L7SwVersionIni' => (
    is => 'rw',
);

has 'L7SwVersionTarget' => (
    is => 'rw',
);

has 'L7MField' => (
    is => 'rw',
);

has 'L7DcHwId' => (
    is => 'rw',
);

has 'L7BlocksCount' => (
    is => 'rw',
);

has 'BlocksCount' => (
    is => 'rw',
);

has 'L7ChannelId' => (
    is => 'rw',
);

has 'L7ModulationId' => (
    is => 'rw',
);

has 'L7DaysProg' => (
    is => 'rw',
);

has 'L7DaysRepeat' => (
    is => 'rw',
);

has 'L7DeltaSec' => (
    is => 'rw',
);

has 'HashSW' => (
    is => 'rw',
);

has 'SwSize' => (
    is => 'rw',
);

has 'Vsoftmaj' => (
    is => 'rw',
);

has 'L7KeyVal' => (
	is => 'rw',
);

has 'L7DownChannel' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'L7DownMod' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'L7PingRxDelay' => (
		is => 'rw',
		isa => 'unchecked'
);

has 'L7PingRxLength' => (
		is => 'rw',
		isa => 'unchecked'
);

#éléments des trames RESPONSE lan

has 'L7Rssi' => (
	is 		=> 'rw',
	isa => 'intervalle_255'
);


has 'L7Rssi_up' => (
	is 		=> 'rw',
);


has 'L7Rssi_down' => (
	is 		=> 'rw',
);


#L7SwVersion
our $L7SwVersion;
subtype 'L7SwVersion_type',
        => as 'Str'
       => where { $L7SwVersion ? uc($_) eq uc($L7SwVersion) : 1  }
	   => message {"
	   obtenu $_
	      	   
	   ***************
	   Verifiez neanmoins la valeur attendue de L7SwVersion dans le fichier de configuration (campagne.cfg)
	   ***************
	   "};
	   
has 'L7SwVersion' => (
		is => 'rw',
		isa => 'L7SwVersion_type'
#		isa => subtype( 'Str' => where { $L7SwVersion ? $_ eq $L7SwVersion : 1 } ),
);
has 'set_L7SwVersion' => (
		is => 'rw',
		trigger  => sub { my ($self,$new) = @_; $L7SwVersion = $new;  $self->L7SwVersion($new) }
);

our $L7ConcentId;
subtype 'L7ConcentId_type',
        => as 'Str'
       => where { $L7ConcentId ? uc($_) eq uc($L7ConcentId) : 1  }
	   => message {"
	   obtenu $_
	      	   
	   ***************
	   Verifiez neanmoins la valeur attendue de L7ConcentId dans le fichier de configuration (campagne.cfg)
	   ***************
	   "};
has 'L7ConcentId' => (
		is => 'rw',
		isa => 'L7ConcentId_type'
);

has 'set_L7ConcentId' => (
		is => 'rw',
		trigger  => sub { my ($self,$new) = @_; $L7ConcentId = $new;  $self->L7ConcentId($new) }
);

our $L7ModemId;
has 'L7ModemId' => (
		is => 'rw',
		isa => subtype( 'Str' => where { $L7ModemId ? $_ eq $L7ModemId : 1 } ),
);
has 'set_L7ModemId' => (
		is => 'rw',
		trigger  => sub { my ($self,$new) = @_; $L7ModemId = $new;  $self->L7ModemId($new) }
);

#sous-éléments extraits de paramètres
has 'row_event_log' => (
		is => 'rw',
);

has 'TIMESTAMP' => (
		is => 'rw',
		isa => 'bits_32'
);

has 'EVENT_REPEAT' => (
		is => 'rw',
		isa => 'bits_8'
);

our $EVENT_DATA;
has 'EVENT_DATA'  =>(
	is 		=> 'rw',
);

has 'set_EVENT_DATA' => (
		is => 'rw',
		trigger  => sub { my ($self,$new) = @_; $EVENT_DATA = $new;   }
);

before 'EVENT_DATA' => sub {
     my ($self,$newone) = @_;
    if ($newone && $EVENT_DATA) {
        if ( ( hex($newone) & hex($EVENT_DATA)) == 0) {
            die "data not match ($newone <=> $EVENT_DATA)";
        }
    }
};

our $EVENT_TYPE;
has 'EVENT_TYPE'  => (
	is 		=> 'rw',
);

has 'set_EVENT_TYPE' => (
		is => 'rw',
		trigger  => sub { my ($self,$new) = @_; $EVENT_TYPE = $new;   }
);

before 'EVENT_TYPE' => sub {
     my ($self,$newone) = @_;
    if ($newone && $EVENT_TYPE) {
        if ( ( hex($newone) & hex($EVENT_TYPE)) == 0) {
            die "data not match ($newone <=> $EVENT_TYPE)";
        }
    }
};

#controles des valeurs de la couche de liaison

has 'Afield' => (
		is => 'rw',
		isa => 'octets_6'
);

has 'Cfield' => (
		is => 'rw',
		isa => 'bits_8'
);

has 'Mfield' => (
		is => 'rw',
		isa => 'bits_16'
);

has 'Lfield' => (
		is => 'rw',
		isa => 'bits_8'
);

has 'CRC' => (
		is => 'rw',
		isa => 'bits_16'
);


=head2 hash des paramètres attendus par id

Méthodes attendus

exists_parameter_id

	if ($objet->exists_parameter_id('04')) {
		say "Aucun id de ce type dans la liste";
	}

get_parameter_name_by_id

	my $valeur = $objet->get_parameter_name_by_id('78');
		#nom
		say $valeur->[0];
		#longueur en octet
		say $valeur->[1];
		
add_parameter_name_by_id
		
		#Ajouter un parametre
		$objet->add_parameter_name_by_id( '8A' => ['NEW_PARAM',2]);

parameters_id_pairs
		
		#Lister les parametres et leurs valeurs
		
		for my $pair ( $objet->parameters_id_pairs ) {
			print "$pair->[0] = $pair->[1][0]\n";
		}

list_parameters_id_keys
		
		#Liste des parametres seuls
		my @liste_params = $objet->list_parameters_id_keys();



=cut

has 'parameters_id' => (
	  traits    => ['Hash'],
	  is        => 'ro',
	  isa       => 'HashRef',
	  default   => sub { {
			'01'    =>  ['VERS_HW_TRX',2],
			'02'    =>  ['VERS_FW_TRX',2],
			'03'    =>  ['DATEHOUR_LAST_UPDATE',4],
			'08'    =>  ['RF_UPSTREAM_CHANNEL',1],
			'09'    =>  ['RF_DOWNSTREAM_CHANNEL',1],
			'0A'    =>  ['RF_UPSTREAM_MOD',1],
			'0B'    =>  ['RF_DOWNSTREAM_MOD',1],
			'10'    =>  ['TX_POWER',1],
			'11'    =>  ['TX_DELAY_FULLPOWER',2],
			'12'    =>  ['TX_FREQ_OFFSET',2],
			'18'    =>  ['EXCH_RX_DELAY',1],
			'19'    =>  ['EXCH_RX_LENGTH',1],
			'1A'    =>  ['EXCH_RESPONSE_DELAY',1],
			'1B'    =>  ['EXCH_RESPONSE_DELAY_MIN',1],
			'1C'    =>  ['L7TRANSMIT_LENGTH_MAX',1],
			'1D'    =>  ['L7RECEIVE_LENGTH_MAX',1],
			'20'    =>  ['CLOCK_CURRENT_EPOC',4],
			'21'    =>  ['CLOCK_OFFSET_CORRECTION',2],
			'22'    =>  ['CLOCK_DRIFT_CORRECTION',2],
			'28'    =>  ['CIPH_CURRENT_KEY',1],
			'29'    =>  ['CIPH_KEY_COUNT',1],
			'30'    =>  ['PING_RX_DELAY',1],
			'31'    =>  ['PING_RX_LENGTH',1],
			'32'    =>  ['PING_RX_DELAY_MIN',1],
			'33'    =>  ['PING_RX_LENGTH_MAX',1],
			'34'    =>  ['PING_LAST_EPOCH',4],
			'35'    =>  ['PING_NBFOUND',1],
			'36'    =>  ['PING_REPLY1',9],
			'37'    =>  ['PING_REPLY2',9],
			'38'    =>  ['PING_REPLY3',9],
			'39'    =>  ['PING_REPLY4',9],
			'3A'    =>  ['PING_REPLY5',9],
			'3B'    =>  ['PING_REPLY6',9],
			'3C'    =>  ['PING_REPLY7',9],			
			'3D'    =>  ['PING_REPLY8',9],
			'60'    =>  ['RADIO_NUMBER',6],
			'61'    =>  ['RADIO_MANUFACTURER',2],
			'62'    =>  ['METER_NUMBER',6],
			'63'    =>  ['METER_MANUFACTURER',1],
			'64'    =>  ['MASTER_PWD',8],
			'65'    =>  ['INTEGRATOR_PWD',8],
			'66'    =>  ['HEURE_GAZIERE',2],
			'67'    =>  ['PAS_MESURE',1],
			'68'    =>  ['TFEN_TELERELEVE',1],
			'69'    =>  ['NB_FENETRE_JOUR',1],
			'6A'    =>  ['NB_FENETRE_HOR',1],
			'6B'    =>  ['CFGFRAME_PERIOD',1],
			'6C'    =>  ['NB_FENETRE_CFG',1],
			'6D'    =>  ['NB_FENETRE_SUP',1],
			'6E'    =>  ['INTRADAY',1],
			'6F'    =>  ['NB_FENETRE_INTRA',1],
			'70'    =>  ['TFEN_INTRADAY',5],
			'71'    =>  ['INDEX',4],
			'72'    =>  ['VIF',1],
			'73'    =>  ['ECART_INDEX_LATEST',13],
			'74'    =>  ['SENSOR_STATUS',1],
			'75'    =>  ['SURVEILLANCE',1],
			'76'    =>  ['VECTEUR_ETAT',2],
			'77'    =>  ['FRAUDE',1],
			'78'    =>  ['CURRENT_STATE',1],
			'79'    =>  ['FLAG_DELAY',1],
			'7A'    =>  ['INTERFACE_RADIO',1],
			'7B'    =>  ['CFGFRAME_SEND',1],
			'7C'    =>  ['SORTIE_CLIENT',1],
			'7D'    =>  ['BACKUP_METERING',1],
			'7E'    =>  ['BACKUP_LOG',1],
			'7F'    =>  ['BACKUP_TECHNICAL',1],
			'80'    =>  ['TRACE_MODE',1],
			'81'    =>  ['BITMAP',1],
			'82'    =>  ['DAYLIGHT_SAV',1],
			'83'    =>  ['DAYLIGHT_SAV_MOD',7],
			'84'    =>  ['EVENT_LOG_LATEST',8],
			'85'    =>  ['EVENT_LOG_PART1',36],
			'86'    =>  ['EVENT_LOG_PART2',36],
			'87'    =>  ['EVENT_LOG_PART3',36],
			'88'    =>  ['EVENT_LOG_PART4',36],
			'89'    =>  ['EVENT_LOG_PART5',36],	
			'8A'    =>  ['EVENT_LOG_PART6',36],
			'8B'    =>  ['ECART_INDEX_PART1',37],
			'8C'    =>  ['ECART_INDEX_PART2',37],
			'8D'    =>  ['ECART_INDEX_PART3',37],
			'8E'    =>  ['ECART_INDEX_PART4',37],
			'8F'    =>  ['ECART_INDEX_PART5',37],
			'90'    =>  ['ECART_INDEX_PART6',37],
			'91'    =>  ['ECART_INDEX_PART7',25],
			'92'    =>  ['INSTFRAME_DELAY',1],
			'93'    =>  ['K_MOB',16],
			'94'    =>  ['VERSION_REFERENTIEL',1],
			'95'    =>  ['EPOCH_REFERENTIEL',4],
			'96'    =>  ['DUREE_REPONSE_INTERFACE',1],
			'97'    =>  ['MODULE_TYPE',1],	
			'F0'    =>  ['INTEGRATION_MODE',1],
			'F1'    =>  ['NEXT_TIME_EVENT',2],
			'F2'    =>  ['NEXT_EVENT',1],
			'F3'    =>  ['IMMEDIAT_SEEK_TIME',2],
			'F4'    =>  ['TRACE_ENABLE',1],
			'F5'    =>  ['SEND_IMMEDIAT_TEST_FRAME',40],
			'F6'    =>  ['SEND_SEVERAL_TESTS_FRAMES',41],
			'F7'    =>  ['CONT_REC_IMMEDIAT',1],
			'F8'    =>  ['CPT_REC',10],
			'F9'    =>  ['USE_KEY_ENC_TEST',17],
			'FA'    =>  ['USE_KMAC_TEST',16],
			'FB'    =>  ['CPT_RESET',12],
			'FC'    =>  ['RAZ_DEFAUT',1],	
	  } },
	  handles   => {
		  get_parameter_name_by_id     => 'get',
		  add_parameter_name_by_id     => 'set',
		  parameters_id_pairs   	=> 'kv',
		  list_parameters_id_keys 		=> 'keys',
		  exists_parameter_id     => 'exists',
	  },
);

=head2 Hash des paramètres par nom

Même chose que ci-dessus, mais par nom

Méthodes disponibles:

exists_parameter_name

	Vérifie si un paramètre existe.
	
	unless ($objet->exists_parameter_name('PORTNAWAK')) {
		print "Paramètre inconnu";
	}

get_parameter_id_by_name

	my $valeur = $objet->get_parameter_id_by_name('NEXT_EVENT');
		#nom
		say $valeur->[0];
		#longueur
		say $valeur->[1];
		
add_parameter_id_by_name
		
		#Ajouter un parametre
		$objet->add_parameter_id_by_name( 'AUTRE' => ['8A',2]);

parameters_name_pairs
		
		#Lister les parametres et leurs valeurs
		
		for my $pair ( $objet->parameters_name_pairs ) {
			print "$pair->[0] = $pair->[1][0]\n";
		}

list_parameters_name_keys
		
		#Liste des parametres seuls
		my @liste_params = $objet->list_parameters_name_keys();


=cut
has 'parameters_name' => (
	  traits    => ['Hash'],
	  is        => 'ro',
	  isa       => 'HashRef',
	  default   => sub { {
    'VERS_HW_TRX' => ['01',2],
    'VERS_FW_TRX' => ['02',2],
    'DATEHOUR_LAST_UPDATE' => ['03',4],
    'RF_UPSTREAM_CHANNEL' => ['08',1],
    'RF_DOWNSTREAM_CHANNEL' => ['09',1],
    'RF_UPSTREAM_MOD' => ['0A',1],
    'RF_DOWNSTREAM_MOD' => ['0B',1],
    'TX_POWER' => ['10',1],
    'TX_DELAY_FULLPOWER' => ['11',2],
    'TX_FREQ_OFFSET' => ['12',2],
    'EXCH_RX_DELAY' => ['18',1],
    'EXCH_RX_LENGTH' => ['19',1],
    'EXCH_RESPONSE_DELAY' => ['1A',1],
    'EXCH_RESPONSE_DELAY_MIN' => ['1B',1],
    'L7TRANSMIT_LENGTH_MAX' => ['1C',1],
    'L7RECEIVE_LENGTH_MAX' => ['1D',1],
    'CLOCK_CURRENT_EPOC' => ['20',4],
    'CLOCK_OFFSET_CORRECTION' => ['21',2],
    'CLOCK_DRIFT_CORRECTION' => ['22',2],
    'CIPH_CURRENT_KEY' => ['28',1],
    'CIPH_KEY_COUNT' => ['29',1],
    'PING_RX_DELAY' => ['30',1],
    'PING_RX_LENGTH' => ['31',1],
    'PING_RX_DELAY_MIN' => ['32',1],
    'PING_RX_LENGTH_MAX' => ['33',1],
    'PING_LAST_EPOCH' => ['34',4],
    'PING_NBFOUND' => ['35',1],
    'PING_REPLY1' => ['36',9,'check_ping'],
    'PING_REPLY2' => ['37',9,'check_ping'],
    'PING_REPLY3' => ['38',9,'check_ping'],
    'PING_REPLY4' => ['39',9,'check_ping'],
    'PING_REPLY5' => ['3A',9,'check_ping'],
    'PING_REPLY6' => ['3B',9,'check_ping'],
    'PING_REPLY7' => ['3C',9,'check_ping'],
    'PING_REPLY8' => ['3D',9,'check_ping'],
    'RADIO_NUMBER' => ['60',6],
    'RADIO_MANUFACTURER' => ['61',2],
    'METER_NUMBER' => ['62',6],
    'METER_MANUFACTURER' => ['63',1],
    'MASTER_PWD' => ['64',8],
    'INTEGRATOR_PWD' => ['65',8],
    'HEURE_GAZIERE' => ['66',2],
    'PAS_MESURE' => ['67',1],
    'TFEN_TELERELEVE' => ['68',1],
    'NB_FENETRE_JOUR' => ['69',1],
    'NB_FENETRE_HOR' => ['6A',1],
    'CFGFRAME_PERIOD' => ['6B',1],
    'NB_FENETRE_CFG' => ['6C',1],
    'NB_FENETRE_SUP' => ['6D',1],
    'INTRADAY' => ['6E',1],
    'NB_FENETRE_INTRA' => ['6F',1],
    'TFEN_INTRADAY' => ['70',5],
    'INDEX' => ['71',4],
    'VIF' => ['72',1],
    'ECART_INDEX_LATEST' => ['73',13],
    'SENSOR_STATUS' => ['74',1],
    'SURVEILLANCE' => ['75',1],
    'VECTEUR_ETAT' => ['76',2],
    'FRAUDE' => ['77',1],
    'CURRENT_STATE' => ['78',1],
    'FLAG_DELAY' => ['79',1],
    'INTERFACE_RADIO' => ['7A',1],
    'CFGFRAME_SEND' => ['7B',1],
    'SORTIE_CLIENT' => ['7C',1,],
    'BACKUP_METERING' => ['7D',1],
    'BACKUP_LOG' => ['7E',1],
    'BACKUP_TECHNICAL' => ['7F',1],
    'TRACE_MODE' => ['80',1],
    'BITMAP' => ['81',1],
    'DAYLIGHT_SAV' => ['82',1],
    'DAYLIGHT_SAV_MOD' => ['83',7],
    'EVENT_LOG_LATEST' => ['84',8],
    'EVENT_LOG_PART1' => ['85',36],
    'EVENT_LOG_PART2' => ['86',36],
    'EVENT_LOG_PART3' => ['87',36],
    'EVENT_LOG_PART4' => ['88',36],
    'EVENT_LOG_PART5' => ['89',36],
    'EVENT_LOG_PART6' => ['8A',36],
    'ECART_INDEX_PART1' => ['8B',37],
    'ECART_INDEX_PART2' => ['8C',37],
    'ECART_INDEX_PART3' => ['8D',37],
    'ECART_INDEX_PART4' => ['8E',37],
    'ECART_INDEX_PART5' => ['8F',37],
    'ECART_INDEX_PART6' => ['90',37],
    'ECART_INDEX_PART7' => ['91',25],
    'INSTFRAME_DELAY' => ['92',1],
    'K_MOB' => ['93',16],
    'VERSION_REFERENTIEL' => ['94',1],
    'EPOCH_REFERENTIEL' => ['95',4],
    'DUREE_REPONSE_INTERFACE' => ['96',1],
    'MODULE_TYPE' => ['97',1],
    'INTEGRATION_MODE' => ['F0',1],
    'NEXT_TIME_EVENT' => ['F1',2],
    'NEXT_EVENT' => ['F2',1],
    'IMMEDIAT_SEEK_TIME' => ['F3',2],
    'TRACE_ENABLE' => ['F4',1],
    'SEND_IMMEDIAT_TEST_FRAME' => ['F5',40],
    'SEND_SEVERAL_TESTS_FRAMES' => ['F6',41],
    'CONT_REC_IMMEDIAT' => ['F7',1],
    'CPT_REC' => ['F8',10],
    'USE_KEY_ENC_TEST' => ['F9',17],
    'USE_KMAC_TEST' => ['FA',16],
    'CPT_RESET' => ['FB',12],
    'RAZ_DEFAUT' => ['FC',1],
	  } },
	  handles   => {
		  get_parameter_id_by_name     => 'get',
		  add_parameter_id_by_name     => 'set',
		  parameters_name_pairs   	=> 'kv',
		  list_parameters_name_keys 		=> 'keys',
		  exists_parameter_name 		=> 'exists',
	  },
);	  

=head2 vif

Translation du vif en litres

my $litres = $objet->get_vif('01');

=cut
has 'vif' => (
	  traits    => ['Hash'],
	  is        => 'ro',
	  isa       => 'HashRef',
	  default   => sub { {
		'00'	=> 1,
		'01'	=> 10,
		'02'	=> 100,
		'03'	=> 100,
		'04'	=> 1000,
		'05'	=> 10000,
		'06'	=> 0.5,
		'07'	=> 0.1,	
	  } },
	  handles   => {
		  get_vif	     => 'get',
		  list_vif 		=> 'keys',
	  },
);

=head2 defaut

Dans les event log latest, dictionnaire des réponses pour le type d'évent 08/09/0B

methodes

	get_defaut
	
	list_defaut

=cut
has 'defaut' => (
	  traits    => ['Hash'],
	  is        => 'ro',
	  isa       => 'HashRef',
	  default   => sub { {
			'00' => 'Pas de defaut detecte.',
			'01' => 'Defaut NFC (la puce est inaccessible en lecture ou en ecriture)',
			'02' => 'L\'interface radio hardware est inaccessible',
			'04' => 'Probleme d\'alimentation de l\'interface radio',
			'08' => 'Erreur detectee dans la memoire (microcontroleur ou NFC)',
			'10' => 'Aucune commande du SIAS recue depuis TX_DELAY_FULLPOWER',
			'20' => 'Detection d\'une sous-tension sur le bloc pile',
			'40' => 'Defaut d’integrite de l\'index electronique (cf. 7.2)',
			'80' => 'Reserve pour evolution future',
	  } },
	  handles   => {
		  get_defaut	     => 'get',
		  list_defaut 		=> 'keys',
	  },
);

=head2 fraude

Liste des types de fraude

Méthodes

	get_fraude
	
	list_fraude

=cut
has 'fraude' => (
	  traits    => ['Hash'],
	  is        => 'ro',
	  isa       => 'HashRef',
	  default   => sub { {
		'00' => 'Pas de fraude detectee',
		'01' => 'Presence d\'un champ magnetique anormalement fort',
		'02' => 'Suspicion de fraude : plus de 32 acces par jour a l\'interface locale',
		'04' => 'Demontage du module radio integre',
		'08' => 'Defaut de montage du module radio integre',
		'10' => 'Tentative de fraude sur le capteur inductif du module radio integre',
		'20' => 'Activation de la ligne surveillance de l\'interface PISMD du module deporte',
		'40' => 'Plage reservee aux evolutions futures',

	  } },
	  handles   => {
		  get_fraude	     => 'get',
		  list_fraude 		=> 'keys',
	  },
);

=head2 get_fraudes

Détails des fraudes recensées par une entrée event_log

Exemple:

	my $fraudes = $local->get_fraudes($event_log->[3]);
	foreach my $fraude (keys %$fraudes) {
		say "$fraude       : " . $fraudes->{$fraude};
	}	

Paramètres

	$value: chaine hexa contenant la valeur

Retourne:

	hashref des différentes types d'erreurs rencontrés avec leur nom

=cut
sub get_fraudes {
	my ($self,$value) = @_;
	my @erreurs = ();
	if (hex($value) == 0) {
		return {0 => $self->get_fraude('00')};
	}
	foreach my $ref ( 1, 2, 4, 8  ) {
		push(@erreurs, sprintf("%02X" , (($value & $ref) >> 0)) );
	}
	foreach my $ref ( 1, 2, 4, 8  ) {
		push(@erreurs, sprintf("%02X",((( (($value & 0xf0) >> 4) & $ref  ) >> 0) << 4)));
	}
	my %erreurs = ();
	foreach my $erreur (@erreurs) {
		$erreurs{$erreur} =  $self->get_fraude($erreur) if $erreur != 0;
	}
	return \%erreurs;
}

=head2 get_defauts

Détails des defauts recensés par une entrée event_log

Exemple:

	my $defauts = $local->get_defauts($event_log_value);
	foreach my $defaut (keys %$defauts) {
		say "$defaut       : " . $defauts->{$defaut}; 
	}	

Paramètres

	$value: chaine hexa contenant la valeur

Retourne:

	hashref des différentes types d'erreurs rencontrés avec leur nom


=cut

sub get_defauts {
	my ($self,$value) = @_;
	my @erreurs = ();
	if (hex($value) == 0) {
		return {0 => $self->get_defaut('00')};
	}
	foreach my $ref ( 1, 2, 4, 8  ) {
		push(@erreurs, sprintf("%02X" , (($value & $ref) >> 0)) );
	}
	foreach my $ref ( 1, 2, 4, 8  ) {
		push(@erreurs, sprintf("%02X",((( (($value & 0xf0) >> 4) & $ref  ) >> 0) << 4)));
	}
	my %erreurs = ();
	foreach my $erreur (@erreurs) {
		$erreurs{$erreur} =  $self->get_defaut($erreur) if $erreur != 0;
	}
	return \%erreurs;
}

=head2 get_resets

Détails des reset recensés par une entrée event_log

exemple:

	my $resets = $local->get_resets($event_log->[3]);
	foreach my $reset (keys %$resets) {
		say "$reset       : " . $resets->{$reset};
	}

Paramètres

	$value: chaine hexa contenant la valeur

Retourne:

	hashref des différentes types d'erreurs rencontrés avec leur nom
	
=cut
sub get_resets {
	my ($self,$value) = @_;
	my @erreurs = ();
	if (hex($value) == 0) {
		return {0 => $self->get_reset('00')};
	}
	foreach my $ref ( 1, 2, 4, 8  ) {
		push(@erreurs, sprintf("%02X" , (($value & $ref) >> 0)) );
	}
	foreach my $ref ( 1, 2, 4, 8  ) {
		push(@erreurs, sprintf("%02X",((( (($value & 0xf0) >> 4) & $ref  ) >> 0) << 4)));
	}
	my %erreurs = ();
	foreach my $erreur (@erreurs) {
		$erreurs{$erreur} =  $self->get_reset($erreur) if $erreur != 0;
	}
	return \%erreurs;
}

=head2 reset

Liste des types de reset

Méthodes

	get_reset
	
	list_reset

=cut
has 'reset' => (
	  traits    => ['Hash'],
	  is        => 'ro',
	  isa       => 'HashRef',
	  default   => sub { {
		'00' => 'Redemarrage a froid',
		'01' => 'Redemarrage suite a l\'activation du watchdog',
		'02' => 'Redemarrage suite a une mise a jour logicielle reussie',
		'04' => 'Redemarrage suite a un retour arriere du logiciel (cf. 7.10)',
		'08' => 'Redemarrage suite a une exception logicielle',
		'10' => 'Autre cause',
		'20' => 'Reserve aux evolutions futures',
	  } },
	  handles   => {
		  get_reset	     => 'get',
		  list_reset 		=> 'keys',
	  },
);

=head2 soc

Liste des types de sortie client

Méthodes

	get_soc
	
	list_soc

=cut
has 'soc' => (
	  traits    => ['Hash'],
	  is        => 'ro',
	  isa       => 'HashRef',
	  default   => sub { {
		'00' => 'sortie client inutilisee',
		'01' => 'Sortie client utilisee',
	  } },
	  handles   => {
		  get_soc     => 'get',
		  list_soc		=> 'keys',
	  },
);

=head2 event_types

Liste des types d'évenement

Méthodes

	get_soc
	
	list_soc

=cut
has 'event_types' => (
	  traits    => ['Hash'],
	  is        => 'ro',
	  isa       => 'HashRef',
	  default   => sub { {
				'00' => 'Acces local en lecture',
				'01' => 'Acces local en ecriture',
				'02' => 'Acces distant en lecture',
				'03' => 'Acces distant en ecriture',
				'04' => 'Annonce locale de mise a jour logicielle',
				'05' => 'Annonce distante de mise a jour logicielle',
				'06' => 'Reception d\'une trame INSTPONG',
				'07' => 'Changement d\'etat de la sortie client',
				'08' => 'Apparition d\'un defaut',
				'09' => 'Disparition d\'un defaut',
				'0A' => 'Changement de mode de fonctionnement',
				'0B' => 'Detection d\'une fraude',
				'0C' => 'Redemarrage du module radio',
				'0D' => 'Ecriture dans le registre d\'heure impliquant un decalage suite a une commande de mise a l\'heure locale',
				'0E' => 'Ecriture dans le registre d\'heure impliquant un decalage suite a une commande de mise a l\'heure distante',

	  } },
	  handles   => {
		  get_event_types     => 'get',
		  list_event_types	=> 'keys',
	  },
);



=head1 SUBROUTINES/METHODS

=cut

=head2 parse_event_log

Parse un event log récupéré de event_log_latest

Paramètres:

	chaîne héxa déchiffrée
	
Retourne:

	array
	
	$row,$timestamp, $repeat,$type,$data	
		

=cut
sub parse_event_log {
	my ($self,$event_log) = @_;
	my ($row,$timestamp, $repeat,$type,$data);
	if (length($event_log) == 16) {
		($row,$timestamp, $repeat,$type,$data) 
			= unpack("H2 H8 H2 H2 H2", pack('H*', $event_log));
	} else {
		($timestamp, $repeat,$type,$data) 
			= unpack("H8 H2 H2 H2", pack('H*', $event_log));		
	}
	return ($row,$timestamp, $repeat,$type,$data);
};


=head2 parse_event_log_part

Parse un event_log_part<n>

Paramètres:

	chaîne héxa déchiffrée
	
Retourne:

	array
	
	($row,arrayref des events)	

=cut
sub parse_event_log_part {
	my ($self,$event_log_part) = @_;
	my ($row,@parts) 
		= unpack("H2 H14 H14 H14 H14 H14", pack('H*', $event_log_part));
	my @event_log_parsed = ();
	foreach my $part (@parts) {
		my @parsed 
			= unpack("H8 H2 H2 H2", pack('H*', $part));
		push(@event_log_parsed,\@parsed);
	}
	return ($row,\@event_log_parsed);
}



=head1 AUTHOR

phv, C<< <philippe.devisme at suez-env.com> >>

=head1 BUGS

Please report any bugs or feature requests to Ondeo Systems.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Telereleve::Helper::CheckDatas

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014-2015 Ondeo Systems.

This program is NOT free software; you cannot redistribute it and/or modify it.

=cut

1; # End of Telereleve::Helper::CheckDatas
