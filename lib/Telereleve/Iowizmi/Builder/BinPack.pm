package Telereleve::Iowizmi::Builder::BinPack;

use Moose;

extends 'Telereleve::Iowizmi::Builder';

use XML::LibXML;
use XML::Compile::Schema;

use MIME::Base64;
use Digest::SHA;

use Date::Parse;
use DateTime;
use DateTime::Format::Natural;
use File::Basename;

use Data::Dumper qw(Dumper);
use Data::Peek;

our $VERSION = '0.0';

has '+module' => (
    is => 'rw',
    default => 'BinPack',
);

has 'xsd_element' => (
    is => 'rw',
    #default => 'donneesLogiciellesEmetteur',
    default => 'blocsLogicielEmetteur',
);

override 'build' => \&_build;

sub _build {
    my ($self, $Tool, $ManufName, $Type, $RefTechVer, $Klog, $BinFileName, $SwVersion, @CompatVer ) = @_;
    
    $self->logger->info($self->module);

    # Get unique HwVersion from CompatVer
    my %unique = ();
    for ( my $i=0; $i< scalar @CompatVer; $i++)
    {
        $unique{$CompatVer[$i][1]} ++;
    }
    my @HwVersion = keys %unique;
    
    # Show inputs
    $self->logger->debug("\t ManufName    : $ManufName");
    $self->logger->debug("\t Type         : ".hex($Type));
    $self->logger->debug("\t RefTechVer   : ".hex($RefTechVer));
    $self->logger->debug("\t Klog         : $Klog");
    $self->logger->debug("\t BinFileName  : $BinFileName" );
    $self->logger->debug("\t SwVersion    : ".sprintf( "%.02f\n", $SwVersion ) );
    $self->logger->debug("\t HwVersion(s) : ".scalar @HwVersion);
    for ( my $i=0; $i< scalar @HwVersion; $i++)
    {
        $self->logger->debug("\t   ".sprintf( "%.02f\n", $HwVersion[$i]) );
    }
    
    #***************************************************************************
    $self->logger->debug("Get info from bin file");
    my $ManufacturerID;
    my $HashSw = 0;
    my $hash_sw = 0;
    my $BinSize;
    my $nbBlock;
    my $temp = 0;
    
    # Get ManufacturerID from ManufName
    foreach my $c (unpack("C*", $ManufName )) 
    {
        $temp = ($temp << 5) + ($c -64);
    }
    $ManufacturerID = sprintf("%hx", $temp);

    # Get Hash from file
    my $sha = Digest::SHA->new(256);   
    $sha->addfile($BinFileName);
    
    # Get file size then deduce the number of block
    $BinSize = (stat $BinFileName)[7];
    $nbBlock = int($BinSize/210);
    my $rest = $BinSize % 210;
    my $nPadding = 0;
    if ( $rest != 0 )
    {
        $nPadding = 210 - $rest;
        $nbBlock += 1;
        
        my $pad_str = "";
        for (my $j=0; $j < $nPadding; $j++)
        {
            $pad_str = $pad_str . pack ("H2", "FF");
        }
        $sha->add($pad_str);
    } 
    
    
    # this doesn't work
    # $HashSw = $sha->hexdigest;

    # Without padding : 04f34bfe8c87ec79f9db3b494ae3afcde2d185983476c2a8efa54b593751d972  IowizmiTest/OpenWize-Up/bootstrap.bin
    # With padding : bf8c9d20c214477eff449be108067bf8ae6e7bc6f7754419d8c1654c5bc66f6b  ./IowizmiTest/OpenWize-Up/bootstrap_tmp.bin
    # this one work
    $hash_sw = $sha->hexdigest;
    
    $self->logger->trace("\t Manuf ID : $ManufacturerID");
    $self->logger->trace("\t BinSize  : $BinSize");
    $self->logger->trace("\t Block    : $nbBlock");
    $self->logger->trace("\t Padding  : $nPadding");
    #$self->logger->trace("\t HashSw   : $HashSw");
    $self->logger->trace("\t HashSw   : $hash_sw");
   
    #***************************************************************************
    if ( $Tool eq 'BINARY')
    {
        $self->xml_file("BINAIRES");
        $self->xsd_element('blocsLogicielEmetteur');
    }
    elsif ( $Tool eq 'DESCRIPTION')
    {
        $self->xml_file("DESCRIPTION");
        $self->xsd_element('donneesLogiciellesEmetteur');
    }
    else 
    {
        $self->logger->error("Unknown \"$Tool\" tool");
        return;
    }
    
    $self->logger->debug("Build ".$self->xml_file.".xml");
    $self->logger->debug("\txsd : ".$self->xsd_file);
   

    my $data = $self->schema->template(
        'PERL' => $self->xsd_element, 
        show_comments => '', 
        skip_header => 'true', 
        output_style => 1
        );

    #print Dumper $data;
    $data =~ s/#.*//g;
    $data =~ s/\s*//g;
    $data = eval($data);
    
    #***************************************************************************
    # Build BINARY.xml
    if ( $Tool eq 'BINARY')
    {
        my ($maj, $min);
        $data->{ManufacturerID} = pack("H*", $ManufacturerID);
        
        $HashSw = substr($hash_sw, 0, 8);
        $data->{HashSw} = pack("H*", $HashSw);

        for ( my $i=0; $i< scalar @HwVersion; $i++)
        {
            ($maj, $min) = (split /\./, sprintf( "%.02f", $HwVersion[$i]) )[0,1];
            $data->{HwVersion}[$i] = pack("H*", 
                sprintf( "%02X%.02X", 
                    sprintf( "%02s", $maj ), 
                        sprintf( "%.2s", $min ) 
                        )
                    );
        }
        
        ($maj, $min) = (split /\./, sprintf( "%.02f", $SwVersion ) )[0,1];
        $data->{SwVersionTarget} = pack("H*", 
                sprintf( "%02X%.02X", 
                    sprintf( "%02s", $maj ), 
                        sprintf( "%.2s", $min ) 
                        )
                    );
        
        $data->{nbBlocs} = $nbBlock;
        
        my $i=0;
        my $L7Frm;
        open(FILE, $BinFileName) or die("Error reading file, stopped");
        while( my $nbRead = read(FILE, $L7Frm, 210) ) 
        {
            if ($i >= $nbBlock) 
            {
                $self->logger->error("Mismatch number of block");
            }
            
            if ( $nbRead < 210) 
            {
                my $padding = 210 - $nbRead;
                $self->logger->debug("Add $padding padding bytes on block ". ($i+1) );
                for (my $j=0; $j < $padding; $j++)
                {
                    $L7Frm = $L7Frm . pack ("H2", "FF");
                }
            }
            $data->{blocLogiciel}[$i]->{id} = $i+1;
            $data->{blocLogiciel}[$i]->{trameL7} = $L7Frm;
            $data->{blocLogiciel}[$i]->{BlockSize} = 210;
            $i++;
        }
        close(FILE);
    }
    
    #***************************************************************************
    # Build DESCRIPTION.xml
    if ( $Tool eq 'DESCRIPTION')
    {

=pod
        print ".............\n";
        my $tt;
        
        $tt = pack("H*", $SwVersion);
        print DHexDump($tt)."\n";
        print encode_base64($tt);
=cut

        my $tt = sprintf( "%.02f\n", $SwVersion );

        $data->{versionLogiciel} = sprintf( "%.02f", $SwVersion );

        $data->{versionRefTechnique} = $RefTechVer;
        $data->{nbBlocs} = $nbBlock;
        
        $HashSw = substr($hash_sw, 0, 8);
        $data->{motifIntegriteLogiciel} = pack("H*", $HashSw);

        $data->{type} = $Type;
        $data->{fabricant}->{nomFabricant} = $ManufName;

        $data->{fabricant}->{motifIntegriteFabricant} = pack("H*", $Klog);
        
        for ( my $i=0; $i< scalar @CompatVer; $i++)
        {
            $data->{versionCompatibilite}[$i]->{modele} = 
                sprintf( "%.02d", $CompatVer[$i][0] );
            $data->{versionCompatibilite}[$i]->{versionHardware} = 
                sprintf( "%.02f", $CompatVer[$i][1] );
            $data->{versionCompatibilite}[$i]->{versionAnterieureOK} = 
                sprintf( "%.02f", $CompatVer[$i][2] );
        }
    }
    #***************************************************************************
    # build ouput
    $self->_out_xml_file($data);
    return 0;
}

#***************************************************************************

no Moose;
__PACKAGE__->meta->make_immutable;

1; # End of Telereleve::Iowizmi::BinPack
 
