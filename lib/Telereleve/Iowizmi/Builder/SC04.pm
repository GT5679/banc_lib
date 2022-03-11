package Telereleve::Iowizmi::Builder::SC04;

use Moose;

extends 'Telereleve::Iowizmi::Builder';

use XML::LibXML;
use XML::Compile::Schema;

use MIME::Base64;

use Date::Parse;
use DateTime;
use DateTime::Format::Natural;
use File::Basename;

use Data::Dumper qw(Dumper);
use Data::Peek;

our $VERSION = '0.0';

has '+module' => (
    is => 'rw',
    default => 'SC04',
);

has 'xsd_element' => (
    is => 'rw',
    default => 'InputTeleoperation',
);

override 'build' => \&_build;

sub _build {
    my ($self, $Operator, $Subscriber, $Sensor, $IC, $L7ChannelId, $L7ModulationId, $FrmL2) = @_;
    
    $self->logger->info($self->module);
    
    $self->logger->debug("\tOperator       : $Operator");
    $self->logger->debug("\tSubscriber     : $Subscriber");
    $self->logger->debug("\tSensor         : $Sensor");
    $self->logger->debug("\tIC             : $IC");
    $self->logger->debug("\tL7ChannelId    : ".hex($L7ChannelId) );
    $self->logger->debug("\tL7ModulationId : ".hex($L7ModulationId) );
    $self->logger->debug("\tFrmL2          : $FrmL2");
    
    #***************************************************************************
    $self->logger->debug("Build xml");
    $self->logger->debug("\txsd : " .$self->xsd_file);

    $self->schema->importDefinitions("iowizmi-v1.0.xsd");
    
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
    $data->{Operator} = $Operator;
    $data->{IC} = $IC;
    $data->{Teleoperation}[0]->{Subscriber} = $Subscriber;
    $data->{Teleoperation}[0]->{Sensor} = $Sensor;
    $data->{Teleoperation}[0]->{teleoperationDetail}->{RfDownstreamMod} = hex($L7ModulationId);
    $data->{Teleoperation}[0]->{teleoperationDetail}->{RfDownStreamChannel} = hex($L7ChannelId);
    $data->{Teleoperation}[0]->{teleoperationDetail}->{VerFE} = "0.1";
    #$data->{Teleoperation}[0]->{teleoperationDetail}->{L2Frame} = encode_base64($FrmL2);
    
    my $msg = pack("H*" ,$FrmL2);
    $self->logger->trace("L2 Frm hexdump form Input");
    $self->logger->trace(DHexDump($msg));
    $data->{Teleoperation}[0]->{teleoperationDetail}->{L2Frame} = $msg;
    
    my $db64 = $data->{Teleoperation}[0]->{teleoperationDetail}->{L2Frame};
    $self->logger->debug("L2 Frm hexdump from base64");
    $self->logger->debug(DHexDump($db64));
    
    #***************************************************************************
    # build ouput
    $self->xml_file( $self->module."-".$Operator."-".$Subscriber."-".$Sensor."-".$IC."_".DateTime->now()->strftime("%Y-%m-%d") );
    $self->_out_xml_file($data);
    
    return 0;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1; # End of Telereleve::Iowizmi::SC04
