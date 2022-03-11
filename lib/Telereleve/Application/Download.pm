package Telereleve::Application::Download;

use Moose;
use feature qw(say);

extends 'Telereleve::Application';

=head1 NAME

Telereleve::Application::Download - gestionnaire de téléchargement via le LAN

=head1 VERSION

Version 0.50

=cut

our $VERSION = '0.50';


=head1 SYNOPSIS

    use Telereleve::Application::Download;

    my $download = Telereleve::Application::Download->new();

=head2 Attributes

=cut

has '+application' => (
	is 		=> 'rw',
	default => 'DOWNLOAD',
);

has 'debug' => (
	is => 'rw',
	predicate => 'debug_mode',
);

has '+aes_callback' => (
	default => sub { \&Telereleve::Layer::Presentation::_init_crypt_download } 
);

=head1 SUBROUTINES/METHODS

=cut

override 'build' => \&_build;

override 'extract' => \&_extract;


=head2 _build

=cut

sub _build {
    my ($self,$message) = @_; 
    $self->logger->info($self->application() . " begin.");
    confess("Message manquant") unless $message;
    super();
    $self->logger->info($self->application() . " done");
}

=head2 _extract

=cut

sub _extract {
    my ($self) = @_; 
    super() unless $self->debug_mode;
}

=head1 AUTHOR

phv, C<< <philippe.devisme at suez-env.com> >>

=head1 BUGS

Please report any bugs or feature requests to Ondeo Systems.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Telereleve::Application::Download

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014-2015 Ondeo Systems.

This program is NOT free software; you cannot redistribute it and/or modify it.


=cut

no Moose;
__PACKAGE__->meta->make_immutable;
1; # End of Telereleve::Application::Download
