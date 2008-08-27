package CatalystX::CRUD::YUI::View;

use warnings;
use strict;
use Carp;
use base qw( Catalyst::View::TT );
use Data::Dump qw( dump );
use Class::C3;
use Path::Class;
use Class::Inspector;
use CatalystX::CRUD::YUI;
use CatalystX::CRUD::YUI::TT;

our $VERSION = '0.003';

=head1 NAME

CatalystX::CRUD::YUI::View - base View class

=head1 SYNOPSIS

 # TODO

=head1 DESCRIPTION

 # TODO

=head1 CONFIGURATION

Configuration is the same as with Catalyst::View::TT. Read those docs.

The default config here is:

 __PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    PRE_PROCESS        => 'crud/tt_config.tt',
    WRAPPER            => 'crud/wrapper.tt',
 );

=cut

# default config here instead of new() so subclasses can more easily override.
__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    PRE_PROCESS        => 'crud/tt_config.tt',
    WRAPPER            => 'crud/wrapper.tt',
);

=head1 METHODS

Only new or overridden method are documented here.

=cut

=head2 new

Overrides base new() method. Sets
INCLUDE_PATH to the base
CatalystX::CRUD::YUI::TT .tt files plus your local app root.
This means you can override the default template behaviour
by putting a .tt file with the same name in your C<root> template dir.

For example, to customize your C<wrapper.tt> file, just copy the default one
from the C<CatalystX/CRUD/YUI/TT/crud/wrapper.tt> in @INC and put it
in C<root/crud/wrapper.tt>. Likewise, you can set up a global config file
by creating a C<root/crud/tt_config.tt> file and putting your MACROs and other
TT stuff in there.

=cut

sub new {
    my ( $class, $c, $arg ) = @_;

    my $template_base
        = Class::Inspector->loaded_filename('CatalystX::CRUD::YUI::TT');
    $template_base =~ s/\.pm$//;

    # important that local 'root' path is first,
    # followed by $template_base and then whatever
    # is already set.
    # *AND* no duplicates.
    my @inc_path = (
        Path::Class::dir( $c->config->{root} ),
        Path::Class::dir($template_base)
    );
    for my $path ( @{ $class->config->{INCLUDE_PATH} || [] } ) {
        if ( grep { $path eq $_ } @inc_path ) {
            next;
        }
        push( @inc_path, $path );
    }
    
    #dump \@inc_path;

    $class->config( { INCLUDE_PATH => \@inc_path } );

    return $class->next::method( $c, $arg );
}

=head2 template_vars

Overrides base method to add some other default variables.

=over

=item

The C<yui> variable is a CatalystX::CRUD::YUI object.

=item

The C<page> variable is a hashref with members B<js> and B<css>.
It is used by crud/page_head_maker.tt to ease the addition of 
per-request .js and .css files. Stuff the base file name into
the array in each .tt file to get those files included in the 
page header.

Example:

 [% page.css.push('foo') %]
 
 # html <head> section will contain:
 # <link type="stylesheet" href="[% static_url %]/css/foo.css" />

=item

The C<static_url> variable defaults to $c->uri_for('/static').
You can override that in $c->config() by setting a 'static_url'
value to whatever base URL you wish. Ideal for serving your static
content from different URL than your dynamic content.

=back

=cut

sub template_vars {
    my ( $self, $c ) = @_;

    my $cvar = $self->config->{CATALYST_VAR};

    defined $cvar
        ? ( $cvar => $c )
        : (
        c    => $c,
        base => $c->req->base,
        name => $c->config->{name},
        yui  => CatalystX::CRUD::YUI->new(),
        page => { js => [], css => [] },
        static_url => ( $c->config->{static_url} || $c->uri_for('/static') ),
        );
}

1;

__END__

=head1 AUTHOR

Peter Karman, C<< <karman@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-catalystx-crud-yui@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically be
notified of progress on your bug as I make changes.

=head1 ACKNOWLEDGEMENTS

The Minnesota Supercomputing Institute C<< http://www.msi.umn.edu/ >>
sponsored the development of this software.

=head1 COPYRIGHT & LICENSE

Copyright 2008 by the Regents of the University of Minnesota.
All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

