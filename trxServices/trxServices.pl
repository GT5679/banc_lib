##!/usr/bin/perl

my $CurVersion = "1.5.0"; # git describe --tag
my $CurCommit = '$Id$'; # git rev-parse --short HEAD
my $CurSupport = "support\@grdf.fr";

#*******************************************************************************

package TrxServices;

my $lib_base_dir;
BEGIN
{
    # Check that the "LIB_BASE_DIR" envrironement varaible is defined and exist
    $lib_base_dir = $ENV{'LIB_BASE_DIR'}; 
    if( $lib_base_dir) 
    {
            if (-d $lib_base_dir) { }
            else 
            {
                print("*******************************************************************************\n"); 
                print("ERR : LIB_BASE_DIR is defined as \"$lib_base_dir\",\n but directory doesn't exist\n");
                print("*******************************************************************************\n");
                exit -1; 
            }
    }
    else {
        $lib_base_dir = "../";
        if (-d $lib_base_dir) { }
        else 
        { 
            print("*******************************************************************************\n");
            print("ERR : LIB_BASE_DIR is defined as \"$lib_base_dir\",\n but directory doesn't exist\n");
            print("*******************************************************************************\n");
            exit -1; 
        }
    }
    
}

# Disable print buffering
$| = 1;

use utf8;
use threads;
use Thread::Queue;

use Log::Log4perl;
use Date::Parse;
use XML::LibXML;
use MIME::Base64;
use File::Basename;
use File::Path;
use Getopt::Long qw(:config bundling);

use Pod::Usage;
use Term::ReadLine;
use Time::HiRes qw(usleep alarm gettimeofday);
use Time::Local;

use feature qw(say);
use Data::Dumper;
use Data::Peek;

use Math::Utils qw(:utility);

use lib "$lib_base_dir/lib"; 

use Telereleve::Application::Command;
use Telereleve::Application::Response;
use Telereleve::Application::Pong;
use Telereleve::Application::Ping;
use Telereleve::Application::Download;
use Telereleve::Application::Iot;

use Telereleve::COM::Trx qw(:error_code);

use Telereleve::Extend::Admin qw(GetPackageDesc genADMIN);

#our $VERSION = '0.0';

#*******************************************************************************
my $USAGE =<<USAGE;

Description:
This tool is a kind of server to test Wize TX/RX.

Usage:
$0 -t trx.cfg -m main.cfg [-v] [-x]

    where:
    --mcfg/-m       : The main configuration file.
    [--mode type]   : (Optional) Choose the mode "SERVICE" (default) or "FRAME" or "FREE".
    [--tcfg/-t]     : The SmartBrick configuration file (Required in "SERVICE and FREE mode").
    [--verbose/-v]  : (Optional) Verbose level (incremental).
    [-x]            : (Optional) Internal libraries verbose level (incremental).
    [--help/-h]     : Prints out this help.
USAGE

my $logconf = q(
    log4perl.appender.MainScreen             = Log::Log4perl::Appender::ScreenColoredLevels
    log4perl.appender.MainScreen.stderr      = 0
    log4perl.appender.MainScreen.utf8        = 1
    log4perl.appender.MainScreen.layout      = Log::Log4perl::Layout::PatternLayout::Multiline
    #log4perl.appender.MainScreen.layout.ConversionPattern = [%-5p][%M{1}][%d{HH:mm:ss}] %m %n
    log4perl.appender.MainScreen.layout.ConversionPattern = %m %n
    log4perl.appender.MainScreen.color.DEBUG = CYAN
    log4perl.appender.MainScreen.color.INFO  =
    log4perl.logger                          = WARN, MainScreen
    );

Log::Log4perl::init(\$logconf);
my $logger = Log::Log4perl::get_logger("TrxServices::TrxServices");
my $check_color_level=0;

#******************************************************************************
use constant TEMP_FILE_NAME => ".main_config.cfg";
my $main_def_cfg = q(
[INSTPING]
format=exchange
[INSTPONG]
format=exchange
[DATA]
format=exchange
[COMMAND]
format=exchange
[RESPONSE]
format=exchange
[DOWNLOAD]
format=download

[DDC]
MASTER_PWD=0000000000000000
INTEGRATOR_PWD=0000000000000000
VERS_FW_TRX=0000
VERS_HW_TRX=0000
RADIO_NUMBER=000000000000
RADIO_MANUFACTURER=FFFF
METER_NUMBER=000000000000
METER_MANUFACTURER=FFFF
##################################################

[main]
conflog=./log.cfg

);

use constant TRX_CFG_FILE_NAME => ".trx_config.cfg";
my $trx_def_cfg = q(
[main]
mode=3
timeout=8000

[smartbrick]
BIT_STUFFING=OFF
CRC_DISABLE=OFF

[serial]
user_msg=1
error_msg=1
saved_fileconf=./saveconfigfilecom.cfg

[receiving]
timeout=2000
retry=3
tempo=2000

);

# Applications "class" instance
my @gApp;
use constant {
    APP_PING     => 0,
    APP_PONG     => 1,
    APP_COMMAND  => 2,
    APP_RESPONSE => 3,
    APP_IOT      => 4,
    APP_DOWNLOAD => 5,
    GEN_ADMIN    => 6,
};

# trxService mode
use constant {
    MODE_SERVICE => 0,
    MODE_FRAME   => 1,
    MODE_FREE    => 2,
};

# Download thread
my $DwnThread; 
# Download thread ctrl queue
my $DwnThreadCtrl = Thread::Queue->new();

#******************************************************************************
#******************************************************************************
# TRX related

my $msg_min_delay = 80;

=head2 TRX_Open

This function open and configure the TRX (Smartbick) device

=cut
sub TRX_Open
{
    my ($trx) = @_;
    eval { 
        #say("Try to connect to the Smartbrick");
        $logger->debug("Try to connect to the Smartbrick");
        $trx->open(); 
    };
    if ($@)
    {
        # Erreur
        print(Dumper($@));
        #$logger->fatal("$@");
        return -1; 
    };
    
    # Smartbick configuration
    eval
    {
        #say("Configuring the Smartbrick");
        $logger->debug("Configuring the Smartbrick");
        $trx->deactive_state();
        $trx->set_config($trx->rx_channel(), $trx->tx_channel(), $trx->tx_power());
        $trx->set_legacy_modulation('OFF');
        $trx->set_raw_mode('ON');
    
        # Set trigger mode 
        # - Trigger mode
        # 00 for autonomous mode (default)
        # 01 for external trigger mode
        # 02 for reply mode
        # 03 for absolute time mode
        # - Trigger out mode
        # 00 : don't output trigger pulses
        # 01 : output pulses after each transmission
        # 02 : output pulses before each transmission
        # 03 : output pulses after each reception
        $trx->set_trigger_mode(0, 0); # 
        
        $trx->clear_fifo_rx();
        $trx->clear_fifo_tx();
        $trx->reset_free_running_clock(); # Internal clock reset
        $trx->active_state();
    };
    if ($@)
    {
        # Error
        $logger->fatal("Error during the smartbrick activation");
        $logger->fatal($@->{error} ." : ". $@->{message});
        return -1;
    }
    $logger->info("### SmartBick Module ###");
    #$logger->info("  - Name    : ". $trx->module_name());
    $logger->info("  - Prot. Ver. : ". $trx->protocol_version());
    $logger->info("  - Id code    : ". $trx->mod_model_msb() . "." . $trx->mod_model_lsb());
    $logger->info("  - Version    : ". $trx->mod_version());
    $logger->info("### SmartBick configuration ###");
    $logger->info("Downlink : (SmartBick TX)");
    $logger->info("  - Power      : ". $trx->tx_power());
    $logger->info("  - Channel    : ". $trx->tx_channel());
    $logger->info("  - Modulation : ". $trx->tx_modulation() . "(" . $trx->tx_symbol_rate() . ", " . $trx->tx_frequency_deviation(). ")");
    
    $logger->info("Uplink : (Smartbick RX)");
    $logger->info("  - Channel    : ". $trx->rx_channel());
    $logger->info("  - Modulation : ". $trx->rx_modulation() . "(" . $trx->rx_symbol_rate() . ", " . $trx->rx_frequency_deviation(). ")");
    return 1;
}

=head2 TRX_Close

This 

=cut
sub TRX_Close
{
    my ($trx) = @_;
    $trx->close();
    return 1;
}

#******************************************************************************
#******************************************************************************
# Service Related

################################################################################
# --------------
my $gCmdUid = 0;
my %gPendingRsp;

# --------------
$SIG{ALRM} = sub 
{ 
    my ($sec, $usec) = gettimeofday;
    # Check if download thread is running
    if ($DwnThread && $DwnThread->is_running) 
    {
        # Stop the thread
        $DwnThreadCtrl->enqueue(0);
    }

    # Check pending response
    for(keys %gPendingRsp)
    {
        #$logger->debug("\nCkPendRspThread :".$_);
        # check if it's out fo date
        if ($sec > $gPendingRsp{$_}[2] + 2 )
        {
            $logger->warn("\nAt [".$sec ."] "
                ."No RSP from "
                .$gPendingRsp{$_}[0]." on CMD "
                .$gPendingRsp{$_}[1]." until "
                .$gPendingRsp{$_}[2] );
            $logger->warn("Remove [".$_."] from pending list.\n");
            delete ($gPendingRsp{$_});
        }
    }
    alarm (10);
};

#******************************************************************************
# Treat Multi ping/pong

=head2 doMultiINST
Parameter: $hexframe, $rssi
    - $hexframe : received raw frame
    - $rssi     : RSSI of received frame

This will treat PING message and generate multiple PONG frame ready to be send.

Return the tuple ($TxChannel, $TxMod, $TxDelay, @trm2) if success
    - $complements : A tuple of element only used when COMMAND is ANNDOWNLOAD
    - $TxChannel   : Channel to TX 
    - $TxMod       : Modulation to TX 
    - $TxDelay     : Waiting delay before sending first frame
    - @trm2        : An array of PONG L2 frame

Return the tuple (undef, undef, undef, undef undef) if failed

=cut
sub doMultiINST {
    my ($hexframe, $rssi) = @_;
    my $ret;
    
    $logger->info("### INSTPING <-- #");
    my $ping = $gApp[APP_PING];

    eval 
    { 
        $ping->extract($hexframe);
    };
    if ($@)
    {
        # Erreur
        #print(Dumper($@));
        $logger->error("ping extract error: ".$@ );
        return (undef, undef, undef, undef, undef);        
    };

    my $TxChannel = $ping->get_response('L7DownChannel');
    my $TxMod = $ping->get_response('L7DownMod');
    my $TxDelay = $ping->get_response('L7PingRxDelay');
    my $TxLength = $ping->get_response('L7PingRxLength');
    
    $logger->debug("wize rev : ".$ping->wize_rev());
    $logger->info("Downlink channel : ". hex($TxChannel));
    $logger->info("Downlink modulation : ". $TxMod);
    $logger->info("Ping RX delay : ". hex($TxDelay) ."s");
    $logger->info("Ping RX length : ". hex($TxLength) ."s");
    $logger->info("NetwId  : ". $ping->Opr() );
    
    
    $logger->info("### INSTPONG --> #");
    my $pong = $gApp[APP_PONG];
                    
    $pong->_update_wize_rev($ping->wize_rev());
    $pong->Opr($ping->Opr());
    $pong->kmac($ping->kmac());
    
    
    $pong->id_fabricant( $ping->get_liaison_response('M-field') );
    $pong->id_ddc( $ping->get_liaison_response('A-field') );
    $pong->set_cpt( hex($ping->cpt) );
    $pong->keysel(0);
    $pong->tx_freq_offset(0000);

    my $complements;
    my $datas->{action} = '';
    my $trm7;
    my @trm2;
    
    my $nb_pong = 2;
    
    $nb_pong = $pong->mainconfig()->{simu}->{PongNb} if  $pong->mainconfig()->{simu}->{PongNb};
    
    for (my $i=0; $i< $nb_pong; $i++) {
        $complements->{L7ConcentId} = $pong->L7ConcentId + $i; 
        $complements->{L7ModemId} = $pong->L7ModemId; 
        $complements->{RSSI} = $rssi;
        
        # ---
        my $EPOCH_UNIX_TO_OURS = 1356998400;
        my ($_sec, $_usec)   = gettimeofday;
        my $epoch_unix       = $_sec + $_usec / 1000000;
        
        $epoch_unix = $epoch_unix + hex($TxDelay);
        if ($i != 0)
        {
            $epoch_unix = $epoch_unix + $msg_min_delay / 1000;
        }
        
        my $epoch_2013 = $epoch_unix - $EPOCH_UNIX_TO_OURS;
        
        $pong->epoch( ceil($epoch_2013) );
        
        # ---
        $trm7 = $pong->build_message($datas->{action}, $complements);
        $pong->build($trm7);
        $trm2[$i] = $pong->message_hexa();
        
    }
    return (undef, $TxChannel, $TxMod, $TxDelay, @trm2);
}

#******************************************************************************
# Treat Admin

=head2 doADM
Parameter: $hexframe, $rssi
    - $hexframe : received raw frame
    - $rssi     : RSSI of received frame

This will treat DATA message and generate, if required, COMMAND frame ready to be send.

Return the tuple ($complements, $TxChannel, $TxMod, $TxDelay, @trm2) if success
    - $complements : 
        - If COMMAND is ANNDOWNLOAD, a tuple of element :
            - DaysProg (4)
            - L7DwnldId (3)
            - L7Klog (16)
            - L7SwVersionIni (2)
            - L7SwVersionTarget (2)
            - L7MField (2)
            - L7DcHwId (2)
            - L7BlocksCount (2)
            - L7ChannelId (1)
            - L7ModulationId (1)
            - L7DaysProg (4)
            - L7DaysRepeat (1) 
            - L7DeltaSec (1) 
            - HashSW (4)
        - undef otherwise
    - $TxChannel   : Channel to TX 
    - $TxMod       : Modulation to TX 
    - $TxDelay     : Waiting delay before sending first frame
    - @trm2        : An array of only one COMMAND L2 frame
        
Return the tuple (undef, undef, undef, undef, undef) if failed
    
=cut
sub doADM {
    my ($hexframe, $rssi) = @_;
    
    my $data = $gApp[APP_IOT];
    my $cmd = $gApp[APP_COMMAND];
    my $admin = $gApp[GEN_ADMIN];
    
    #---------------------------------------------------------------------------
    # Get DATA
    $logger->info("### DATA <-- #");   

    my $trm6 = $data->decompose($hexframe);
    if ($data->BADCRC() == 1)
    {
        return (undef, undef, undef, undef, undef); 
    }
    
    #-------------------------------------------
    # Try to find the dedicated key file
    my $device = $data->id_fabricant().$data->id_ddc();
    my $config = $admin->GetCfgFromFile($device, "key.cfg");
    if ( not defined $config)
    {
        return (undef, undef, undef, undef, undef); 
    }
    
    #-------------------------------------------
    # Get the key
    $data->_load_kenc( $config );
    
    #-------------------------------------------
    # Decrypt L6 frame
    eval 
    { 
        $data->extract($hexframe);
        $logger->info("Data (L6APP = ". $data->App() .") = ". $data->decrypted);
    };
    if ($@)
    {
        # Erreur
        $logger->error("data extract error: ".$@ );
        return (undef, undef, undef, undef, undef);        
    };
    #---------------------------------------------------------------------------
    # Get available command
    $logger->info("### COMMAND --> #");
    
    my $trm7;
    my @trm2;
    
    #-------------------------------------------
    # Re-init RF (in case of)
    my $TxChannel = $cmd->RF_DOWNSTREAM_CHANNEL;
    my $TxMod = $cmd->RF_DOWNSTREAM_MOD;
    my $TxDelay = $cmd->EXCH_RX_DELAY;
    my $TxLength = $cmd->EXCH_RX_LENGTH;
    my $TxRespDelay = $cmd->EXCH_RESPONSE_DELAY;
    
    #-------------------------------------------
    # Init cmd parameters
    $cmd->_load_kenc( $config );
    $cmd->_update_wize_rev($data->wize_rev());
    
    $cmd->Opr($data->Opr());
    $cmd->kmac($data->kmac());
    $cmd->kenc($data->kenc());
    $cmd->version($data->version());
    $cmd->wts($data->wts());
    $cmd->keysel($data->keysel());
    
    $cmd->set_cpt( hex($data->cpt) );
    
    $cmd->id_fabricant( $data->get_liaison_response('M-field') );
    $cmd->id_ddc( $data->get_liaison_response('A-field') );
    
    #-------------------------------------------
    # Get available command, if any
    my ($datas, $complements) = $admin->GenADM($cmd);

    #-------------------------------------------
    # Check if command available
    if ( defined $datas && defined $complements)
    {
        # Build frame
        $trm7 = $cmd->build_message($datas->{action}, $datas->{parameters}, $complements);
        $cmd->build($trm7);
        $trm2[0] = $cmd->message_hexa();
               
        # Set RSP expected time
        my ($sec, $usec) = gettimeofday;
        $sec = $sec + hex($TxDelay) + hex($TxRespDelay) + 1.0;
        
        $gPendingRsp{$gCmdUid} = [ $cmd->id_fabricant().$cmd->id_ddc(), $cmd->cpt, $sec ];
        
        $logger->trace("Set Pending RSP [".$gCmdUid."] : "
            .$gPendingRsp{$gCmdUid}[0].", "
            .$gPendingRsp{$gCmdUid}[1].", "
            .$gPendingRsp{$gCmdUid}[2] );
        
        # Increment Command Uid
        $gCmdUid = $gCmdUid + 1;
    }

    #---------------------------------------------------------------------------
    return ($complements, $TxChannel, $TxMod, $TxDelay, @trm2);
}

#******************************************************************************
# Treat Response

=head2 doRSP
Parameter: $hexframe, $rssi
    - $hexframe : received raw frame
    - $rssi     : RSSI of received frame

This will treat RESPONSE
    
Return the tuple (undef, undef, undef, undef, undef) 
=cut
sub doRSP {
    my ($hexframe, $rssi) = @_;

    my $rsp = $gApp[APP_RESPONSE];
    my $admin = $gApp[GEN_ADMIN];
    
    my ($sec, $usec) = gettimeofday;
    
    #---------------------------------------------------------------------------
    #
    $logger->info("### RESPONSE <-- #");
    
    #-------------------------------------------
    #
    my $trm6 = $rsp->decompose($hexframe);
    if ($rsp->BADCRC() == 1)
    {
        return (undef, undef, undef, undef, undef); 
    }    
    #-------------------------------------------
    # Try to find the dedicated key file
    my $device = $rsp->id_fabricant().$rsp->id_ddc();
    my $config = $admin->GetCfgFromFile($device, "key.cfg");
    if ( not defined $config)
    {
        return (undef, undef, undef, undef, undef); 
    }
    #-------------------------------------------
    # Get the key
    $rsp->_load_kenc( $config );
    
    #-------------------------------------------
    # Extract L7 frame
    eval 
    { 
        $logger->trace ("Try to extract...");
        $rsp->extract($hexframe);
        
        my $L7ResponseId = $rsp->get_response('L7ResponseId');
        my $L7ErrorCode = hex($rsp->get_response('L7ErrorCode'));
        my $L7SwVersion;
        my $L7Rssi;
        my $L7ErrorParam;
        
        $logger->info("L7ResponseId: " .$L7ResponseId . " (" . $rsp->get_commande($L7ResponseId) .")");
        $logger->info("Frame       : " .$rsp->decrypted());
        if ( hex($L7ErrorCode) == 0 ) 
        {
            $L7SwVersion = $rsp->get_response('L7SwVersion');
            $L7Rssi = $rsp->get_response('L7Rssi');
            $logger->info("SW version  : " .$L7SwVersion );
            $logger->info("RSSI        : " .$L7Rssi );
            $logger->info("Error code  : " .$L7ErrorCode );
        }
        else
        {
            my $error_response = $rsp->get_error_response($L7ResponseId);
            $L7ErrorParam = $rsp->get_response('L7ErrorParam');
            $logger->info("Error code  : " .$L7ErrorCode );
            $logger->info("Error desc. : " .$error_response->{$L7ErrorCode} );
            $logger->info("Datas       : [" .$L7ErrorParam."]" );
        }

        for(keys %gPendingRsp)
        {
            # check if this device has pending resposne
            if ($device == $gPendingRsp{$_}[0])
            {
                # check if l6cpt match
                if ($rsp->cpt == $gPendingRsp{$_}[1] )
                {
                    # check if it's out fo date
                    if ($sec > $gPendingRsp{$_}[2] )
                    {
                        $logger->warn("RSP is out of date [".$_."] : "
                            .$gPendingRsp{$_}[0].", "
                            .$gPendingRsp{$_}[1].", "
                            .$gPendingRsp{$_}[2] );
                    }
                    delete ($gPendingRsp{$_});
                    last;
                }
            }
        }
        
        # Check if download thread is running
        if ($DwnThread && $DwnThread->is_running) 
        {
            # Thread exist, that is previous CMD was ANNDOWNLOAD
            # Check if response with no error
            if (hex( $L7ErrorCode) == 0 )
            {
                # Start the thread
                $DwnThreadCtrl->enqueue(1);
                # Then block on it
                $DwnThread->join();
            }
            else 
            {
                # Stop the thread
                $DwnThreadCtrl->enqueue(0);
            }
        }        
    };
    if ($@)
    {
        # Erreur
        $logger->error("data extract error: ".$@ );
        return (undef, undef, undef, undef, undef);        
    };    
    #---------------------------------------------------------------------------

    return (undef, undef, undef, undef, undef);    
}


#******************************************************************************
# Treat Download

=head2 downThread
Parameter: $trx, $complements
$complements with :
    - binFile        : file name and path of the binary (xml) to send
    - L7DaysProg     : Date of the begining, aka first block to send
    - L7DeltaSec     : delta in second between each sent block
    - L7DwnldId      : ...
    - L7BlocksCount  : ...
    - L7ChannelId    : ...
    - L7ModulationId : ...
    - L7Klog         : ...

This will treat DOWNLOAD 
    
Return the tuple (undef, undef, undef, undef) 
=cut
sub downThread 
{
    my ($trx, $complements) = @_;
    $logger->info("### DOWNLOAD thread --- #");
    
    my $dwn = $gApp[APP_DOWNLOAD];
    my $L7DaysProg = $complements->{L7DaysProg};
    my $L7DeltaSec = $complements->{L7DeltaSec};
    my $L7DwnldId = $complements->{L7DwnldId};
    my $L7Klog = $complements->{L7Klog};
    my $L7ChannelId = $complements->{L7ChannelId};
    my $L7ModulationId = $complements->{L7ModulationId};
    my $L7BlocksCount = $complements->{L7BlocksCount};
    my $binFile = $complements->{binFile};
    my $xml_file;
    
    $dwn->klog($L7Klog);
    
    $dwn->kmac($dwn->get_kmac($dwn->Opr));
    $dwn->kenc($dwn->klog);
    $dwn->keysel(18);
    
    $dwn->download_id($L7DwnldId);
    $dwn->version(0);
    
    
    $logger->trace("Download Thread input :".
        "\n\tL7DaysProg     : ".$L7DaysProg.
        "\n\tL7DeltaSec     : ".$L7DeltaSec.
        "\n\tL7DwnldId      : ".$L7DwnldId.
        "\n\tL7Klog         : ".$L7Klog.
        "\n\tL7ChannelId    : ".$L7ChannelId.
        "\n\tL7ModulationId : ".$L7ModulationId.
        "\n\tL7BlocksCount  : ".$L7BlocksCount.
        "\n\tbinFile        : ".$binFile
        );

    # Check if bin file exist
    if (-e $binFile and -f $binFile) 
    {
        my $count = 1;
        my $frame;
        my $binBlockCount;
        
        $logger->debug("$binFile file found!");
        # Read bin.xml file 
        my $dom;

        # - check if bin file is xml or tgz or tar.gz
        my ($base, $dir, $ext) = fileparse($binFile, '\..*');
        if ( $ext == "tgz")
        {
            $logger->trace("Extracting $binFile");
            # - extract if required
            system('mkdir -p .tmp'); 
            system('tar xvzf '.$binFile." -C .tmp" );

            $xml_file = ".tmp/".$base.".xml";
        }
        else
        {
            $xml_file = $binFile;
        }
        
        eval 
        { 
            $dom = XML::LibXML->load_xml(location => $xml_file); 
        };
        if ($@) 
        {
            $logger->warn(qq|[Error XML loading $xml_file file]\n $@|);
        }

        #unlink ".tmp"; 
        rmtree ".tmp"; 
        
        # Check that bloc count match
        $binBlockCount = unpack ("H*", pack( "n", $dom->findvalue('//nbBlocs') ));
        #$logger->debug("... L7BlocksCount : " . sprintf( "%d", hex($L7BlocksCount) ) );
        #$logger->debug("... binBlockCount : " . sprintf( "%d", hex($binBlockCount) ) );
        
        my $Ctrl;
        my $curEpochMs;
        my $prevEpochMs;
        if ( $L7BlocksCount == $binBlockCount )
        {
        
            # Wait for start (RSP ok or nok)
            $logger->debug("Download Thread is waiting RSP");
            $Ctrl = $DwnThreadCtrl->dequeue();
            if( $Ctrl != 1 )
            {
                $logger->debug("Download Thread stopped");
                return ;
            }

            #  -----
            my $_1M = 1000000;
            my $EPOCH_UNIX_TO_OURS = 1356998400;
            my $dayProg = hex($L7DaysProg) + $EPOCH_UNIX_TO_OURS;
            
            my ($sec, $usec) = gettimeofday;
            my $curEpoch = $sec;
            
            my $usEpoch = $sec * $_1M + $usec;
            my $usDayProg = (hex($L7DaysProg) + $EPOCH_UNIX_TO_OURS) * $_1M;
            my $usdelay = 0;
            
            if ($usDayProg < $usEpoch )
            {
                $usdelay = ($usEpoch - $usDayProg) % (hex($L7DeltaSec) * $_1M);
            }
            else 
            {
                $usdelay = ($usDayProg - $usEpoch);
            }                       
            
             
            $logger->debug("Download session will start soon :".
                "\n\t- curEpoch         (UTC)  : ".$curEpoch.
                "\n\t- L7DaysProg (2013 epoch) : ".$L7DaysProg.
                "\n\t- dayProg    (unix epoch) : ".$dayProg.
                "\n\t- delay          (second) : ".($usdelay/$_1M)
                );
            
            $logger->debug("Download session Sleep for $usdelay uS");
            
            #$logger->debug("Delay is $delay second");
            
            # wait DayProg
            #sleep($delay);
            
            usleep($usdelay);
            
            #-------------------------------------------------------------------
            # lock the trx
            
            #-------------------------------------------------------------------
            # Configuration of the TRx
            $trx->deactive_state();
            $trx->set_tx_channel(hex($L7ChannelId));
            $trx->set_tx_wm_modulation(hex($L7ModulationId));
            $trx->clear_fifo_rx();
            $trx->clear_fifo_tx();
            $trx->reset_free_running_clock();
            
            #-------------------------------------------------------------------
            $logger->debug("Download for ". sprintf( "%d", hex($binBlockCount) ) ." blocks start");
            
            my $block_sz;
            my $block_id;
            my $block_frm;
            my $temp; 
                
            # Get block info
            foreach my $block_dom ($dom->findnodes('//blocLogiciel'))
            {
                my ($_sec, $_usec) = gettimeofday;
                
                $curEpochMs = $_sec*1000 + $_usec/1000;
                $prevEpochMs = $curEpochMs;

                $block_sz = $block_dom->findvalue('./BlockSize');
                $block_id = $block_dom->findvalue('./id');
                $block_frm = $block_dom->findvalue('./trameL7');
                $temp = decode_base64($block_frm);

                    
                $logger->trace("block_id : $block_id; block_sz : $block_sz");
                #$logger->trace("block_frm (base 64) : " . $block_frm . " (len : ". length($block_frm) .")");                            
                #$logger->trace("block_frm : " . unpack("H*", $temp) . " (len : ". length($temp) .")");        
                
                #$block_frm = $temp;
                $block_frm = unpack("H*", $temp);

                if ( $count != $block_id ) 
                {
                    $logger->warn("Block Id dosen't match : " . $count . " != ". $block_id);
                    last;
                }
                $logger->info("Broadcast block id : $block_id");
                eval 
                {
                    $dwn->downbnum($block_id);
                    # Build frame
                    $dwn->build($block_frm);
                    $frame = $dwn->message_hexa();
                    #$logger->trace("frame : $frame");

                    # Send frame
                    #$trx->active_state();
                    @$msg_hex = map { hex $_ }  $frame =~ m/([A-Fa-f0-9]{2})/ig;
                    $trx->write_datas($msg_hex, 0);
                    $trx->active_state();
                            
                };
                if ($@) 
                {
                    $logger->warn(qq|[Download error in build frame]\n $@|);
                    last;
                }
                # increment to block count
                $count++;
                if ( $count > hex($binBlockCount) )
                {
                    $logger->info("Download done ");
                    $trx->deactive_state();
                    $trx->clear_fifo_rx();
                    $trx->clear_fifo_tx();
                    $trx->reset_free_running_clock();
                    $trx->active_state();
                    last;
                }

                # wait DeltaSec
                ($_sec, $_usec) = gettimeofday;
                    
                $curEpochMs = $_sec*1000 + $_usec/1000;
                #$delta = $L7DeltaSec*1000 - sprintf("%02f", $curEpochMs - $prevEpochMs );
                $delta = $L7DeltaSec*1000 - ($curEpochMs - $prevEpochMs );
                
                $logger->debug("...wait for ". $delta. " ms from ". sprintf( "%d", hex($L7DeltaSec) )." second");
                #$logger->info("...wait for ". sprintf( "%d", hex($L7DeltaSec) )." second");
                usleep($delta*1000);
                
                #my $wait_time = $delta;
                #while ($wait_time)
                #{
                    #print(".");
                    #sleep(1);
                    #usleep($delta*1000);
                    #$wait_time--;
                #if( ($wait_time % 5000) == 0 )
                #{
                #    print("\n");
                #}
                #}
                #sleep($L7DeltaSec);
                $DwnThreadCtrl->enqueue(1);
            }
        }
        else 
        {
            $logger->warn("Block count $L7BlocksCount doesn't match with $binBlockCount in \"$binFile\"");
        }
    }
    else 
    {
        $logger->warn("File " . $binFile . " not found");
    }
}

#******************************************************************************
# Treat Message

=head2 TreatMessage

This 

=cut
sub TreatMessage
{
    my ($trx, $msg) = @_;
    my ($TxChannel, $TxMod, $TxDelay, $trm2);
    my @trm2Tab;
    my $TxClock = 0;
    my $do_send = 0;    

    my $fake, my $lfield, my $cfield, my $frame;
    my $clock;
    my $l7rssi;
    my $complements;
       
    #-----------
    # Get current time
    my ($sec,$min,$hour) = localtime(time);
    my ($_sec, $_usec)   = gettimeofday;
    my $epoch_unix       = $_sec + $_usec / 1000000;
    my $times_local      = sprintf("%02d:%02d:%02d:%03d", $hour, $min, $sec, $_usec);
       
    #$logger->info($times_local."; ".$sec."; ".$_usec);
    #$logger->info($epoch_unix."; ".$_sec."; ".$_usec);
    
    #-----------
    # Show input   
    $l7rssi = sprintf("%.1f", (0.5*$msg->RSSI - 147.5) );
    $l7rssi_raw = sprintf("0x%x", $msg->RSSI);
    
    ($fake, $frame) = unpack("A2 A*", $msg->message);
    
    $logger->info("[$times_local] [$epoch_unix] [$l7rssi_raw ($l7rssi dBm)] [".$trx->rx_channel()."] [UP] ". $frame);
    
    #
    my $post_delay = -100;
    if ( $trx->config()->{simu}->{post_waiting_delay} )
    {
        $post_delay = $trx->config()->{simu}->{post_waiting_delay};
    }

    #----------
    my $curEpochUnix = gettimeofday;
    my $prvEpochUnix = $curEpochUnix;
        
    ############################################################################
    
    # Get frame fields
    ($fake, $lfield, $cfield, $frame) = unpack("A2 A2 A2 A*", $msg->message);
    # Timestamp
    $clock = $msg->timestamp();
    # RSSI
    $l7rssi = sprintf("%02X", $msg->RSSI);
    
    my $hexframe;
    ($fake, $hexframe) = unpack("A2 A*", $msg->message);

    ##################
    # PING
    if ($cfield eq '46') 
    {
        ($complements, $TxChannel, $TxMod, $TxDelay, @trm2Tab) = doMultiINST(pack("H*", $hexframe), $l7rssi);
        $TxClock = hex($TxDelay)*1000 + $post_delay;
    }
    ##################
    # DATA or DATA PRIO
    elsif ($cfield eq '44' || $cfield eq '54') 
    {    
        ($complements, $TxChannel, $TxMod, $TxDelay, @trm2Tab) = doADM(pack("H*", $hexframe), $l7rssi);
        $TxClock = hex($TxDelay)*1000; 
        $TxClock -= 56; # required negative delay for device with small EXCH_RX_LENGTH        
               
        if ( defined $complements ) 
        {
            if ( $complements->{binFile} )
            {
                # If DwnThread is already running, then stop it
                if ($DwnThread)
                {
                    if ($DwnThread->is_running) 
                    {
                        $logger->warn("Terminate the Download Thread");
                        $DwnThreadCtrl->enqueue(0);
                    }
                }
                $logger->debug("Create Download Thread");
                $DwnThread = threads->new( \&downThread, $trx, $complements);
            }
        }
    }
    ##################
    # ADM RSP 
    elsif($cfield eq '08')
    {
        ($complements, $TxChannel, $TxMod, $TxDelay, @trm2Tab) = doRSP(pack("H*", $hexframe), $l7rssi);
    }
    ##################
    # not expected from device
    else 
    {   
        ($complements, $TxChannel, $TxMod, $TxDelay, @trm2Tab) = (undef, undef, undef, undef, undef);
        $logger->warn("bad cfield: $cfield");
    }
    
    ############################################################################
    if(defined $TxChannel)
    {
        $do_send = scalar @trm2Tab;
    }
    else 
    {
        #$logger->debug("TxChannel not defined" );
        $logger->debug("No more to send" );
    }
    
    if ($do_send) 
    {
        $logger->debug("Prepare to send ".scalar @trm2Tab ." messages in TRX trgiggered fifo" );
        
        my ($sec,$min,$hour) = localtime(time);
        my ($_sec, $_usec) = gettimeofday;
        my $times_local = sprintf("%02d:%02d:%02d:%03d", $hour, $min, $sec, $_usec);
        
        my $delta;
           
        # Configuration of the TRx
        $trx->deactive_state();
        $trx->set_tx_channel(hex($TxChannel));
        $trx->set_tx_wm_modulation(hex($TxMod));
        $trx->clear_fifo_rx();
        $trx->clear_fifo_tx();
        $trx->reset_free_running_clock();
        if ($trx->trig_out_enable()) 
        {
            $trx->set_trigger_mode(0x00, 0x02); #
        }
        
        $trx->active_state();

        # Adjust the sending date to take into account the "TreatMessage" delay
        if ( $TxClock > 0 )
        {
            $curEpochUnix = gettimeofday;
            $delta = sprintf("%02f", $curEpochUnix - $prvEpochUnix);
            #print "curEpoch : $curEpochUnix\n";
            #print "prvEpoch : $prvEpochUnix\n";
            #print "delta : $delta\n";
            $TxClock = $TxClock - ($delta*1000);
        }

        # Ensure is never negative (should never happen)
        if ( $TxClock < 0) 
        {
            $TxClock = 0;
        }
        
        # Case multiple message have to be send
        if ($do_send > 1) 
        {
            my $i;
            
            $prvEpochUnix = $curEpochUnix;
            
            $logger->info("[$times_local] [$curEpochUnix] [ -xx.x dBm  ] [".hex($TxChannel)."] [DN] ");
            $logger->info("    : [trig. delay (ms)] pushed frame");
            #$logger->info("[$times_local] [".sprintf("%05d", $TxClock)."] [ -xx.x dBm  ] [".hex($TxChannel)."] [DN] ");
            
            for ($i = 0; $i < scalar @trm2Tab; $i++ )
            {
                @$msg_hex = map { hex $_ }  $trm2Tab[$i] =~ m/([A-Fa-f0-9]{2})/ig;
                do
                {
                    $trx->check_fifo();          
                    if($trx->tx_fifo_message_count() > 3) 
                    {
                        usleep(100);
                    }
                } while($trx->tx_fifo_message_count() > 3);
                
                # Write the frame into the FIFO 
                $trx->write_datas($msg_hex, $TxClock);
                $curEpochUnix = gettimeofday;
                $delta = sprintf("%02f", $curEpochUnix - $prvEpochUnix);
                
                # $logger->info("    Push [$delta]  trigger : [".sprintf("%05d", $TxClock)."] ". $trm2Tab[$i]);
                $logger->info("    : [".sprintf("%05d", $TxClock)."] ". $trm2Tab[$i]);
                
                $TxClock = $msg_min_delay;
            }            
        }
        # Case only one message has to be send
        else
        {
            $curEpochUnix = gettimeofday;
            
            #usleep($TxClock*1000);
            @$msg_hex = map { hex $_ }  $trm2Tab[0] =~ m/([A-Fa-f0-9]{2})/ig;
            $trx->write_datas($msg_hex, $TxClock);
            #$trx->write_datas($msg_hex, 0);
            $trx->active_state();
            #$logger->info("[$times_local] [".sprintf("%05d", $TxClock)."] [ -xx.x dBm  ] [".hex($TxChannel)."] [DN] ". $trm2Tab[0]);
            $logger->info("[$times_local] [$curEpochUnix] [ -xx.x dBm  ] [".hex($TxChannel)."] [DN] [trig. ".sprintf("%05d", $TxClock)."] ".$trm2Tab[0]);
            #$logger->info("    : [trig. delay (ms)] pushed frame");
            #$logger->info("    : [".sprintf("%05d", $TxClock)."] ". $trm2Tab[0]);
        }

        # Everything is done
        $do_send = 0; # in case of
    }
}

#******************************************************************************
# Service mode (Loop)

=head2 ServiceMode

This 

=cut
sub ServiceMode
{
    my ($trx) = @_;
    my $i = 0;
    
    if ( $trx->config()->{simu}->{msg_min_delay} )
    {
        $msg_min_delay = $trx->config()->{simu}->{msg_min_delay} 
    }
    
    $logger->info("\n### SmartBick is listening ###");
    $logger->info("[  Time  ] [ Unix Epoch (ms) ] [ RSSI (dBm) ] [ CH ] [ UP/DN ]");
    
    my @messages; 
    my $msg; 
    
    # Create the alarm to check the "dead" pending response
    alarm (5);
    
    while (1)
    {
        if ($trx->trig_out_enable()) 
        {
            do
            {
                $trx->check_fifo();
                
            } while($trx->tx_fifo_message_count());
            
            $trx->deactive_state();
            $trx->set_trigger_mode(0x00, 0x03); #
        }
        
        eval
        {
            @messages = $trx->read_response_waiting_message(1);
            $msg = $messages[0];
        };
        
        if ($@)
        {
            $logger->fatal("Error : RX :(" . $@->{error} ." : ". $@->{message} );
        };
        
        if($msg)
        {
            if ($msg->error_code == TRX_MESSAGE_OK)
            {
                print("\n");
                # Frame Received
                TreatMessage($trx, $msg);
                usleep(1000);
                $logger->info("***************************************\n");
            }
        }
        else 
        {
            if($i>10)
            {
                print("\n");
                $i=0;
            }
            print(".");
            $i++;
        }
    }
    return 1;
}

#******************************************************************************
# Frame mode

=head2 FrameMode

This 

=cut

sub FrameMode
{
    my ($device_id, $wize_rev, $keysel, $Opr) = @_;
    $logger->debug("# Frame Mode");
    $logger->trace("device_id : $device_id" );
    $logger->trace("wize_rev  : $wize_rev" );
    $logger->trace("keysel    : $keysel" );
    $logger->trace("Opr       : $Opr" );
    
    my $cmd = $gApp[APP_COMMAND];
    my $admin = $gApp[GEN_ADMIN];
    
    my $trm2; 
    
    if ( $device_id eq '' )
    {
        $logger->error("Device id $device_id is wrong");
        return (undef);
    }
    
    # Get available command and key files
    my $device = $device_id;
    my ($id_fabricant, $id_ddc) = unpack ("A4 A12", $device);

    $cmd->id_fabricant(sprintf("%04x", hex($id_fabricant)) );
    $cmd->id_ddc( $id_ddc );
    
    $cmd->_update_wize_rev($wize_rev);
    $cmd->Opr($Opr);
    $cmd->keysel($keysel);
    #$cmd->version($version);
    #$cmd->wts($wts);
    #$cmd->set_cpt( hex(0000) );
    $cmd->kmac( $cmd->get_kmac( $Opr ) );
    
    $logger->trace("id_fabricant : ".$cmd->id_fabricant() );
    $logger->trace("id_ddc       : ".$cmd->id_ddc() );    
    
    
    #-------------------------------------------
    # Try to find the dedicated key file
    my $config = $admin->GetCfgFromFile($device, "key.cfg");
    if ( not defined $config)
    {
        return (undef); 
    }

    $cmd->_load_kenc( $config );
    
    #-------------------------------------------
    # Get available command, if any
    my ($datas, $complements) = $admin->GenADM($cmd);
    
    # Try to find the dedicated admin file
    #-------------------------------------------
    # Check if command available
    if ( defined $datas && defined $complements)
    {
        my $trm7;
        # Build frame
        $trm7 = $cmd->build_message($datas->{action}, $datas->{parameters}, $complements);
        $cmd->build($trm7);
        $trm2 = $cmd->message_hexa();

        # check if CMD was correctly build and if was an ANN_DOWNLOAD
        if ( $datas->{action} ) 
        {
            if ( $datas->{action} ne 'COMMAND_ANNDOWNLOAD' )
            {
                $complements->{L7ChannelId} = $cmd->RF_DOWNSTREAM_CHANNEL; 
                $complements->{L7ModulationId} = $cmd->RF_DOWNSTREAM_MOD;
            }

            $complements->{action} = $datas->{action};
            $complements->{device_id} = $device_id;
            $complements->{wize_rev} = $wize_rev;
            $complements->{keysel} = $keysel;
            $complements->{Opr} = $Opr;
            $complements->{L2Frm} = $trm2;
            
            $logger->debug("FRM L2 : $trm2");
        }
        else 
        {
            return (undef);
        }
    }
    else 
    {
        return (undef);
    }

    return ($complements);
}

#******************************************************************************
# Free mode

# Free mode command
use constant {
    IDLE => 0,
    TX   => 1,
    RX   => 2,
    PWR  => 3,
    STOP => 10,
    EXIT => 20,
};

my @channel_list = (100, 110, 120, 130, 140, 150 );
my @modulation_list = (0, 1, 2);

=head2 FreeMode_Menu

This 

=cut

sub FreeMode_Menu {
    my $input = '\0';
    my @command;
    my ($ret, $cmd, $Channel, $Mod, $repeat, $message) = (1, IDLE, 0, 0, 0, 'Glop...Glop');
    
    # sudo apt-get install libreadline7 or libreadline6
    # sudo apt-get install readline-common
    
    # required : sudo apt-get install libterm-readline-gnu-perl
    # sudo apt-get install libterm-ui-perl
    
    my $term = Term::ReadLine->new("Simple Shell");
    $term->ornaments(0); 
    
    # cmd : 
    #  TX channel modulation repeat [frame]
    #  RX channel modulation window
    print("Send   : TX channel modulation repeat [frame] (repeat in step every second)\n");
    print("Listen : RX channel modulation window (window in second) \n");
    print("Quit   : q \n");
    $input = $term->readline("\$> : ");
    
    $term->addhistory($input) if /\S/;
    
    @command = split(' ', $input);
    
    if($command[0] eq "TX" )   { $cmd = TX; }
    elsif($command[0] eq "RX" ){ $cmd = RX; }
    elsif($command[0] eq "q" ) 
    { 
        $cmd = EXIT; 
        return (1, $cmd, $Channel, $Mod, $repeat, $message);
    }
    else                       
    { 
        $cmd = IDLE; 
        print("Unknonw command\n");
        return (0, $cmd, $Channel, $Mod, $repeat, $message);
    }    

    if(scalar @command < 4)
    {
        print("Missing parameter\n");
        return (0, $cmd, $Channel, $Mod, $repeat, $message);
    }
    
    $Channel = sprintf("%d", $command[1]);
    $Mod     = sprintf("%d", $command[2]);
    $repeat  = sprintf("%d", $command[3]);
        
    if( !($Channel ~~ @channel_list) ) 
    { 
        print("Unknonw Channel\n"); 
        return (0, $cmd, $Channel, $Mod, $repeat, $message);
    }

    if( !($Mod ~~ @modulation_list) ) 
    { 
        print("Unknonw Modulation\n"); 
        return (0, $cmd, $Channel, $Mod, $repeat, $message);
    }
    
    if( $repeat > 999 ) 
    { 
        if($cmd == TX)
        {
            print("Repeat is limited to 999\n"); 
        }
        if($cmd == RX)
        {
            print("Listening window is limited to 999 second\n"); 
        }
        return (0, $cmd, $Channel, $Mod, $repeat, $message);
    }    

    if($cmd == TX)
    {
         if(scalar @command > 4)
         {
            $message = $command[4];
         }
         else
         {
            $message = unpack("H*",$message);
         }
    }

    return ($ret, $cmd, $Channel, $Mod, $repeat, $message);
}

=head2 FreeMode

This 

=cut

sub FreeMode
{
    my ($trx) = @_;
    my $done = 0;
    my $TxClock = 0;

    my ($sec,$min,$hour);
    my ($s_sec, $usec);
    my $date_time;
    
    my $timestamp;
    my $prev_timestamp;
    
    my @messages; 
    my ($ret, $cmd, $Channel, $Mod, $repeat, $msg);
    
    local $SIG{ALRM} = sub { $cmd = STOP; };
    
    $cmd = IDLE;
    print("\n");
    print "RAW MODE : ".$trx->raw_mode_cfg()."\n\n";
    
    while ($done == 0)
    {
        if ( $cmd == IDLE)
        {
            ($ret, $cmd, $Channel, $Mod, $repeat, $msg) = FreeMode_Menu();
            if ($ret == 0)
            {
                $cmd = IDLE;
            }           
            #printf("%d : %s , %d, %d, %d, %s\n", $ret, $cmd, $Channel, $Mod, $repeat, $msg);
        }
        elsif ( $cmd == EXIT)
        {
            $done = 1;
        }
        elsif ( $cmd == STOP)
        {
            print("\n");
            $trx->deactive_state();
            $trx->clear_fifo_tx();
            $trx->clear_fifo_rx();
            $trx->reset_free_running_clock();
            $cmd = IDLE;
        }
        elsif ( $cmd == TX)
        {
            # Configuration of the TRx
            $trx->deactive_state();
            $trx->set_tx_channel($Channel);
            $trx->set_tx_wm_modulation($Mod);
            $trx->clear_fifo_tx();

            $trx->reset_free_running_clock();
            $trx->set_raw_mode($trx->raw_mode_cfg());

            if ($trx->trig_out_enable()) 
            {
                $trx->set_trigger_mode(0x00, 0x02); #
            }
            
            $trx->active_state();

            while ($cmd != STOP)
            {               
                my $temp;
                if ($trx->raw_mode() eq "OFF")
                {
                    $temp = pack ("H4 H*", sprintf("%04d", $repeat), $msg);
                }
                else 
                {
                    $temp = pack ("H*", $msg);
                }
                #print("$repeat : $temp\n");
                #DHexDump($temp);
                
                $temp = unpack("H*",$temp);
                @$msg_hex = map { hex $_ }  $temp =~ m/([A-Fa-f0-9]{2})/ig;
             
                $trx->write_datas($msg_hex, $TxClock);
                
                ($sec,$min,$hour) = localtime(time);
                ($s_sec, $usec) = gettimeofday;
                $date_time = sprintf("%02d:%02d:%02d:%03d", $hour, $min, $sec, $usec);
            
                print("$repeat [$date_time] [ -xx.x dBm  ] [".$trx->tx_channel()."] [TX] ". $temp);               
                print("\n");
                sleep(1);
                if($repeat == 0)
                {
                    $cmd = STOP;
                }
                $repeat--;
            }
        }
        
        elsif ( $cmd == RX)
        {
            # Configuration of the TRx
            $trx->deactive_state();
            $trx->set_rx_channel($Channel);
            $trx->set_rx_wm_modulation($Mod);
            $trx->clear_fifo_rx();
            
            $trx->reset_free_running_clock();
            $trx->set_raw_mode($trx->raw_mode_cfg());
            
            if ($trx->trig_out_enable()) 
            {
                $trx->set_trigger_mode(0x00, 0x03); #
            }

            $trx->active_state();    
            
            alarm $repeat;

            ($sec,$min,$hour) = localtime(time);
            ($s_sec, $usec) = gettimeofday;
            $timestamp = gettimeofday;
            $date_time = sprintf("%02d:%02d:%02d:%03d", $hour, $min, $sec, $usec);
            
            my $delta;;
            
            while ($cmd != STOP)
            {
                eval
                {
                    @messages = $trx->read_response_waiting_message(1);
                    $msg = $messages[0];
                };

                if ($@)
                {
                    print("Error : RX :(" . $@->{error} ." : ". $@->{message} );
                    print("\n");
                    $cmd = STOP;
                };
                if($msg)
                {
                    if ($msg->error_code == TRX_MESSAGE_OK)
                    {
                        $prev_timestamp = $timestamp;
                        $timestamp = gettimeofday;
                        $delta = $timestamp - $prev_timestamp;
                        
                        ($sec,$min,$hour) = localtime(time);
                        ($s_sec, $usec) = gettimeofday;
                        $date_time = sprintf("%02d:%02d:%02d,%03d", $hour, $min, $sec, $usec);
                        
                        
                        $trx->deactive_state();
                        # Trame reçue
                        $l7rssi = sprintf("%.1f", -0.5*$msg->RSSI);
                        print("\n");
                        
                        if ( $trx->raw_mode == 'ON' )
                        {
                            ($fake, $frame) = unpack("A2 A*", $msg->message);
                            print("[$date_time] [ $l7rssi dBm  ] [".$trx->rx_channel()."] [RX] " . $frame . " [$delta]");
                        }
                        else
                        {
                            print("[$date_time] [ $l7rssi dBm  ] [".$trx->rx_channel()."] [RX] " . $msg->message . " [$delta]");
                        }
                        print("\n");
                        usleep(100);
                        #print("***************************************\n");
                    }
                }
                else 
                {
                    if($i>10)
                    {
                        print("\n");
                        $i=0;
                    }
                    print(".");
                    $i++;
                }
            }
            
        }
    }
}

#******************************************************************************
#******************************************************************************

=head2 CleanExit

This remove temporary files

=cut
sub CleanExit
{
    unlink TEMP_FILE_NAME;
    unlink TRX_CFG_FILE_NAME;
}

=head2 SetLogLevel
Parameter: 
    - $verbose : logger level to set
    - $main    : application logger to use  
 
This change the internal library logger level

=cut
sub SetLogLevel
{
    my ($verbose, $xVerbose)=@_;
    my $log;
    #print "verbose = $verbose ; xVerbose = $xVerbose\n";
    
    # Setup verbose level on each application "sub" class
    if( $xVerbose > 0) 
    {
        foreach my $app (instping, instpong, command, data, response, download )
        {
            $log = Log::Log4perl::get_logger("application.$app");
            $log->more_logging($xVerbose); # inc logging level
        }
        foreach my $app (admin )
        {
            $log = Log::Log4perl::get_logger("extend.$app");
            $log->more_logging($xVerbose); # inc logging level
        }
    }
    if( $verbose > 0) 
    {
        $log = Log::Log4perl::get_logger("TrxServices");
        $log->more_logging($verbose); # inc trxService log level
    }
    # Get the new Application logger
    undef $logger;
    $logger = Log::Log4perl::get_logger("TrxServices");
}

#*******************************************************************************

=head2 Options

This extract option from command line

Return the tuple : ($verbose, $xVerbose, $trxcfg, $maincfg, $mode);

=cut
sub Options
{
    #*******************************************
    my $mode_str = "";
    my $trx_cfg_fname = "";
    my $main_cfg_fname = "";
    my $verbose = 0;
    my $xVerbose = 0;
    my $mode = MODE_SERVICE;
    my $help=0;

    GetOptions (
        "mode=s"     => \$mode_str,
        "tcfg|t=s"   => \$trx_cfg_fname,
        "mcfg|m=s"   => \$main_cfg_fname,
        "verbose|v+" => \$verbose,
        "x+"         => \$xVerbose,
        "help|h"     => \$help,
        )
    or die("Error in command line arguments\n");
    
    if ($help) 
    {
        print "$USAGE\n";
        print "Version : $CurVersion; Commit : $CurCommit; Contact : $CurSupport\n\n";
        exit 0;    
    }

    SetLogLevel($verbose, $xVerbose);

    $logger->debug("LIB_BASE_DIR = $lib_base_dir");
    CleanExit();
    
    ###############################################
    # Check mode
    if ( $mode_str eq "FRAME" )
    {
        $mode = MODE_FRAME;
    }
    elsif ($mode_str eq "FREE")
    {
        $mode = MODE_FREE;
    }
    #else { nothing, stay in MODE_SERVICE }

    ###############################################
    # Check main_cfg file
    #if ( $mode != MODE_FREE )
    {
        if (-e $main_cfg_fname and -f $main_cfg_fname) 
        {
            $logger->debug("$main_cfg_fname file found!");
        } 
        else 
        {
            $logger->error("main config file not found!");
            print "$USAGE\n";  
            exit -1;
        }
    }
    ###############################################
    # Check trx_cfg file
    if ( $mode != MODE_FRAME )
    {
        if (-e $trx_cfg_fname and -f $trx_cfg_fname) 
        {
            $logger->debug("$trx_cfg_fname file found!");
        } 
        else 
        {
            $logger->error("trx config file not found!");
            print "$USAGE\n";  
            exit -1;
        }
    }

    ###############################################
    # Generate the main config file 
    my $maincfg=TEMP_FILE_NAME;
    open my $out, '>>', $maincfg or die "Could not open '$maincfg' for appending\n"; 
    # 
    print $out $main_def_cfg;
    
    # Copy main cfg file
    if (open my $in, '<', $main_cfg_fname) 
    {
        while (my $line = <$in>) 
        {
            print $out $line;
        }
        close $in;
    } 
    else 
    {
        $logger->warn("Could not open '$main_cfg_fname' for reading");
    }
    close $out;
    
    ###############################################
    # Fake Application instance, just to get RF parameters
    my $fake_app = Telereleve::Application::Command->new(
        testname=>"fake", mainconfig_file => $maincfg,
        check_params => 0, format =>"exchange");
    
    SetLogLevel($verbose, $xVerbose);

    ###############################################
    # Generate the trx config file 
    my $trxcfg=TRX_CFG_FILE_NAME;
    if ( $mode != MODE_FRAME )
    {
        open my $out, '>>', $trxcfg or die "Could not open '$trxcfg' for appending\n"; 
        # 
        print $out $trx_def_cfg;
        print $out "[smartbrick]"."\n";
        print $out "TX_CHANNEL=".hex($fake_app->RF_DOWNSTREAM_CHANNEL())."\n";
        print $out "RX_CHANNEL=".hex($fake_app->RF_UPSTREAM_CHANNEL())."\n";
        print $out "TX_WM_MODULATION=".hex($fake_app->RF_DOWNSTREAM_MOD())."\n";
        print $out "RX_WM_MODULATION=".hex($fake_app->RF_UPSTREAM_MOD())."\n";
        
        # Copy trx cfg file
        if (open my $in, '<', $trx_cfg_fname) 
        {
            while (my $line = <$in>) 
            {
                print $out $line;
            }
            close $in;
        } 
        else 
        {
            $logger->warn("Could not open '$trx_cfg_fname' for reading");
        }
        close $out;
    }

    ###############################################

    return ($verbose, $xVerbose, $trxcfg, $maincfg, $mode, @ARGV);
}

=head2 Main

This is the main function 

=cut
sub Main
{
    my $app_name = "TRxServices";
    my $mode = MODE_SERVICE;
    my @extra_param;
    my ($verbose, $xverbose, $trxcfg, $maincfg, $mode, @extra_param) = Options();

    if ( $mode != MODE_FREE )
    {
        # Instantiate Application "class"
        $gApp[APP_PING] = Telereleve::Application::Ping->new(
            testname=>$app_name, mainconfig_file => $maincfg,
            check_params => 1);#, format =>"exchange");

        $gApp[APP_PONG] = Telereleve::Application::Pong->new(
            testname=>$app_name, mainconfig_file => $maincfg,
            check_params => 1, format =>"exchange");
            
        $gApp[APP_COMMAND] = Telereleve::Application::Command->new(
            testname=>$app_name, mainconfig_file => $maincfg,
            check_params => 0, format =>"exchange");
            
        $gApp[APP_RESPONSE] = Telereleve::Application::Response->new(
            testname=>$app_name, mainconfig_file => $maincfg,
            check_params => 1, format =>"exchange");

        $gApp[APP_IOT] = Telereleve::Application::Iot->new(
            testname=>$app_name, mainconfig_file => $maincfg,
            check_params => 1, format =>"exchange");

        $gApp[APP_DOWNLOAD] = Telereleve::Application::Download->new(
            testname=>$app_name, mainconfig_file => $maincfg,
            check_params => 1, format =>"download");
            
        $gApp[GEN_ADMIN] = Telereleve::Extend::Admin->new(
            logger_config_file => "./log.cfg");
    }
    # Set the Logger level
    SetLogLevel($verbose, $xverbose);

    if ($check_color_level)
    {
        $logger->info("Check color");
        $logger->debug("Check color");
        $logger->trace("Check color");
        $logger->warn("Check color");
        $logger->error("Check color");
        $logger->fatal("Check color");
    }
    
    my $ret;
    #*******************************************
    if ( $mode == MODE_FRAME )
    {
        $logger->debug($app_name." Start"." (FRAME mode)");
        my $complements;
        #*******************************************
        # Run Frame
        
        # Required argument (@extra_param) are : 
        # $device_id (concatenation of Mfield and Afiled as defined in L2 frame header)
        # $wize_rev (one from {0.0, 1.0, 1.1}
        # $keysel
        # $Opr (operator id, aka. L6NetwID)( for wize_rev 0.0, use L6NetwID 255)
        $ret = FrameMode(@extra_param);
        if( defined $ret  ) 
        { 
            my $arg = 
                $ret->{action} . " " .
                $ret->{device_id} . " " .
                $ret->{L7ChannelId} . " " .
                $ret->{L7ModulationId} . " " .
                $ret->{L2Frm};

            if ( $ret->{binFile} )
            {
                $arg = $arg . " " .
                    $ret->{L7DaysProg} . " " .
                    $ret->{L7DaysRepeat} . " " .
                    $ret->{L7DeltaSec} . " " .
                    $ret->{binFile} ;

                #$logger->info($arg);
            }
            print $arg;
            print "\n";
        }
        else 
        {
            $logger->warn("Frame is empty!!!");
            goto end_stage_final; 
        }
    }
    else # ($mode == MODE_SERVICE ) or ( $mode == MODE_FREE )
    { 
        if ( $mode == MODE_FREE )
        {
            $logger->debug($app_name." Start"." (FREE mode)");
        }
        elsif ( $mode == MODE_SERVICE )
        {
            $logger->debug($app_name." Start"." (SERVICE mode)");
        }
        else 
        {
            goto end_stage_final;
        }
        
        # Instantiate TRX class
        my $trx;
        $trx = Telereleve::COM::Trx->new(config => $trxcfg);
        #*******************************************
        # Open then Init TRX
        $ret = TRX_Open($trx);
        if($ret != 1 ) { goto end_stage_1; }
        #*******************************************
        # Run it
        if ( $mode == MODE_FREE)
        {        
            # Free
            $ret = FreeMode($trx);
            if($ret != 1 ) { goto end_stage_1; }
        }
        elsif ( $mode == MODE_SERVICE )
        {
            # Service
            $ret = ServiceMode($trx);
            if($ret != 1 ) { goto end_stage_1; }        
        }
        #*******************************************
        # End, Close TRX
        end_stage_1 : {
            TRX_Close($trx);
        }
    }
    # never happen:  else { goto end_stage_final; }
    
    #*******************************************
    
    end_stage_final : {
        $logger->debug($app_name." End");
        exit();
    }
}

Main();

#*******************************************************************************
