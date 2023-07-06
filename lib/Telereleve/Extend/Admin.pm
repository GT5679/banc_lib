package Telereleve::Extend::Admin;

use Moose;
use utf8;

use Config::Tiny;
use Log::Log4perl qw(:easy);
use Log::Log4perl::Appender::File;

use Time::HiRes qw(usleep alarm gettimeofday);
use XML::LibXML;

use Date::Parse;
use MIME::Base64;
use File::Basename;
use File::Path;

use Data::Dumper;
use Data::Peek;

our $VERSION = '0.0';

#******************************************************************************

has 'module' => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_module_name',
    default => 'admin',
);

has 'logger' => (
    is => 'rw'
);

has 'logger_config_file' => (
    is => 'rw',
    required => 1,
    predicate => 'has_logger_config_file',
    clearer  => 'clear_logger_config_file',
    trigger  => \&_load_logger_config_file,
);

#******************************************************************************

my %trm_type = (
    'NONE'            => 0,
    'READPARAMETERS'  => 1,
    'WRITEPARAMETERS' => 2,
    'EXECPING'        => 3,
    'ANNDOWN'         => 4,
    'KEYCHG'          => 5
);

my @param_ANNDOWN = (
    'L7CommandId', 'L7DwnldId', 'L7Klog', 'L7SwVersionIni', 'L7SwVersionTarget', 'L7MField', 
    'L7DcHwId', 'L7BlocksCount', 'L7ChannelId', 'L7ModulationId', 'L7DaysProg',
    'L7DaysRepeat', 'L7DeltaSec', 'HashSW'
    );
my @template_ANNDOWN = ("H2", "H6", "H32", "H4", "H4", "H4", "H4", "n", "c", "c", "L>", "c", "c", "H8");

my @param_KEYCHG = ('L7CommandId', 'L7KeyId', 'L7KeyVal', 'L7KIndex');
#my @template_KEYCHG = ("H2", "H2", "H64", "H2"); 
my @template_KEYCHG = ("2", "2", "64", "2");


#******************************************************************************
=head2 GenADM
Parameter: $app   : instance of Telereleve::Application::Command;
This generate ADMIN frames from "admin.cfg" file if any. The "id_fabricant" and
"id_ddc" fileds must be set in $app before.

Return 
    A tuple ($datas, $complements) if success;
    A tuple (undef, undef) otherwise;
=cut
sub GenADM
{
    my ($self, $app) = @_;
    
    my $target;
    my $device;
    my $config;
    
    #-----------------------------------------------------------------------
    if (defined $app)
    {
        $device = $app->id_fabricant().$app->id_ddc();
        $config = $self->GetCfgFromFile($device, "admin.cfg");
        if ( not defined $config)
        {
            return (undef, undef);
        }
    }
    else
    {
        $self->logger->debug("\"\$app\" is undefined");
        return (undef, undef);
    }

    #-----------------------------------------------------------------------
    # Get data required to build the frame
    my $infoIn;
    $infoIn->{app} = $app;
    $infoIn->{config} = $config;
    $infoIn->{action} = ''; #$action;
    #$infoIn->{desc} = $pack_desc_file;
    
    if ($config->{DDC}->{desc_file})
    {
        my $pack_desc_file;
        $target = uc "./".$device;
        $pack_desc_file = $config->{DDC}->{desc_file};
        $infoIn->{desc} = "./".$target."/".$pack_desc_file;
    }
    
    #-----------------------------------------------------------------------
    # Generate CMD
    my ($datas, $complements) = $self->GenCMD($infoIn);
    
    #-----------------------------------------------------------------------
    if ( defined $datas && defined $complements)
    {
        # check if CMD was correctly build and if was an ANN_DOWNLOAD
        if ( $datas->{action} && ( $datas->{action} eq 'COMMAND_ANNDOWNLOAD') ) 
        {
            # Check if bin file is declared
            if ( $config->{DDC}->{bin_file} )
            {
                $complements->{binFile} = "./".$device."/".$config->{DDC}->{bin_file};
            }
            else 
            {
                $self->logger->warn("ANNDOWN request without \"bin_file\"");
            }
        }
    }
    return ($datas, $complements);
}

#******************************************************************************
=head2 GetCfgFromFile
Parameter: 
    - $target_device : device id
    - $target_file   : file to search in
This return the cfg read from "target_file" in "target_device" directory, if any.

Return 
    The $cfg if success, undef otherwise;
=cut
sub GetCfgFromFile
{
    my ($self, $target_device, $target_file) = @_;
    my $cfg;
    
    if (defined $target_device and defined $target_file)
    {
        my $target = uc "./".$target_device;

        $self->logger->trace ("Searching in " .$target_file." for available commands");
        $target = $target."/".$target_file;
        
        if (-e $target and -f $target) 
        {
            $self->logger->trace("$target file found!");
            eval { 
                $cfg = Config::Tiny->read($target); 
            };
            if ($@) {
                confess(qq|[Error in $target file]\n $@|);
                return undef;
            }
        }
        else
        {
            $self->logger->debug("Device $target_device is unknown");
            $self->logger->trace("None");
            return undef;
        }
        return $cfg;
    }
    return undef;
}

#******************************************************************************

=head2 GetPackageDesc
Parameter: file name of the FW package description.xml 
    
This extract informations from the xml input file

Return the pack_desc hash.
Content is 
    If success \$pack_desc->{status} = 1;
    otherwise  \$pack_desc->{status} = 0;    
=cut
sub GetPackageDesc
{    
    my ($self, $pack_desc_file)=@_;
    
    my $pack_desc;
    $pack_desc->{status} = 0;
    if ( !($pack_desc_file eq "") ) 
    {
        my $temp;
        
        if (-e $pack_desc_file and -f $pack_desc_file) 
        {
            $self->logger->debug("$pack_desc_file file found!");
            
            my $dom = XML::LibXML->load_xml(location => $pack_desc_file);

            $pack_desc->{fabName} = $dom->findvalue('//fabricant/nomFabricant');
            
            $temp = 0;
            foreach my $c (unpack("C*", $pack_desc->{fabName} )) 
            {
                $temp = ($temp << 5) + ($c -64);
            }    
            $pack_desc->{fabId} = sprintf("%hx", $temp);
            $pack_desc->{L7Klog} = $dom->findvalue('//fabricant/motifIntegriteFabricant');
            $pack_desc->{L7SwVersionTarget} = $dom->findvalue('//versionLogiciel');
            $pack_desc->{L7BlocksCount} = $dom->findvalue('//nbBlocs');
            
            $temp = decode_base64($dom->findvalue('//motifIntegriteLogiciel') );
            $pack_desc->{HashSW} = sprintf("%x", unpack("N", $temp ) );
            $pack_desc->{status} = 1;
        } 
        else 
        {
             $self->logger->warn("File " . $pack_desc_file . " not found");
        }
    }
    return $pack_desc;
}

=head2 GenCMD
Parameter: $infoIn hash  
    - $infoIn->{app}    : instance of Telereleve::Application::Command;
    - $infoIn->{config} : config containing input COMMAND to treat
    - $infoIn->{action} : (optional) action (frame type) to work on;
    - $infoIn->{desc}   : (optional ANNDOWNLOAD only) file name of the given description.xml 
This generate information to build L7 and L2 ADMIN frames

Return the tuple ($datas, $complements);
    
=cut
sub GenCMD
{
    my ($self, $infoIn) = @_;
    
    my $app    = $infoIn->{app};
    my $config = $infoIn->{config};
    my $action = $infoIn->{action};
    
    my $complements;
    my $datas;
    my $show = "";   
    
    $complements->{init} = 1; 
    if ($action eq '' or $action eq 'NONE') 
    {
        if ( $config->{main}->{action}) 
        {
            $action = $config->{main}->{action};
        }
        else 
        {
            return (undef, undef);
        }
    }
    $self->logger->trace("Action : ". $action );
    
    if ( $action eq 'READPARAMETERS')
    {
        # READPARAMETERS
        $datas->{action} = 'COMMAND_READPARAMETERS';
        $datas->{parameters} = '';
        my @pList = ( split /,/, $config->{DDC}->{READ_LIST} );
        foreach my $p (@pList)
        {
            my $param = sprintf( "%.02x", hex($p)  );
            $self->logger->trace("Add parameter : ". $param );
            $datas->{parameters} .= $param;
            # $self->logger->trace($param);
        }
        if ( length $datas->{parameters} == 0 )
        {
             $self->logger->error("No parameters Ids for $datas->{action}");
            return (undef, undef);
        }
    }
    elsif ( $action eq 'WRITEPARAMETERS' )
    {
        # WRITEPARAMETERS
        $datas->{action} = 'COMMAND_WRITEPARAMETERS';
        $datas->{parameters} = '';
        #my @pList = ( split /\{.*\},/, $config->{DDC}->{WRITE_LIST} );
        my @pList = ( split /\s*;\s*/, $config->{DDC}->{WRITE_LIST} );
        
        foreach my $p (@pList)
        {
            my @param = ( split /\s*,\s*/, $p);
            $self->logger->trace($p);
            my $id = sprintf( "%.02x", hex($param[0])  );
            my $sz = sprintf( "%.02x", hex($param[1])  );
            my $v  = sprintf( "%.02x", hex($param[2])  );
             $self->logger->debug("Found parameter => Id : ".$id . " Size  : ".$sz . " Value : ".$v);

            #my $param = sprintf( "%.02x", hex($p)  );
            my $temp = pack("H2 H".$sz*2, $id, $v);
             $self->logger->trace("Add parameter : ". unpack ("H*", $temp) );
            
            $datas->{parameters} .= unpack ("H*", $temp);
        }
        if ( length $datas->{parameters} == 0 )
        {
             $self->logger->error("No parameters Ids for $datas->{action}");
            return (undef, undef);
        }
    }
    elsif ( $action eq 'EXECPING' )
    {
        # EXECPING
        $datas->{action} = 'COMMAND_EXECINSTPING';
        $datas->{parameters} = '';
    }
    elsif ( $action eq 'ANNDOWN' )
    {
        # ANNDOWN
        $datas->{action} = 'COMMAND_ANNDOWNLOAD';
        $datas->{parameters} = '';
        
        my @param = @param_ANNDOWN;
        my @template = @template_ANNDOWN;
        
        my $pack_desc;
        $pack_desc->{status} = 0;
        if ( !($infoIn->{desc} eq "") )
        {
            $pack_desc = $self->GetPackageDesc($infoIn->{desc});
            if ($pack_desc->{status} == 1)
            {
                 $self->logger->trace("From  : " . $infoIn->{desc} );
                 $self->logger->trace("\tfabName           : " . $pack_desc->{fabName});
                 $self->logger->trace("\tfabId             : " . $pack_desc->{fabId});
                 $self->logger->trace("\tL7Klog            : " . $pack_desc->{L7Klog});
                 $self->logger->trace("\tL7SwVersionTarget : " . $pack_desc->{L7SwVersionTarget});
                 $self->logger->trace("\tL7BlocksCount     : " . $pack_desc->{L7BlocksCount});
                 $self->logger->trace("\tHashSW            : " . $pack_desc->{HashSW});
            }
        }
        
        $config->{DDC}->{L7MField} = $app->{id_fabricant};
        # If decsription xml is given
        if ( $pack_desc->{status} == 1) 
        {
            if ( !(lc $config->{DDC}->{L7MField} eq lc $pack_desc->{fabId} ) )  
            {
                 $self->logger->fatal(
                    "Fab id doesn't match : "
                    . $config->{DDC}->{L7MField}
                    . "!=" . $pack_desc->{fabId} );
                return (undef, undef);
            }
            else 
            {
                # Replace with decsription xml one
                $config->{DDC}->{L7Klog} = $pack_desc->{L7Klog};
                $config->{DDC}->{L7SwVersionTarget} = $pack_desc->{L7SwVersionTarget};
                $config->{DDC}->{L7BlocksCount} = $pack_desc->{L7BlocksCount};
                $config->{DDC}->{HashSW} = $pack_desc->{HashSW};
            }
        }

        # Get DaysProg
        if ($config->{DDC}->{DaysProg})
        {
            # Get it
            # $complements->{DaysProg} = $config->{DDC}->{DaysProg};
        }
        else 
        {
            $self->logger->debug("DaysProg not found");
            # else, start after a delay
            my $downDelay = 1;
            if ($app->{simu}->{DownDelay})
            {   
                # after DownDelay greater than 1s from main.cfg if it exist
                if ( $app->config()->{simu}->{DownDelay} > 1)
                {
                    $downDelay = $app->config()->{simu}->{DownDelay};
                }
            }
            else 
            {
                # after 15 second 
                $downDelay = 15;
            }
            
            my ($_sec, $_usec) = gettimeofday;
            
            my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($_sec + $downDelay);
            
            $config->{DDC}->{DaysProg} = sprintf("%d-%02d-%02d %02d:%02d:%02d", 1900+$year, $mon+1, $mday, $hour, $min, $sec);
            $self->logger->debug("Set DaysProg to $config->{DDC}->{DaysProg} (now + $downDelay second)");
        }
        $complements->{DaysProg} = $config->{DDC}->{DaysProg};
        
        # Copy mainconfig to complements
        for ( my $i=1; $i< scalar @param; $i++)
        {
            $complements->{$param[$i]} = $config->{DDC}->{$param[$i]};
        }
        
        # Convert in epoch since 2013
        $complements->{L7DaysProg} = str2time($complements->{DaysProg}) - str2time("2013-01-01 00:00:00");
        $config->{DDC}->{L7DaysProg} = localtime($complements->{L7DaysProg});
        
        
        # Convert sw init, target and hw version
        my ($maj, $min);

        $complements->{L7SwVersionIni} .= '0'; 
        ($maj, $min) = (split /\./, $complements->{L7SwVersionIni})[0,1];
        $complements->{L7SwVersionIni} = sprintf( "%02X%.02X", sprintf( "%02s", $maj ), sprintf( "%.2s", $min ) );
        #$complements->{L7SwVersionIni} = sprintf( "%02X%02X", (split /\./, $complements->{L7SwVersionIni})[0,1]  );

        $complements->{L7SwVersionTarget} .= '0'; 
        ($maj, $min) = (split /\./, $complements->{L7SwVersionTarget})[0,1];
        $complements->{L7SwVersionTarget} = sprintf( "%02X%.02X", sprintf( "%02s", $maj ), sprintf( "%.2s", $min ) );
        #$complements->{L7SwVersionTarget} = sprintf( "%02X%02X", (split /\./, $complements->{L7SwVersionTarget})[0,1]  );

        $complements->{L7DcHwId} .= '0'; 
        ($maj, $min) = (split /\./, $complements->{L7DcHwId})[0,1];
        $complements->{L7DcHwId} = sprintf( "%02X%.02X", sprintf( "%02s", $maj ), sprintf( "%.2s", $min ) );
        #$complements->{L7DcHwId} = sprintf( "%02X%-02X", (split /\./, $complements->{L7DcHwId})[0,1]  );

        # Convert Download Id to hex
        $complements->{L7DwnldId} = sprintf( "%06X", $complements->{L7DwnldId} );
            
        
        $show = $show . "\t"."DaysProg = ". $complements->{DaysProg}."\n";
        # Setup the complements
        for ( my $i=1; $i< scalar @param; $i++)
        {
            my $str = $config->{DDC}->{$param[$i]};
            $config->{DDC}->{$param[$i]} = $complements->{$param[$i]};
            $complements->{$param[$i]} = pack( 
                    "".$template[$i]."", 
                    $config->{DDC}->{$param[$i]} 
                    );
            
            $show = $show . "\t" .$param[$i] ." = 0x". unpack ("H*", $complements->{$param[$i]}) . " (".$str .")\n";
            
            $complements->{$param[$i]} = unpack ("H*", $complements->{$param[$i]});
            # $self->logger->trace( $param[$i] ." = 0x". unpack ("H*", $complements->{$param[$i]}) . " (".$str .")\n" );    
        }
    }
    elsif ( $action eq 'KEYCHG' )
    {
        # KEYCHG
        $datas->{action} = 'COMMAND_WRITEKEY';
        $datas->{parameters} = '';
        #$complements->{L7KeyId} = '03';
        #$complements->{L7KeyVal} = 'ccccccccaaaaaaaaffffffffeeeeeeee';
    
        my @param = @param_KEYCHG;
        my @template = @template_KEYCHG;
        
        for ( my $i=1; $i< scalar @param; $i++)
        {
            if ($config->{DDC}->{$param[$i]})
            {
                if ($param[$i] eq 'L7KeyVal') 
                {
                    $complements->{$param[$i]} = unpack ("H*", pack( "H$template[$i]", $config->{DDC}->{$param[$i]}) );
                    # $self->logger->trace( $param[$i] ." = ". unpack ("H*", $complements->{$param[$i]}) ."\n" );
                     $self->logger->trace( $param[$i] ." = ". $complements->{$param[$i]} ."\n" );
                }
                else 
                {
                    $complements->{$param[$i]} = sprintf( "%.02x", hex( $config->{DDC}->{$param[$i]} ) );
                     $self->logger->trace( $param[$i] ." = ". $complements->{$param[$i]} ."\n" );
                }
            }
            else 
            {
                 $self->logger->trace( $param[$i] ." not found! \n" );
                return (undef, undef);
            }
        }
        #return (undef, undef);
    }
    else
    {
        $datas->{action} = 'UNKNOWN ACTION';
        return (undef, undef);
    }
    $self->logger->trace( "$datas->{action}\n" . $show );
    return ($datas, $complements);
}

#******************************************************************************

sub _load_logger_config_file {
    my ($self) = @_;
    
    confess("A main configuration file is required") unless $self->has_logger_config_file;
    unless (-e $self->logger_config_file) 
    {
        confess(qq|The logger configuration file is missing: |.$self->logger_config_file );
    }
    
    eval 
    { 
        Log::Log4perl->easy_init($ERROR);
        Log::Log4perl::init( $self->logger_config_file );
        
    };
    if ($@) 
    {
        confess(qq|[_load_logger_config_file]\n$@ 
        The logs configuration file is missing.|);
    }

    eval 
    {
        if ($self->has_module_name) 
        {
            $self->logger( Log::Log4perl->get_logger( lc("extend.".$self->module) ));
        } 
        else 
        {
            $self->logger( Log::Log4perl->get_logger( "module" ));
        }
    };
    if ($@) {
        confess("[_load_logger_config_file][init error] $@");
    }
}

#******************************************************************************

no Moose;
__PACKAGE__->meta->make_immutable;

1; # End of Telereleve::Extend::Admin
