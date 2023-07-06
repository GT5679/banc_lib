##!/usr/bin/perl
#! /bin/env "perl -n"


package SC_Build; 

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
use Data::Dumper qw(Dumper);

# libxml-compile-perl
# libdatetime-format-natural-perl 
# libdata-peek-perl 

use lib "$lib_base_dir/lib"; 
use Telereleve::Iowizmi::Builder::SC04;
use Telereleve::Iowizmi::Builder::SC06;

#*******************************************************************************

my $USAGE =<<USAGE;

Description:
This tool generate commands frames and xml SC06, SC04

Usage:
perl trxServices.pl -m main.cfg --mode FRAME -- device_id wize_rev keysel Opr | xargs perl ./SC_Build.pl Operator Subscriber Sensor IC port

Example : 
perl trxServices.pl -m prv_main_2.cfg --mode FRAME -- 11A5001727673003 0.0 0 255 | xargs  perl ./SC_Build.pl IOWIZMI IOWIZMI DME001727673003 5115810000647 1

Device directory "11A5001727673003" has to exist and its content :
    - admin.cfg :
        Should include COMMAND and all related required parameters.
    - keys.cfg :
        Should includes device keys, at least the ones uses for the requested COMMAND.

Result is written into : 
SC04 : "./SC04-Operator-Subscriber-Sensor-IC_CurentDateTime.xml"
SC06 : "./SC06-BinDirName-IC_CurentDateTime.xml"


Iowizmi - WizeUp

perl trxServices.pl -m main_iowizmi.cfg --mode FRAME -- 25F7000000010000 1.2 0 255 | xargs  perl ./SC_Build.pl IOWIZMI IOWIZMI IOW000000010000 5115810000647 1

USAGE


if (@ARGV == 0)
{
    print "$USAGE\n";    
    exit 0;
}

# Get from command line
my ($Operator, $Subscriber, $Sensor, $IC, $Port, $action, $device_id, $L7ChannelId, $L7ModulationId, $L2Frm, @rest) = @ARGV;

#*******************************************************************************
my $SC04_xsd_file = "./IowizmiTest/xsd/sc04_v2.xsd";
my $SC06_xsd_file = "./IowizmiTest/xsd/TelediffRequest_sc06.xsd";

$SC04 = Telereleve::Iowizmi::Builder::SC04->new( logger_config_file => "./log.cfg", xsd_file => $SC04_xsd_file );
$SC06 = Telereleve::Iowizmi::Builder::SC06->new( logger_config_file => "./log.cfg", xsd_file => $SC06_xsd_file );

$SC04->logger()->more_logging(2);
$SC06->logger()->more_logging(2);

# Required arguments are : 
# SC04 
#   Operator Subscriber Sensor IC L7ChannelId, L7ModulationId, FrmL2
# SC06
#   IC, Port, L7ChannelId, L7ModulationId, L7DaysProg, L7DaysRepeat, L7DeltaSec, binFile

# Get from command line
# Operator Subscriber Sensor IC Port
#
# Get from trxServices
# action, device_id, L7ChannelId, L7ModulationId, L2Frm, (optionaly) : L7DaysProg, L7DaysRepeat, L7DeltaSec, binFile
#

$SC04->logger()->info("Build frame : $action");
$SC04->build($Operator, $Subscriber, $Sensor, $IC, $L7ChannelId, $L7ModulationId, $L2Frm);

if ( $action eq 'COMMAND_ANNDOWNLOAD')
{
    my ($L7DaysProg, $L7DaysRepeat, $L7DeltaSec, $binFile) = @rest;
    $SC06->build($IC, $Port, $L7ChannelId, $L7ModulationId, $L7DaysProg, $L7DaysRepeat, $L7DeltaSec, $binFile);
}
