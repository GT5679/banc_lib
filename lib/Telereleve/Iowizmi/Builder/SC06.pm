package Telereleve::Iowizmi::Builder::SC06;

use Moose;

extends 'Telereleve::Iowizmi::Builder';

use XML::LibXML;
use XML::Compile::Schema;

use MIME::Base64;

use Date::Parse;
use DateTime;
use DateTime::Format::Natural;
use File::Basename;


our $VERSION = '0.0';

has '+module' => (
    is => 'rw',
    default => 'SC06',
);

has 'xsd_element' => (
    is => 'rw',
    default => 'TelediffRequest',
);

override 'build' => \&_build;

sub _build {
    my ($self, $IC, $Port, $L7ChannelId, $L7ModulationId, $L7DaysProg, $L7DaysRepeat, $L7DeltaSec, $binFile) = @_;
    
    $self->logger->info($self->module);
    
    $self->logger->debug("\tIC             : $IC");
    $self->logger->debug("\tPort           : ".hex($Port) );
    $self->logger->debug("\tL7ChannelId    : ".hex($L7ChannelId) );
    $self->logger->debug("\tL7ModulationId : ".hex($L7ModulationId) );
    $self->logger->debug("\tL7DaysProg     : ".hex($L7DaysProg) );
    $self->logger->debug("\tL7DaysRepeat   : ".hex($L7DaysRepeat));
    $self->logger->debug("\tL7DeltaSec     : ".hex($L7DeltaSec) );
    $self->logger->debug("\tbinFile        : $binFile");
    
    #***************************************************************************
    $self->logger->debug("Build xml");
    $self->logger->debug("\txsd : " .$self->xsd_file);
    
    my $data = $self->schema->template(
        'PERL' => $self->xsd_element, 
        show_comments => '', 
        skip_header => 'true', 
        output_style => 1
        );

    $data =~ s/#.*//g;
    $data =~ s/\s*//g;
    $data = eval($data);
    
    #***************************************************************************
    $data->{HeaderInfo}->{IC} = $IC;
    $data->{TelediffDetail}[0]->{Port} = hex($Port);
   
    # Get filename
    my ($base, $dir, $ext) = fileparse($binFile, '\..*');
    my @spl = split('/', $dir);
    $data->{FileName} = @spl[scalar @spl - 1];
    
    # Get file
    #if (open my $in, '<', $binFile) 
    #{
        #while (<$in>) 
        #{
        #    $data->{File} = encode_base64("$_");
        #}
        #close $in;
    #}
    if (open IN, '<', $binFile) 
    {
        #my $raw = <IN>;
        my $raw = do{ local $/ = undef; <IN>; };
        close IN;
        $data->{File} = $raw;
        #print encode_base64($raw);
    } 
    else 
    {
        $self->logger->warn("Could not open '$binFile' for reading");
    }

    # Get prog dates and expiration date
    my $next_day = hex($L7DaysProg);
    my $i = 0;
    for ( $i = 0; $i < $L7DaysRepeat; $i++) 
    {
        $data->{TelediffDetail}[0]->{Dates}[$i] = $next_day;
        $next_day += 86400;
    }
    $i--;
    $next_day += str2time("2013-01-01 00:00:00");
    $data->{TelediffDetail}[0]->{DateExpiration} = DateTime->from_epoch( epoch => $next_day );

    # Get the rest
    $data->{TelediffDetail}[0]->{RfDownStreamMod} = hex($L7ModulationId);
    $data->{TelediffDetail}[0]->{RfDownStreamChannel} = hex($L7ChannelId);
    $data->{TelediffDetail}[0]->{InterFrameDelta} = hex($L7DeltaSec);
    
    #***************************************************************************
    # build ouput
    $self->xml_file( $self->module."-".$data->{FileName}."-".$IC."_".DateTime->now()->strftime("%Y-%m-%d") );
    $self->_out_xml_file($data);
   
    return 0;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1; # End of Telereleve::Iowizmi::SC06
