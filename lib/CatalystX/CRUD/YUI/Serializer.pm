package CatalystX::CRUD::YUI::Serializer;

use warnings;
use strict;
use Carp;
use base 'Class::Accessor::Fast';
use Class::C3;
use Scalar::Util qw( blessed );
use JSON::XS ();
use Data::Dump qw( dump );

__PACKAGE__->mk_accessors(qw( datetime_format yui ));

our $VERSION = '0.003';

=head1 NAME

CatalystX::CRUD::YUI::Serializer - flatten CatalystX::CRUD::Object instances

=head1 SYNOPSIS

 # TODO

=head1 DESCRIPTION

 # TODO
 
=head1 METHODS

Only new or overridden method are documented here.

=cut

=head2 new

Instantiate new Serializer.

=cut

sub new {
    my $class = shift;
    my $self = $class->next::method( ref $_[0] ? @_ : {@_} );
    $self->{datetime_format} ||= '%Y-%m-%d %H:%M:%S';
    return $self;
}

=head2 datetime_format

Set strftime-style DateTime format string. Default is '%Y-%m-%d %H:%M:%S'.
Used in serialize_object().

=cut

=head2 serialize_object( I<params> )

Serialize a CatalystX::CRUD::Object instance, or an object that acts like one. 
I<params> should be a hash or hashref of key/value pairs.
The "object" key pair and "col_names" key pair are required.

I<params> include:

=over

=item

I<object> is the CRUD object to be serialized. B<Required>

=item

I<rel_info> is the struct returned by Form->metadata->relationship_info() method.

=item

I<col_names> is the list of column names to include in the serialized hashref.
B<Required>

=item

I<parent_object> is the originating RDBO object, in the case where you are serializing
related objects.

=item

I<cat_context> is a $c object.

=item

I<show_related_values> is a hash ref of methods and foreign fields,
as defined by B<I<TODO>>.

=item

I<takes_object_as_argument> is a hashref of method names where I<parent_object>
is expected as a single argument.

=back

Returns a hashref of key/value pairs representing the object.

=cut

sub serialize_object {
    my $self         = shift;
    my %opts         = ref( $_[0] ) ? %{ $_[0] } : @_;
    my $object       = delete $opts{object} or croak "CRUD object required";
    my $show_related = delete $opts{show_related_values};
    my $takes_object = delete $opts{takes_object_as_argument};
    my $col_names    = delete $opts{col_names} or croak "col_names required";

    if ( defined $show_related
        and ref($show_related) ne 'HASH' )
    {
        croak "show_related_values should be a hashref";
    }
    if ( defined $takes_object
        and ref($takes_object) ne 'HASH' )
    {
        croak "takes_object_as_argument should be a hashref";
    }
    if ( ref($col_names) ne 'ARRAY' ) {
        croak "col_names array ref required";
    }

    my $flat = {};
    if ( defined $opts{datatable} and $opts{datatable}->show_remove_button ) {
        $flat->{'_remove'} = ' X ';
    }

    #carp "calling col_names on $object : " . dump $col_names;

    #carp dump $takes_object;

    for my $col (@$col_names) {

        # sanity check
        if ( !$object->can($col) ) {
            croak "no such method '$col' for object $object";
        }

        # non-accessor methods. these are NOT FK methods.
        # see below for $show_related_values.
        if ( exists $takes_object->{$col} and exists $opts{parent} ) {

            # TODO revisit this api
            # right now we only pass parent if it isa class
            # designated in the $takes_object hash

            #warn "FOUND takes_object $col => $opts{parent}";

            if ( my $parent_class = blessed( $opts{parent} ) ) {
                my $obj_to_pass;
                if ( $opts{parent}->can('delegate')
                    and blessed( $opts{parent}->delegate ) )
                {

                    #warn " obj with delegate = " . $opts{parent}->delegate;
                    if ( $opts{parent}->delegate->isa( $takes_object->{$col} )
                        )
                    {
                        $obj_to_pass = $opts{parent}->delegate;
                    }
                }
                elsif ( $opts{parent}->isa( $takes_object->{$col} ) ) {
                    $obj_to_pass = $opts{parent};
                }

                if ($obj_to_pass) {
                    eval { $flat->{$col} = $object->$col( $opts{parent} ); };
                    if ($@) {
                        $flat->{$col} = '[not available]';
                    }
                }
                else {
                    $flat->{$col} = $object->$col;
                }

            }
            else {
                eval { $flat->{$col} = $object->$col( $opts{parent} ); };
                if ($@) {
                    $flat->{$col} = '[not available]';
                }
            }

        }

        # DateTime objects
        elsif ( blessed( $object->$col ) && $object->$col->isa('DateTime') ) {
            if ( defined $object->$col->epoch ) {
                $flat->{$col}
                    = $object->$col->strftime( $self->datetime_format );
            }
            else {
                $flat->{$col} = '';
            }
        }

        # FKs
        elsif ( defined $show_related
            and exists $show_related->{$col} )
        {
            my $srv    = $show_related->{$col};
            my $method = $srv->{method};
            my $ff     = $srv->{foreign_field};

            #warn "col: $col  rdbo: $rdbo  method: $method  ff: $ff";
            if ( defined $object->$method && defined $ff ) {
                $flat->{$col} = $object->$method->$ff;
            }
            else {
                $flat->{$col} = $object->$col;
            }
        }

        # booleans
        elsif ( $object->can('column_is_boolean')
            and $object->column_is_boolean($col) )
        {
            $flat->{$col} = $object->$col ? 'true' : 'false';
        }

        # default
        else {
            $flat->{$col} = $object->$col;

        }

    }

    return $flat;

}

=head2 serialize_datatable( I<datatable_object> )

Returns array ref of hash refs as passed through serialize_object().

=cut

sub serialize_datatable {
    my $self      = shift;
    my $datatable = shift or croak "DataTable object required";
    my $results   = $datatable->results
        or croak "no results in DataTable object";
    my $method_name = $datatable->method_name || '';
    my $max_loops
        = $datatable->form->app->req->params->{_no_page}
        ? 0
        : (    $datatable->form->app->req->params->{_page_size}
            || $datatable->controller->page_size );

    my $counter = 0;
    my @data;
    my $iterator;

    if ( $results->isa('CatalystX::CRUD::Results') ) {
        $iterator = $results;
    }
    else {
        if ( !$method_name ) {
            croak
                "method_name required for non-CatalystX::CRUD::Results object with 'results' key";
        }
        my $method = $method_name . '_iterator';
        $iterator = $results->$method;
    }

    while ( my $object = $iterator->next ) {
        push(
            @data,
            $self->serialize_object(
                {   object      => $object,
                    method_name => $method_name,
                    col_names   => $datatable->col_names,
                    parent      => $datatable->form->app->stash->{object},
                    c           => $datatable->form->app,
                    show_related_values => $datatable->show_related_values,
                    takes_object_as_argument =>
                        $datatable->form->metadata->takes_object_as_argument,
                    datatable => $datatable,
                }
            )
        );
        last if $max_loops > 0 && ++$counter > $max_loops;
    }

    $datatable->{count} = $counter;

    return \@data;
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

