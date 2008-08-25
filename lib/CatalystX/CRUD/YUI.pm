package CatalystX::CRUD::YUI;

use warnings;
use strict;
use Carp;
use CatalystX::CRUD::YUI::DataTable;
use CatalystX::CRUD::YUI::Serializer;
use base qw( Class::Accessor::Fast );
use Class::C3;

__PACKAGE__->mk_accessors(qw( datatable_class serializer_class ));

our $VERSION = '0.001';

=head1 NAME

CatalystX::CRUD::YUI - YUI for your CatalystX::CRUD view

=head1 SYNOPSIS

 # TODO

=head1 DESCRIPTION

 # TODO
 
=head1 METHODS

Only new or overridden method are documented here.

=cut

=head2 new( I<opts> )

=cut

sub new {
    my $self = shift->next::method(@_);
    $self->{datatable_class}  ||= 'CatalystX::CRUD::YUI::DataTable';
    $self->{serializer_class} ||= 'CatalystX::CRUD::YUI::Serializer';
    return $self;
}

=head2 datatable( I<opts> )

Returns a CatalystX::CRUD::YUI::DataTable object
ready for the yui_datatable.tt template.

I<opts> should consist of:

=over

=item results

I<results> may be either a CatalystX::CRUD::Results object or a 
CatalystX::CRUD::Object object.

=item controller

The Catalyst::Controller instance for the request.

=item form

The current Form object. The Form class should be
Rose::HTMLx::Form::Related, a subclass thereof, or
a class with a corresponding API.

=item rel_info

If I<results> is a CatalystX::CRUD::Object object, 
then a I<rel_info> should be passed indicating
which relationship to pull data from.

=item field_names

Optional arrayref of field names to include. Defaults
to form->meta->field_methods().

=back

=cut

sub _fix_args {
    my @arg = @_;
    if ( @arg == 1 ) {
        if ( ref( $arg[0] ) eq 'ARRAY' ) {
            @arg = @{ $arg[0] };
        }
        elsif ( ref( $arg[0] ) eq 'HASH' ) {
            @arg = %{ $arg[0] };
        }
    }
    return @arg;
}

sub datatable {
    my $self = shift;
    #carp "get datatable";
    return $self->datatable_class->new( _fix_args(@_), yui => $self );
}

=head2 serializer

Returns new Serializer object of type serializer_class().

=cut

sub serializer {
    my $self = shift;
    return $self->serializer_class->new( _fix_args(@_), yui => $self );
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

