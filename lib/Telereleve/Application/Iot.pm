package Telereleve::Application::Iot;

use Moose;
use feature qw(say);
use Data::Dumper;
use FFI::Platypus;

extends 'Telereleve::Application';

our $VERSION = '0.1';

my $Iot_lib_file;
my $mangler;

has 'iot_lib' => (
    is   => 'rw',
    isa  => 'FFI::Platypus',
    lazy => 1,
    default => sub { 
        my $self = shift;
        if ($self->mainconfig()->{IOT}->{lib_path})
        {
            $Iot_lib_file = $self->mainconfig()->{IOT}->{lib_path};
        }
        else 
        {
            $Iot_lib_file = "../lib/shared/libIOT.so.1.0.0";
        }
        if ($self->mainconfig()->{IOT}->{mangler})
        {
            $mangler = $self->mainconfig()->{IOT}->{mangler};
        }
        else 
        {
            $mangler = "IotLib_";
        }
        #print "$Iot_lib_file \n";
        #print "$mangler \n";
        FFI::Platypus->new(lib => $Iot_lib_file);
    }
);

has '_iot_extract' => (
    is   => 'ro',
    lazy => 1,
    default => sub { 
        my $self = shift; 
        $self->iot_lib->function($mangler.Extract => ['uint8', 'string'] => 'int');
    }
);

has '_iot_set_logger' => (
    is   => 'ro',
    lazy => 1,
    default => sub {  
        my $self = shift;
        $self->iot_lib->type('(int, string)->int' => 'closure_t');
        $self->iot_lib->function($mangler.RegisterLogger => ['closure_t'] => 'void');
    }
);

has '+application' => (
    is      => 'rw',
    default => 'DATA',
);

has 'type_trame' => (
    is => 'rw'
);

has 'name_type_trame' => (
    is => 'rw'
);

has 'trame' => (
        is => 'rw',
        isa => 'Telereleve::Application::Iot::Frames'
);


override 'build' => \&_build;

override 'extract' => \&_extract;

sub BUILD {


}

sub _build {
    my ($self,$message) = @_; 
    $self->logger->info($self->application() . " begin.");
    confess("Input message is missing!") unless $message;
    super();
    $self->logger->info($self->application() . " done");
}

sub _extract {
    my ($self) = @_; 
    $self->logger->info($self->application() . " begin.");
    super();
    if ($self->hashkenc_error() == 1) 
    {
        $self->logger()->warn("kenc false: unable to extract data");
    } else {
        $self->extract_datas();
    }
    $self->logger->info($self->application() . " done");
}

sub extract_datas {
    my ($self) = @_;
    
    my $mref = $self->iot_lib->closure( 
        sub { 
            $self->logger->log(@_);
        } 
    ); 
    $self->_iot_set_logger->call($mref);
    
    $self->logger()->debug("Call _iot_extract");
    my @req_tab = ();
    my $len = 0;
    my $ret = 0;
    my $req = $self->App(). $self->decrypted();
    @req_tab = map { pack('C', hex($_)) } ($req =~ /(..)/g);
    $len = scalar(@req_tab);
    $ret = $self->_iot_extract->call($len, @req_tab);
    $self->logger()->debug("_iot_extract return ".$ret);
}

no Moose;
__PACKAGE__->meta->make_immutable;

1; # End of Telereleve::Application::Iot
