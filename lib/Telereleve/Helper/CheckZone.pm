package Telereleve::Helper::CheckZone;

use Moose::Role;

use Carp;
use Moose::Util::TypeConstraints;

use feature qw(say);

use Data::Dumper;

=head1 NAME

Telereleve::Helper::CheckZone - CheckZone

=head1 VERSION

Version 0.5

=cut

our $VERSION = '0.5';

=head1 SYNOPSIS

Parse les données des différentes zones de données.

Rôle Moose, donc pas d'utilisation directe, mais transversale à travers d'autres librairies.

=cut

=head2 Zone de consommation

Gestion des éléments composant la zone de consommation, voir la sftd ddc

Après avoir parsé la zone de consommation, utiliser la méthode suivante: check_zone_conso($datas);

où $datas contient les infos sous forme de chaÎne hexa

	my $nfc = Telereleve::COM::NFC->new(config => 'nfc.cfg');

	my $zone = 'consommation';

	my @res = $nfc->read_zone($zone);
	my $datas = join '', @res;

	$local->check_zone_conso($datas);
	for my $data ( $local->all_consommation) {
		say "$data->[0] => $data->[1]";
	}	
	say "";
	say "details: ";
	say $local->get_consommation('epoch');
	say $local->get_consommation('jn-1-h0');
	say $local->get_consommation('jn-1-h0-1');
	say $local->get_consommation('jn-1-h0-2');
	
Liste des différentes valeurs disponibles, la valeur est retournée sous forme de chaîne héxa.	

        epoch    	4
        jn-1-h0     4
        jn-1-h0-1   2
        jn-1-h0-2   2
        jn-1-h0-3   2
        jn-1-h0-4   2
        jn-1-h0-5   2
        jn-1-h0-6   2
        jn-1-h0-7   2
        jn-1-h0-8   2
        jn-1-h0-9   2
        jn-1-h0-10  2
        jn-1-h0-11  2
        jn-1-h1     4
        jn-1-h1-1   2
        jn-1-h1-2   2
        jn-1-h1-3   2
        jn-1-h1-4   2
        jn-1-h1-5   2
        jn-1-h1-6   2
        jn-1-h1-7   2
        jn-1-h1-8   2
        jn-1-h1-9   2
        jn-1-h1-10  2
        jn-1-h1-11  2
        jn-2-h0     4
        jn-2-h0-1   2
        jn-2-h0-2   2
        jn-2-h0-3   2
        jn-2-h0-4   2
        jn-2-h0-5   2
        jn-2-h0-6   2
        jn-2-h0-7   2
        jn-2-h0-8   2
        jn-2-h0-9   2
        jn-2-h0-10  2
        jn-2-h0-11  2
        jn-2-h1     4
        jn-2-h1-1   2
        jn-2-h1-2   2
        jn-2-h1-3   2
        jn-2-h1-4   2
        jn-2-h1-5   2
        jn-2-h1-6   2
        jn-2-h1-7   2
        jn-2-h1-8   2
        jn-2-h1-9   2
        jn-2-h1-10  2
        jn-2-h1-11  2
        jn-3-h0     4
        jn-3-h0-1   2
        jn-3-h0-2   2
        jn-3-h0-3   2
        jn-3-h0-4   2
        jn-3-h0-5   2
        jn-3-h0-6   2
        jn-3-h0-7   2
        jn-3-h0-8   2
        jn-3-h0-9   2
        jn-3-h0-10  2
        jn-3-h0-11  2
        jn-3-h1     4
        jn-3-h1-1   2
        jn-3-h1-2   2
        jn-3-h1-3   2
        jn-3-h1-4   2
        jn-3-h1-5   2
        jn-3-h1-6   2
        jn-3-h1-7   2
        jn-3-h1-8   2
        jn-3-h1-9   2
        jn-3-h1-10  2
        jn-3-h1-11  2
        jn-3-h1     4


=cut

has 'tags_conso' => (
	traits  => ['Array'],
	is      => 'ro',
	isa     => 'ArrayRef',
	default => sub { [
        ["epoch",4],
        ["jn-1-h0",4],
        ["jn-1-h0-1",2],
        ["jn-1-h0-2",2],
        ["jn-1-h0-3",2],
        ["jn-1-h0-4",2],
        ["jn-1-h0-5",2],
        ["jn-1-h0-6",2],
        ["jn-1-h0-7",2],
        ["jn-1-h0-8",2],
        ["jn-1-h0-9",2],
        ["jn-1-h0-10",2],
        ["jn-1-h0-11",2],
        ["jn-1-h1",4],
        ["jn-1-h1-1",2],
        ["jn-1-h1-2",2],
        ["jn-1-h1-3",2],
        ["jn-1-h1-4",2],
        ["jn-1-h1-5",2],
        ["jn-1-h1-6",2],
        ["jn-1-h1-7",2],
        ["jn-1-h1-8",2],
        ["jn-1-h1-9",2],
        ["jn-1-h1-10",2],
        ["jn-1-h1-11",2],
        ["jn-2-h0",4],
        ["jn-2-h0-1",2],
        ["jn-2-h0-2",2],
        ["jn-2-h0-3",2],
        ["jn-2-h0-4",2],
        ["jn-2-h0-5",2],
        ["jn-2-h0-6",2],
        ["jn-2-h0-7",2],
        ["jn-2-h0-8",2],
        ["jn-2-h0-9",2],
        ["jn-2-h0-10",2],
        ["jn-2-h0-11",2],
        ["jn-2-h1",4],
        ["jn-2-h1-1",2],
        ["jn-2-h1-2",2],
        ["jn-2-h1-3",2],
        ["jn-2-h1-4",2],
        ["jn-2-h1-5",2],
        ["jn-2-h1-6",2],
        ["jn-2-h1-7",2],
        ["jn-2-h1-8",2],
        ["jn-2-h1-9",2],
        ["jn-2-h1-10",2],
        ["jn-2-h1-11",2],
        ["jn-3-h0",4],
        ["jn-3-h0-1",2],
        ["jn-3-h0-2",2],
        ["jn-3-h0-3",2],
        ["jn-3-h0-4",2],
        ["jn-3-h0-5",2],
        ["jn-3-h0-6",2],
        ["jn-3-h0-7",2],
        ["jn-3-h0-8",2],
        ["jn-3-h0-9",2],
        ["jn-3-h0-10",2],
        ["jn-3-h0-11",2],
        ["jn-3-h1",4],
        ["jn-3-h1-1",2],
        ["jn-3-h1-2",2],
        ["jn-3-h1-3",2],
        ["jn-3-h1-4",2],
        ["jn-3-h1-5",2],
        ["jn-3-h1-6",2],
        ["jn-3-h1-7",2],
        ["jn-3-h1-8",2],
        ["jn-3-h1-9",2],
        ["jn-3-h1-10",2],
        ["jn-3-h1-11",2],
	
	] },
	handles => {
		all_tags_conso    => 'elements',
		add_tags_conso     => 'push',
		filter_tags_conso => 'grep',
		find_tags_conso    => 'first',
		get_tags_conso     => 'get',
		count_tags_conso  => 'count',
	},
);


has 'tableau_des_consommations' => (
  traits    => ['Array'],
  is        => 'ro',
  isa       => 'ArrayRef',
  default   => sub { [] },
  handles   => {
            all_tab_conso    => 'elements',
            add_tab_conso     => 'push',
            get_tab_conso     => 'get',
            count_tab_conso  => 'count',
            has_tab_conso    => 'count',
            has_no_tab_conso => 'is_empty',
  },
);



has 'consommation' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {} },
  handles   => {
	  set_consommation     => 'set',
	  get_consommation     => 'get',
	  all_consommation   => 'kv',
  },
);


=head2 check_zone_conso

Parse la zone de consommation

voir aussi

tags_conso : liste des blocs de consommation
	
consommation: hash contenant la consommation pour chaque bloc
	
	my $conso_jn3_etc = $self->get_consommation("jn-3-h1-11");

Parametre:

	data: chaine hexa contenant la zone de conso

=cut	
sub check_zone_conso {
	my ($self,$datas) = @_;
	my (@parsed) = unpack("H8 H8 H4 H4 H4 H4 H4 H4 H4 H4 H4 H4 H4 H8 H4 H4 H4 H4 H4 H4 H4 H4 H4 H4 H4 H8 H4 H4 H4 H4 H4 H4 H4 H4 H4 H4 H4 H8 H4 H4 H4 H4 H4 H4 H4 H4 H4 H4 H4 H8 H4 H4 H4 H4 H4 H4 H4 H4 H4 H4 H4 H8 H4 H4 H4 H4 H4 H4 H4 H4 H4 H4 H4 H8",
			pack("H*",$datas)); 
	$self->add_tab_conso(@parsed);
	for (my $i =0 ; $i < $self->count_tags_conso ;$i++) {
		$self->set_consommation( $self->get_tags_conso($i)->[0] => $parsed[$i]);
	}
	return 0;
}


=head2 Zone de référentiel technique

Gestion des éléments de la zone de référentiel technique

Après avoir parsé la zone de référentiel technique, utiliser la méthode suivante: check_zone_technique($dats)

où $datas contient les infos sous forme de chaÎne hexa

	my $nfc = Telereleve::COM::NFC->new(config => 'nfc.cfg');

	my $zone = 'technique';

	my @res = $nfc->read_zone($zone);
	my $datas = join '', @res;
	
	$local->check_zone_technique($datas);
	for my $data ( $local->all_reftech) {
		say "$data->[0] => $data->[1]";
	}
	say "";
	say "details: ";
	say $local->get_reftech('CRC_REFERENTIEL');
	say $local->get_reftech('VERSION_REFERENTIEL');
	say $local->get_reftech('EPOCH_REFERENTIEL');
	say $local->get_reftech('RADIO_NUMBER');	

=cut

has 'tags_reftech' => (
	traits  => ['Array'],
	is      => 'ro',
	isa     => 'ArrayRef',
	default => sub { [
        ["CRC_REFERENTIEL",2],
		["Reserved",2],
        ["VERSION_REFERENTIEL",1],
        ["EPOCH_REFERENTIEL",4],
        ["RADIO_NUMBER",6],
        ["RADIO_MANUFACTURER",2],
        ["METER_NUMBER",6],
        ["METER_MANUFACTURER",1],
        ["HEURE_GAZIERE",2],
        ["TFEN_TELERELEVE ",1],
        ["AMR_CONFIG",3],
        ["ACTIVATION_BITS",1],
        ["TFEN_INTRADAY",5],
        ["INDEX",4],
        ["VIF",1],
        ["ECART_INDEX_LATEST",13],
        ["VECTEUR_ETAT",2],
        ["FRAUDE",1],
        ["FLAG_DELAY",1],
        ["BITMAP",1],
        ["INSTFRAME_DELAY",1],
        ["DAYLIGHT_SAV_SUMMER",6],
        ["DAYLIGHT_SAV_WINTER",6],
        ["NBRX_RADIO",4],
        ["NBTX_RADIO",4],
        ["NBECH_NFC",3],
        ["NBERR_KENC",2],
        ["NBERR_KMAC",2],
        ["NBERR_KMOB",2],
        ["L6CTP_METER",2],
        ["L6CTP_INSTALL",2],
        ["NFC_CPT",1],
        ["Reserved  ",8],
        ["VERS_HW_TRX",2],
        ["VERS_FW_TRX",2],
        ["DATEHOUR_LAST_UPDATE",4],
        ["RF_UPSTREAM_CHANNEL",1],
        ["RF_DOWNSTREAM_CHANNEL",1],
        ["RF_UPSTREAM_MOD",1],
        ["RF_DOWNSTREAM_MOD",1],
        ["TX_POWER",1],
        ["TX_DELAY_FULLPOWER",2],
        ["TX_FREQ_OFFSET",2],
        ["EXCH_RX_DELAY",1],
        ["EXCH_RX_LENGTH",1],
        ["EXCH_RESPONSE_DELAY",1],
        ["EXCH_RESPONSE_DELAY_MIN",1],
        ["L7TRANSMIT_LENGTH_MAX",1],
        ["L7RECEIVE_LENGTH_MAX",1],
        ["CLOCK_OFFSET_CORRECTION",2],
        ["CLOCK_DRIFT_CORRECTION",2],
        ["CIPH_CURRENT_KEY",1],
        ["CIPH_KEY_COUNT",1],
        ["PING_RX_DELAY",1],
        ["PING_RX_LENGTH",1],
        ["PING_RX_DELAY_MIN",1],
        ["PING_RX_LENGTH_MAX",1],
        ["PING_LAST_EPOCH",4],
        ["PING_NBFOUND",1],
        ["PING_REPLY1",9],
        ["PING_REPLY2",9],
        ["PING_REPLY3",9],
        ["PING_REPLY4",9],
        ["PING_REPLY5",9],
        ["PING_REPLY6",9],
        ["PING_REPLY7",9],
        ["PING_REPLY8",9],
        ["Reserved2",12],
	] },
	handles => {
		all_tags_reftech    => 'elements',
		add_tag_reftech     => 'push',
		filter_tags_reftech => 'grep',
		find_tags_reftech    => 'first',
		get_tags_reftech     => 'get',
		count_tags_reftech  => 'count',
		sort_tags_reftech  => 'sort',
	},
);

has 'reftech' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {} },
  handles   => {
	  set_reftech     => 'set',
	  get_reftech     => 'get',
	  all_reftech   => 'kv',
	  
  },
);
has 'autrezone' => (
	is => 'rw'
);


=head2 check_zone_technique

Parse la zone de référentiel technique

Parametre:

	data: chaine hexa contenant la zone de conso

Retourne:

	0

=cut	
sub check_zone_technique {
	my ($self,$datas) = @_;
	my (@parsed) = unpack("H4 H4 H2 H8 H12 H4 H12 H2 H4 H2 H6
							H2 H10 H8 H2 H26 H4 H2 H2 H2 H2
							H12 H12 H8 H8 H6 H4 H4 H4 
							H4 H4 H2 H16 
							H4 H4 H8 
							H2 H2 H2 H2 H2 
							H4 H4 
							H2 H2 H2 H2 H2 H2
							H4 H4 
							H2 H2 H2 H2 H2 H2 
							H8 H2 
							H18 H18 H18 H18 H18 H18 H18 H18 
							H24",
			pack("H*",$datas)); 
	for (my $i =0 ; $i < $self->count_tags_reftech ;$i++) {
		$self->set_reftech( $self->get_tags_reftech($i)->[0] => $parsed[$i]);
	}
	if ($self->get_reftech('AMR_CONFIG')) {
		my $value = hex($self->get_reftech('AMR_CONFIG'));
			$self->set_reftech( 'CURRENT_STATE' => sprintf("%02X",(($value & 0x01C000) >> 14)) );
			$self->set_reftech( 'SENSOR_STATUS_SURVEILLANCE' => sprintf("%02X",(($value & 0x003000) >> 12)) );
			$self->set_reftech( 'CFGFRAME_SEND' => sprintf("%02X",(($value & 0x000800) >> 11)) );
			$self->set_reftech( 'CFGFRAME_PERIOD' => sprintf("%02X",(($value & 0x000600) >> 9)) );
			$self->set_reftech( 'NB_FENETRE_INTRA' => sprintf("%02X",(($value & 0x000180) >> 7)) );
			$self->set_reftech( 'NB_FENETRE_SUP' => sprintf("%02X",(($value & 0x000040) >> 6)) );
			$self->set_reftech( 'NB_FENETRE_CFG' => sprintf("%02X",(($value & 0x000020) >> 5)) );
			$self->set_reftech( 'NB_FENETRE_HOR' => sprintf("%02X",(($value & 0x000010) >> 4)) );
			$self->set_reftech( 'NB_FENETRE_JOUR' => sprintf("%02X",(($value & 0x00000C) >> 2)) );
			$self->set_reftech( 'PAS_MESURE' => sprintf("%02X",(($value & 0x000003) >> 0)) );
	}
	if ($self->get_reftech('ACTIVATION_BITS')) {
		my $value = hex($self->get_reftech('ACTIVATION_BITS'));
		$self->set_reftech( 'INTRADAY' => sprintf("%02X",(($value & 0x80) >> 7))  );
		$self->set_reftech( 'DAYLIGHT_SAV' => sprintf("%02X",(($value & 0x40) >> 6)) );
		$self->set_reftech( 'TRACE_MODE' => sprintf("%02X",(($value & 0x20) >> 5)) );
		$self->set_reftech( 'BACKUP_TECHNICAL' => sprintf("%02X",(($value & 0x10) >> 4)) );
		$self->set_reftech( 'BACKUP_LOG' => sprintf("%02X",(($value & 0x08) >> 3)) );
		$self->set_reftech( 'BACKUP_METERING' => sprintf("%02X",(($value & 0x04) >> 2)) );
		$self->set_reftech( 'SORTIE_CLIENT' => sprintf("%02X",(($value & 0x02) >> 1)) );
		$self->set_reftech( 'INTERFACE_RADIO' => sprintf("%02X",(($value & 0x01) >> 0)) );
	}	
	return 0;
}

=head2 Zone des températures

Gestion des éléments de la zone de températures.

Après avoir parsé la zone de températures, utiliser la méthode suivante: $local->check_zone_temperatures($datas);

où $datas contient les infos sous forme de chaÎne hexa

	my $nfc = Telereleve::COM::NFC->new(config => 'nfc.cfg');

	my $zone = 'temperatures';

	my @res = $nfc->read_zone($zone);
	my $datas = join '', @res;
	
	$local->check_zone_temperatures($datas);
	for my $data ( $local->all_temperatures) {
		say "$data->[0] => $data->[1]";
	}
	say "";
	say "details: ";
	say $local->get_temperatures('EPOCH');
	say $local->get_temperatures('CPT15min_0');
	say $local->get_temperatures('CPT15min_plus15');
	say $local->get_temperatures('CPT15min_plus20');
	say $local->get_temperatures('CPT15min_plus25');	


Liste des différentes valeurs disponibles, la valeur est retournée sous forme de chaîne héxa.	

        ["EPOCH","Timestamp de la dernière sauvegarde"],
        ["CPT15min_moins40","En dessous de -37.5°C"],
        ["CPT15min_moins35","Entre -37.5°C et -32.5°C"],
        ["CPT15min_moins30","Entre -32.5°C et -27.5°C"],
        ["CPT15min_moins25","Entre -27.5°C et -22.5°C"],
        ["CPT15min_moins20","Entre -22.5°C et -17.5°C"],
        ["CPT15min_moins15","Entre -17.5°C et -12.5°C"],
        ["CPT15min_moins10","Entre -12.5°C et -7.5°C"],
        ["CPT15min_moins5","Entre -7.5°C et -2.5°C"],
        ["CPT15min_0","Entre -2.5°C et 2.5°C"],
        ["CPT15min_plus5","Entre 2.5°C et 7.5°C"],
        ["CPT15min_plus10","Entre 7.5°C et 12.5°C"],
        ["CPT15min_plus15","Entre 12.5°C et 17.5°C"],
        ["CPT15min_plus20","Entre 17.5°C et 22.5°C"],
        ["CPT15min_plus25","Entre 22.5°C et 27.5°C"],
        ["CPT15min_plus30","Entre 27.5°C et 32.5°C"],
        ["CPT15min_plus35","Entre 32.5°C et 37.5°C"],
        ["CPT15min_plus40","Entre 37.5°C et 42.5°C"],
        ["CPT15min_plus45","Entre 42.5°C et 47.5°C"],
        ["CPT15min_plus50","Entre 47.5°C et 52.5°C"],
        ["CPT15min_plus55","Entre 52.5°C et 57.5°C"],
        ["CPT15min_plus60","Entre 57.5°C et 62.5°C"],
        ["CPT15min_plus65","Entre 62.5°C et 67.5°C"],
        ["CPT15min_plus70","Entre 67.5°C et 72.5°C"],
        ["CPT15min_plus75","Entre 72.5°C et 77.5°C"],
        ["CPT15min_plus80","Au-dessus de 77.5°C"],

=cut

has 'tags_temperatures' => (
	traits  => ['Array'],
	is      => 'ro',
	isa     => 'ArrayRef',
	default => sub { [
        ["EPOCH","Timestamp de la dernière sauvegarde"],
        ["CPT15min_moins40","En dessous de -37.5°C"],
        ["CPT15min_moins35","Entre -37.5°C et -32.5°C"],
        ["CPT15min_moins30","Entre -32.5°C et -27.5°C"],
        ["CPT15min_moins25","Entre -27.5°C et -22.5°C"],
        ["CPT15min_moins20","Entre -22.5°C et -17.5°C"],
        ["CPT15min_moins15","Entre -17.5°C et -12.5°C"],
        ["CPT15min_moins10","Entre -12.5°C et -7.5°C"],
        ["CPT15min_moins5","Entre -7.5°C et -2.5°C"],
        ["CPT15min_0","Entre -2.5°C et 2.5°C"],
        ["CPT15min_plus5","Entre 2.5°C et 7.5°C"],
        ["CPT15min_plus10","Entre 7.5°C et 12.5°C"],
        ["CPT15min_plus15","Entre 12.5°C et 17.5°C"],
        ["CPT15min_plus20","Entre 17.5°C et 22.5°C"],
        ["CPT15min_plus25","Entre 22.5°C et 27.5°C"],
        ["CPT15min_plus30","Entre 27.5°C et 32.5°C"],
        ["CPT15min_plus35","Entre 32.5°C et 37.5°C"],
        ["CPT15min_plus40","Entre 37.5°C et 42.5°C"],
        ["CPT15min_plus45","Entre 42.5°C et 47.5°C"],
        ["CPT15min_plus50","Entre 47.5°C et 52.5°C"],
        ["CPT15min_plus55","Entre 52.5°C et 57.5°C"],
        ["CPT15min_plus60","Entre 57.5°C et 62.5°C"],
        ["CPT15min_plus65","Entre 62.5°C et 67.5°C"],
        ["CPT15min_plus70","Entre 67.5°C et 72.5°C"],
        ["CPT15min_plus75","Entre 72.5°C et 77.5°C"],
        ["CPT15min_plus80","Au-dessus de 77.5°C"],
	] },
	handles => {
		all_tags_temperatures    => 'elements',
		add_tag_temperatures     => 'push',
		filter_tags_temperatures => 'grep',
		find_tags_temperatures    => 'first',
		get_tags_temperatures     => 'get',
		count_tags_temperatures  => 'count',
	},
);

has 'temperatures' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {} },
  handles   => {
	  set_temperatures     => 'set',
	  get_temperatures     => 'get',
	  all_temperatures   => 'kv',
  },
);

=head2 check_zone_temperatures

Parse la zone de températures

=cut	
sub check_zone_temperatures {
	my ($self,$datas) = @_;
	my (@parsed) = unpack("H8 " . "H6" x  25 , pack("H*",$datas)); 
	for (my $i =0 ; $i < $self->count_tags_temperatures ;$i++) {
		$self->set_temperatures( $self->get_tags_temperatures($i)->[0] => $parsed[$i]);
	}
	return 0;
}

=head2 Zone d'événements

Gestion des éléments de la zone d'événements.

Après avoir parsé la zone d'événements, utiliser la méthode suivante: $local->check_zone_events($datas);
	
où $datas contient les infos sous forme de chaÎne hexa.

	my $nfc = Telereleve::COM::NFC->new(config => 'nfc.cfg');

	my $zone = 'events';

	my @res = $nfc->read_zone($zone);
	my $datas = join '', @res;
	
	$local->check_zone_events($datas);
	for my $data ( $local->all_events) {
		say "$data->[0] => $data->[1]";
	}
	say "";
	say "details: ";
	say $local->get_events('event_0');
	say $local->get_events('event_1');
	say $local->get_events('event_2');
	say $local->get_events('event_3');
	say $local->get_events('event_4');

Parametre:

	data: chaine hexa contenant la zone de conso

Retourne:

	0
	
=cut
has 'events' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {} },
  handles   => {
	  set_events     => 'set',
	  get_events     => 'get',
	  all_events   => 'kv',
  },
);

=head2 check_zone_events

Parse la zone d'évènements

=cut	
sub check_zone_events {
	my ($self,$datas) = @_;
	my (@parsed) = unpack("H14" x  30 , pack("H*",$datas)); 
	for (my $i =0 ; $i < @parsed ;$i++) {
		$self->set_events( "event_$i" => $parsed[$i]);
	}
	return 0;
}

=head2 Zone d'échange

Gestion de la zone d'échange en lecture seule.

=cut

has 'echange' => (
  traits    => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {} },
  handles   => {
	  set_echange     => 'set',
	  get_echange     => 'get',
	  all_echanges   => 'kv',
  },
);


=head2 check_zone_echange

Analyse de la zone d'échange.

Les éléments de réponse sont disponibles via 

	set_echange
	
	$objet->get_echange( "nb_commandes" );
	$objet->get_echange( "nb_reponses" );
	$objet->get_echange( "adresse_reponse" );

Et ensuite

	$objet->get_echange( "commande_01" );
	$objet->get_echange( "commande_02" );
	$objet->get_echange( "commande_..." );
	
	$objet->get_echange( "reponse_01" );
	$objet->get_echange( "reponse_02" );
	$objet->get_echange( "reponse_..." );

Paramètre:

	data: chaine hexa contenant la zone de conso

Retourne:

	0
	
=cut
sub check_zone_echange {
	my ($self,$datas) = @_;
	my ($reponse,$suite,$suite2);
	my ($commande,$longueur_reponse,$reste);
	my (@parsed) = unpack("H2 H2 H4 H*", pack("H*",$datas)); 
	$self->set_echange( "nb_commandes" => $parsed[0]);
	$self->set_echange( "nb_reponses" => $parsed[1]);
	$self->set_echange( "adresse_reponse" => $parsed[2]);
	$reste = $parsed[3];
	#itron remet à 0 l'octet du nombre de commandes
	if (hex($self->get_echange("nb_commandes")) == 0 && hex($self->get_echange("nb_reponses")) > 0 ) {
		$self->set_echange( "nb_commandes" => $parsed[1]);
	}
	#lecture des commandes
	for (my $i = 0; $i < hex($self->get_echange("nb_commandes")) ; $i++) {
			my $longueur = substr($reste,0,2);
			($commande,$reste) = unpack("H" . (hex($longueur)*2+4+2) . "H*", pack("H*", $reste) );
			$self->set_echange( "commande_".sprintf("%02i",$i+1) => $commande);
	}
	#lecture des responses
	$reste = substr($parsed[3], (hex($parsed[2])*2) - 8);
	for (my $i = 0; $i < hex($self->get_echange("nb_reponses")) ; $i++) {
			my $longueur = substr($reste,0,2);
			($commande,$reste) = unpack("H" . (hex($longueur)*2+4+2) . "H*", pack("H*", $reste) );
			$self->set_echange( "reponse_".sprintf("%02i",$i+1) => $commande);
	}
	return 0;
}

sub check_autre_zone {
	my ($self,$datas) = @_;
	my (@parsed) = unpack("H*",pack("H*",$datas));
	$self->autrezone( join('',@parsed) );
	return 0;
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

1; # End of Telereleve::Helper::CheckZone


