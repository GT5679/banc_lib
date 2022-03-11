 
package Telereleve::Iowizmi::Builder;

use Moose;

use Config::Tiny;
use Log::Log4perl qw(:easy);
use Log::Log4perl::Appender::File;

use Telereleve::Application;

use XML::LibXML;
use XML::Compile::Schema;

use MIME::Base64;

use Date::Parse;
use DateTime;
use DateTime::Format::Natural;
use File::Basename;

use Data::Dumper qw(Dumper);

our $VERSION = '0.0';

has 'module' => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_module_name',
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

has 'schema' => (
    is => 'rw'
);

has 'xsd_file' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    predicate => 'has_xsd_file',
    clearer  => 'clear_xsd_file',
    trigger  => \&_load_xsd_file,
);

has 'xsd_element' => (
    is => 'rw',
    isa => 'Str',
    default => '',
);

has 'xml_file' => (
    is => 'rw',
    isa => 'Str',
);

has 'dest_dir' => (
    is => 'rw',
    isa => 'Str',
    default => './',
);

sub build {
    my ($self) = @_;
    
    $self->logger->info($self->module);
    return 0;
}


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
            $self->logger( Log::Log4perl->get_logger( lc("iowizmi.".$self->module) ));
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

sub _load_xsd_file 
{
    my ($self) = @_;
    confess("xsd file is required") unless $self->has_xsd_file;
    unless (-e $self->xsd_file) 
    {
        confess(qq|The xsd file is missing: |.$self->xsd_file );
    }
    
    $self->schema(XML::Compile::Schema->new($self->xsd_file));
    my ($base, $dir, $ext) = fileparse($self->xsd_file, '\..*');
    $self->schema->addSchemaDirs($dir);
}

sub _out_xml_file
{
    my ($self, $data) = @_;
    
    my $doc = XML::LibXML::Document->new('1.0', 'UTF-8');
    my $write = $self->schema->compile(WRITER => $self->xsd_element, check_values => 1, validation => 1);
    
    my $xml   = $write->($doc, $data);

    my $filename = $self->dest_dir.$self->xml_file.".xml";
    my $state;
    
    $doc->setDocumentElement($xml);
    $self->logger->info("...write to $filename file");
    $state = $doc->toFile($filename, 1);
    
    return $state;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1; # End of Telereleve::Iowizmi::Builder
