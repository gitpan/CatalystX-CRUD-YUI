package CatalystX::CRUD::YUI::Controller;

use warnings;
use strict;
use base qw( CatalystX::CRUD::Controller );
use Carp;
use Class::C3;

__PACKAGE__->mk_accessors(qw( autocomplete_columns autocomplete_method ));

our $VERSION = '0.001';

=head1 NAME

CatalystX::CRUD::YUI::Controller - base controller

=head1 SYNOPSIS

 # TODO

=head1 DESCRIPTION

 # TODO
 
=head1 METHODS

Only new or overridden method are documented here.

=cut

=head2 json_mime

Returns JSON MIME type. Default is 'application/json; charset=utf-8'.

=cut

sub json_mime {'application/json; charset=utf-8'}

=head2 auto

Fix up some YUI parameter names and stash the form object.
See the Catalyst documentation for other special features of the auto()
Private method.

=cut

sub auto : Private {
    my ( $self, $c, @arg ) = @_;

    # in YUI > 2.5.0 the paginator uses non-sql-friendly sort dir values
    if ( exists $c->req->params->{_dir} ) {
        $c->req->params->{_dir} =~ s/yui\-dt\-//;
    }

    $self->next::method( $c, @arg );
}

=head2 default

Redirects to URI for 'count' in same namespace.

=cut

sub default : Path {
    my ( $self, $c ) = @_;
    $c->response->redirect( $c->uri_for('count') );
}

# YUI DataTable support

=head2 yui_datatable( I<context>, I<arg> )

Public URI method. Like calling search() but returns JSON
in format the YUI DataTable expects.

=cut

sub yui_datatable : Local {
    my ( $self, $c, @arg ) = @_;
    $c->stash->{view_on_single_result} = 0;
    $self->do_search( $c, @arg );
    $c->stash->{template} = 'crud/yui_datatable.tt';
    $c->response->content_type( $self->json_mime );
}

=head2 yui_datatable_count( I<context>, I<arg> )

Public URI method. Like calling count() but returns JSON
in format the YUI DataTable expects.

=cut

sub yui_datatable_count : Local {
    my ( $self, $c, @arg ) = @_;
    $c->stash->{fetch_no_results}      = 1;
    $c->stash->{view_on_single_result} = 0;
    $self->do_search( $c, @arg );
    $c->stash->{template} = 'crud/yui_datatable_count.tt';
    $c->response->content_type( $self->json_mime );
}

=head2 yui_related_datatable( I<oid>, I<relationship_name> )

Public URI method. Returns JSON like yui_datatable but for the records
referred to by I<relationship_name>.

=cut

sub yui_related_datatable : PathPart Chained('fetch') Args(1) {
    my ( $self, $c, $rel_name ) = @_;
    $c->stash->{view_on_single_result} = 0;
    $self->do_related_search( $c, $rel_name );
    $c->stash->{template} = 'crud/yui_datatable.tt';
    $c->response->content_type( $self->json_mime );
}

=head2 do_related_search( I<context>, I<relationship_name> )

Sets up stash() to mimic the foreign controller 
represented by I<relationship_name>.

=cut

sub do_related_search {
    my ( $self, $c, $rel_name ) = @_;

    my $obj = $c->stash->{object};
    my $query = $self->do_model( $c, 'make_query' );

    # TODO this section is specific to RDBO. refactor it.
    # many2many relationships always have two tables,
    # and we are sorting my the 2nd one. The 1st one is the mapper.
    if ( $c->req->params->{_m2m} ) {
        $query->{sort_by} =~ s/t1\./t2\./g;    # re-disambiguate id and name
        if ( $query->{sort_by} !~ m/t\d\./ ) {
            $query->{sort_by} = join( '.', 't2', $query->{sort_by} );
        }
    }

    my $count = $obj->has_related($rel_name);
    my $results = $self->do_model( $c, 'iterator_related', $obj, $rel_name );
    my $pager;
    if ($count) {
        $pager = $self->do_model( $c, 'make_pager', $count, $results );
    }

    $c->stash(
        results => CatalystX::CRUD::Results->new(
            {   count   => $count,
                pager   => $pager,
                results => $results,
                query   => $query,
            }
        )
    );

    # set the controller so we mimic the foreign controller
    my $relinfo = $c->stash->{form}->metadata->relationship_info($rel_name);
    $c->stash(
        controller  => $relinfo->controller,
        method_name => $rel_name,
        form        => $relinfo->controller->form($c),
        field_names => $relinfo->controller->form($c)->metadata->field_methods
    );
}

=head2 remove

Overrides superclass method to set
the content response to 'Ok' on success, 
or a generic error string on failure.

B<CAUTION>: This URI is for ManyToMany only. Using it on OneToMany
or ManyToOne I<rel_name> values will delete the related row altogether.

=cut

sub remove : PathPart Chained('related') Args(0) {
    my ( $self, $c, $rel, $foreign_pk, $foreign_pk_value ) = @_;
    eval { $self->next::method($c) };

    if ( $@ or $self->has_errors($c) ) {
        $c->clear_errors;
        $c->res->body("Error removing related object");
        $c->res->status(500);
        return;
    }
    else {
        $c->response->body('Ok');
    }
}

=head2 add

Overrides superclass method to return
the new record as JSON on success, or a generic 
error string on failure.

=cut

sub add : PathPart Chained('related') Args(0) {
    my ( $self, $c ) = @_;

    # pull the newly associated record out and json-ify it for return
    my $obj              = $c->stash->{object};
    my $rel              = $c->stash->{rel_name};
    my $foreign_pk_value = $c->stash->{foreign_pk_value};

    # check first if already defined so we don't try and re-add
    for my $rec ( @{ $obj->$rel } ) {
        my $pk = $rec->primary_key_value;
        my $pkval = join( ';;', ref $pk ? @$pk : ($pk) );
        if ( $pkval eq $foreign_pk_value ) {
            $c->res->body(
                "Related $rel record $foreign_pk_value already associated.");
            $c->res->status(400);
            return;
        }
    }

    eval { $self->next::method($c) };

    if ( $@ or $self->has_errors($c) ) {
        $c->clear_errors;
        $c->res->body("Error adding related object");
        $c->res->status(500);
        return;
    }

    my $record;
    for my $rec ( @{ $obj->$rel } ) {
        my $pk = $rec->primary_key_value;
        my $pkval = join( ';;', ref $pk ? @$pk : ($pk) );
        if ( $pkval eq $foreign_pk_value ) {
            $record = $rec;
            last;
        }
    }
    if ( !$record ) {
        $self->throw_error(
            "cannot find newly saved record for $rel $foreign_pk_value");
        return;
    }

    # we want the column names, etc., from the foreign controller's form.
    my $foreign_form = $self->form->metadata->relationship_info($rel)
        ->controller->form($c);
    $c->stash(
        template    => 'crud/jsonify.tt',
        serial_args => {
            object => $record,
            parent => $obj,
            takes_object_as_argument =>
                $foreign_form->metadata->takes_object_as_argument,
            col_names => $foreign_form->metadata->field_methods,
        }
    );
    $c->response->content_type( $self->json_mime );
    $c->response->status(200);    # because we are returning content
}

=head2 form_to_object

Overrides the base CRUD method to catch errors if the expected
return format is JSON.

=cut

# catch any errs so we can render json if needed
sub form_to_object {
    my ( $self, $c ) = @_;

    #carp "form_to_object";
    my $obj = $self->next::method($c);
    if (   !$obj
        && exists $c->req->params->{return}
        && $c->req->params->{return} eq 'json' )
    {
        $c->response->status(500);
        my $err = $self->all_form_errors( $c->stash->{form} );
        $err =~ s,\n,<br />,g;
        $c->response->body($err);
    }
    return $obj;
}

=head2 postcommit

Overrides base method to render response as JSON where necessary.
The C<return> request param is checked for the string 'json'
and the object is serialized accordingly.

=cut

sub postcommit {
    my ( $self, $c, $obj ) = @_;

    # get whatever auto-set values were set.
    unless ( $c->action->name eq 'rm' ) {
        $obj->read if $obj->can('read');
    }

    if ( exists $c->req->params->{return} ) {

        my $type = $c->req->params->{return};
        if ( $type eq 'json' ) {

            $c->log->debug("JSONifying object for response") if $c->debug;

            $c->stash( object   => $obj );               # is this necessary?
            $c->stash( template => 'crud/jsonify.tt' )
                unless defined $c->stash->{template};
            $c->response->content_type( $self->json_mime );

        }
        else {
            $self->throw_error("unknown return type: $type");
        }
    }
    else {
        $self->next::method( $c, $obj );
    }

    return $obj;
}

=head2 autocomplete_columns

Should return arrayref of fields to search when
the autocomplete() URI method is requested.

Set this value in config(). Default is a no-op.

=cut

# this is a no-op by default. subclasses can override it.
# it is marked with the _private prefix for now.
sub _get_autocomplete_columns {
    my ( $self, $c ) = @_;
    return $self->autocomplete_columns || [];
}

=head2 autocomplete_method

Which method should be called on each search result to create the 
response list.

Default is the first item in autocomplete_columns().

Set this value in config(). Default is a no-op.

=cut

sub _get_autocomplete_method {
    my ( $self, $c ) = @_;
    my $accols = $self->autocomplete_columns
        || $self->_get_autocomplete_columns;

    $self->autocomplete_method( @$accols ? $accols->[0] : undef );
    return $self->autocomplete_method;
}

=head2 autocomplete( I<context> )

Public URI method. Supports the Rose::HTMLx::Form::Field::Autocomplete
API.

=cut

sub autocomplete : Local {
    my ( $self, $c ) = @_;
    if ( !$self->can_read($c) ) {
        $self->throw_error("Permission denied");
        return;
    }
    my $p = $c->req->params;
    unless ( $p->{l} and $p->{c} and $p->{query} ) {
        $self->throw_error("need l and c and query params");
        return;
    }

    my $ac_columns = $self->autocomplete_columns
        || $self->_get_autocomplete_columns($c);
    if ( !@$ac_columns ) {
        $self->throw_error("no autocomplete columns defined");
        return;
    }

    my $ac_method = $self->autocomplete_method
        || $self->_get_autocomplete_method;
    if ( !$ac_method ) {
        $self->throw_error("no autocomplete method defined");
        return;
    }

    #warn "ac_columns: " . dump $ac_columns;
    #warn "ac_method: " . $ac_method;

    $p->{_fuzzy}     = 1;
    $p->{_page_size} = $p->{l};
    $p->{_op}        = 'OR';
    $p->{$_} = $p->{query} for @$ac_columns;
    my $query = $c->model( $self->model_name )->make_query($ac_columns);

    $c->stash->{results} = $c->model( $self->model_name )->search(
        query   => $query->{query},
        sort_by => $query->{sort_by},
        limit   => $query->{limit},
    );
    $c->stash->{ac_field}   = $p->{c};
    $c->stash->{ac_method}  = $ac_method;
    $c->stash->{ac_columns} = $ac_columns;
    $c->stash->{template}   = 'crud/autocomplete.tt';
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

