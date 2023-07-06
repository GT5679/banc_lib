##!/usr/bin/perl
#! /bin/env "perl -n"


package BinPack_Build; 

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


use lib "$lib_base_dir/lib"; 
use Telereleve::Iowizmi::Builder::BinPack;
use Archive::Tar;
use File::Basename;

#*******************************************************************************


my $USAGE =<<USAGE;

Description:
This tool generate the BINARIES.xml and DESCRIPTION.xml files from the given binary file

Usage:
perl BinPack_Build.pl ManufName BinFileName SwVersion DestDir

TODO : (fixed for now)
   Klog = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f";
   Type = 0;
   RefTechVer = 0;
   CompatVer = ([0, 1.00, 0.00]);

Example : 
perl BinPack_Build.pl DME ./IowizmiTest/bin/uTestApp.bin 1.98 ./LocalTest/down/

Result is written into : 
BINARY      : "./BINARY.xml"
DESCRIPTION : "./DESCRIPTION.xml"

USAGE


if (@ARGV == 0)
{
    print "$USAGE\n";    
    exit 0;
}

# Get from command line
my ($ManufName, $BinFileName, $SwVersion, $DestDir) = @ARGV;

#*******************************************************************************
my @xsd = (
    "./IowizmiTest/xsd/TransmettreLogicielEmetteur-v1.16/BINAIRES_v1.16.xsd",
    "./IowizmiTest/xsd/TransmettreLogicielEmetteur-v1.16/SCON02-TransmettreDonneesLogiciellesEmetteur-v1.3.xsd"
    );

if ($DestDir eq '') 
{
    $BinPack  = Telereleve::Iowizmi::Builder::BinPack->new( logger_config_file => "./log.cfg", xsd_file => $xsd[0] );
    $DescPack = Telereleve::Iowizmi::Builder::BinPack->new( logger_config_file => "./log.cfg", xsd_file => $xsd[1] );
}
else 
{
    $BinPack  = Telereleve::Iowizmi::Builder::BinPack->new( logger_config_file => "./log.cfg", xsd_file => $xsd[0], dest_dir => $DestDir );
    $DescPack = Telereleve::Iowizmi::Builder::BinPack->new( logger_config_file => "./log.cfg", xsd_file => $xsd[1], dest_dir => $DestDir );
}

# Required arguments are : 
#my $ManufName = "DME";
my $Type = 0;
my $RefTechVer = 0;
my $Klog = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f";
#my $BinFileName = "./IowizmiTest/bin/uTestApp.bin";
#my $SwVersion = "1.98";
#my @CompatVer = ( [10, 3.144, 129.98], [10, 3.144, 1.968], [10, 3.117, 1.48] );
my @CompatVer = ([0, 1.00, 0.00]);

$BinPack->logger()->more_logging(3);
$BinPack->build('BINARY', $ManufName, $Type, $RefTechVer, $Klog, $BinFileName, $SwVersion, @CompatVer);

#if ( Archive::Tar->create_archive($DestDir."/".$BinPack->xml_file.".tgz", COMPRESS_GZIP, $DestDir."/".$BinPack->xml_file.".xml") )
#{
    #$BinPack->logger->error(Archive::Tar->error);
#}

my $tgz_file_str = $DestDir."/".$BinPack->xml_file.".tgz";
my $src_files = $BinPack->xml_file .".xml";

system('tar cvzf '.$tgz_file_str." --directory=".$DestDir."/"." ". $src_files ); 
unlink $DestDir."/".$src_files; 


$DescPack->logger()->more_logging(3);
$DescPack->build('DESCRIPTION', $ManufName, $Type, $RefTechVer, $Klog, $BinFileName, $SwVersion, @CompatVer);

