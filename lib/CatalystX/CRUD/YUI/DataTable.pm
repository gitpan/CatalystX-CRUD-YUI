package CatalystX::CRUD::YUI::DataTable;

use warnings;
use strict;
use Carp;
use Data::Dump qw( dump );
use Class::C3;
use base qw( Class::Accessor::Fast );
use JSON::XS ();
use Scalar::Util qw( blessed );
use CatalystX::CRUD::YUI::Serializer;

our $VERSION = '0.002';

__PACKAGE__->mk_accessors(
    qw( yui results controller form
        method_name pk columns show_related_values
        col_filter col_names url count counter
        field_names sort_by show_remove_button
        serializer_class serializer
        )
);

=head1 NAME

CatalystX::CRUD::YUI::DataTable - YUI DataTable objects

=head1 SYNOPSIS

 my $datatable = $yui->datatable( 
            results     => $results,    # CX::CRUD::Results or CX::CRUD::Object
            controller  => $controller, 
            form        => $form,
            method_name => $rel_info->{method},
            col_names   => $form->metadata->field_methods,
 );
  
 $datatable->serialize;  # returns serialized results
 $datatable->count;      # returns number of rows
 
=head1 METHODS

=head2 new( I<opts> )

Create a YUI DataTable object.
You usually call this via CatalystX::CRUD::YUI->datatable( I<opts> ).

I<opts> should include:

=over

=item results

The I<results> object passed in. May be either
a CatalystX::CRUD::Results instance or CatalystX::CRUD::Object
instance.

If a Results instance, each object in the Results set will
be serialized.

If a Object instance, each object returned by I<method_name>
will be serialized.

=item form

The I<form> object should be an instance of the Form
class that corresponds to the data being serialized.
In the case where I<results> isa CatalystX::CRUD::Results
object, I<form> should be a Form corresponding
to the object class in CatalystX::CRUD::Results->results().
In the case where I<results> isa CatalystX::CRUD::Object,
I<form> should be a Form corresponding to the foreign
object class represented by I<method_name>.

=item controller

The I<controller> object should be the governing controller for
the objects being serialized, i.e., the controller governing I<form>.

=back

The new DataTable has the following accessors available:

=over

=item pk

The primary key of the table that I<results> represents.

=item columns

An arrayref of column hashrefs. YUI DataTable API requires these.

=item url

The url for fetching JSON results.

=item show_related_values

A hashref of foreign key information.

=item col_filter

An arrayref of column names.  # TODO used for??

=item col_names

An arrayref of column names. Defaults to I<form>->metadata->field_methods.

=item data

An arrayref of hashrefs. These are serialized from I<results>.

=item count

The number of items in I<data>.

=item counter

User-level accessor. You can get/set this to whatever you want.

=back

B<NOTE:> If you pass a CatalystX::CRUD::Object instance as I<results>
to new(), the object must implement a primary_key_uri_escaped() method
that conforms to the syntax defined by CatalystX::CRUD::Controller
make_primary_key_string(). See Rose::DBx::Object::MoreHelpers for one
example.

=cut

sub new {
    my $self = shift->next::method( ref $_[0] ? @_ : {@_} );
    $self->{serializer_class} ||= 'CatalystX::CRUD::YUI::Serializer';
    $self->_init;
    return $self;
}

sub _init {
    my $self       = shift;
    my $results    = $self->{results} or croak "results required";
    my $controller = $self->{controller}
        or croak "controller required";
    my $form = $self->{form} or croak "form required";

    # may be undef. this is the method we call on the the parent object,
    # where parent $results isa RDBO and we are creating a datatable out
    # of its related objects.
    my $method_name = $self->{method_name};

    my @col_names = @{ $self->{col_names} || $form->metadata->field_methods };

    if (    $results->isa('CatalystX::CRUD::Results')
        and defined $form->app
        and !$form->app->stash->{object} )
    {

        # no parent, so do not include columns that require it.
        #my $takes_object = $form->metadata->takes_object_as_argument;
        #@col_names = grep { !exists $takes_object->{$_} } @col_names;
    }

    $self->pk(
        ref $controller->primary_key
        ? $controller->primary_key
        : [ $controller->primary_key ]
    );
    $self->columns( [] );
    $self->show_related_values( {} );
    $self->col_filter( [] );
    $self->col_names( \@col_names );
    $self->sort_by( $form->metadata->default_sort_by || $self->pk->[0] );

    #carp "col_names for $results: " . dump $self->col_names;

    #carp dump $results;

    if ( $results->isa('CatalystX::CRUD::Results')
        && defined $results->query )
    {
        $self->url(
            $form->app->uri_for(
                $controller->action_for('yui_datatable'),
                $results->query->{plain_query}
            )
        );
    }
    else {

        #carp "results isa " . $results->delegate;
        #carp "controller isa " . $controller;

        if ( !$method_name ) {
            croak
                "method_name required for CatalystX::CRUD::Object datatable";
        }
        $self->url(
            $form->app->uri_for(
                $controller->action_for(
                    $results->primary_key_uri_escaped,
                    'yui_related_datatable',
                    $method_name,
                )
            )
        );
    }

    $self->{url} .= '?' unless $self->{url} =~ m/\?/;

    for my $field_name (@col_names) {

        my $isa_field = $form->field($field_name);

        push(
            @{ $self->{columns} },
            {   key => $field_name,

                # must force label object to stringify
                label => defined($isa_field)
                ? $isa_field->label . ''
                : ( $form->metadata->labels->{$field_name} || $field_name ),

                sortable => $isa_field
                ? JSON::XS::true()
                : JSON::XS::false(),

                # per-column click
                url => $form->app->uri_for(
                    $form->metadata->field_uri($field_name)
                ),

            }
        );

        if (    $isa_field
            and $form->field($field_name)->class =~ m/text|char/ )
        {
            push( @{ $self->{col_filter} }, $field_name );
        }

        if ( grep { $_ eq $field_name } @{ $self->{pk} } ) {
            next;
        }

        next unless $form->metadata->show_related_values;
        next unless $form->metadata->is_related_field($field_name);

        my $rel_info = $form->metadata->related_field($field_name);

        $self->{show_related_values}->{$field_name} = {
            method        => $rel_info->{method},
            foreign_field => $form->metadata->show_related_field_using(
                $rel_info->{foreign_class}, $field_name,
            ),
        };

    }

    return $self;

}

=head2 column( I<field_name> )

Return the column hashref meta for I<field_name>.
The hashref has 3 keys: key, label, and sortable.

=cut

sub column {
    my $self       = shift;
    my $field_name = shift;
    for my $col ( @{ $self->columns } ) {
        return $col if $col->{key} eq $field_name;
    }
    return undef;
}

=head2 serialize 

Returns DataTable as array ref of hash refs, suitable
for conversion to JSON or other transport type.

=cut

sub serialize {
    my $self = shift;
    my $serializer = $self->serializer || $self->serializer_class->new;
    return $serializer->serialize_datatable($self);
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

