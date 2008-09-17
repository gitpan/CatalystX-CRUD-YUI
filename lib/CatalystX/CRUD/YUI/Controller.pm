package CatalystX::CRUD::YUI::Controller;

use warnings;
use strict;
use base qw( CatalystX::CRUD::Controller );
use Carp;
use Class::C3;

#use Data::Dump qw( dump );

__PACKAGE__->mk_accessors(
    qw( autocomplete_columns autocomplete_method
        hide_pk_columns fuzzy_search default_view
        fmt_to_view_map
        )
);

__PACKAGE__->config(
    autocomplete_columns => [],
    autocomplete_method  => undef,
    hide_pk_columns      => 1,
    fuzzy_search         => 0,
    default_view         => 'YUI',
    fmt_to_view_map      => {
        'html' => 'YUI',
        'json' => 'YUI',
        'xls'  => 'Excel',
    },
);

our $VERSION = '0.005';

=head1 NAME

CatalystX::CRUD::YUI::Controller - base controller

=head1 SYNOPSIS

 package MyApp::Controller::Foo;
 use strict;
 
 # ISA order is important
 use base qw(
    CatalystX::CRUD::YUI::Controller
    CatalystX::CRUD::Controller::RHTMLO
 );
 
 __PACKAGE__->config(
    autocomplete_columns => [qw( foo bar )],
    autocomplete_method  => 'foo',
    hide_pk_columns      => 1,
    fuzzy_search         => 0,
    default_view         => 'YUI',
    fmt_to_view_map      => {
        'html' => 'YUI',
        'json' => 'YUI',
        'xls'  => 'Excel',
    },
 );
 
 1;
 

=head1 DESCRIPTION

This is a base controller class for use with CatalystX::CRUD::YUI
applications. It implements URI and internal methods that the
accompanying .tt and .js files rely upon.

=head1 CONFIGURATION

See SYNOPSIS for config options specific to this class.

=over

=item autocomplete_columns

See the autocomplete_columns() method. Value should be an array ref.

=item autocomplete_method

See the autocomplete_method() method. Value should be a method name.

=item hide_pk_columns

Used in the DataTable class. Boolean setting indicating whether the 
primary key column(s) should appear in the YUI DataTable listings
or not. Default is true.

=item fuzzy_search

If true, the C<cxc-fuzzy> param will be appended to all search queries
via the .tt files. See CatalystX::CRUD::Model::Utils for more
documentation about the C<cxc-fuzzy> param.

=item default_view

The name of the View to use if C<cxc-fmt> is not specified. This
should be the name of a View that inherits from CatalystX::CRUD::YUI::View.
The default is 'YUI'.

=item fmt_to_view_map

Hash ref of C<cxc-fmt> types to View names. Used in end() to determine
which View to set.

=back
  
=head1 METHODS

Only new or overridden method are documented here.

=cut

=head2 new

Overrides base method just to call next::method and ensures
config() gets merged correctly.

=cut

sub new {
    my ( $class, $app_class, $args ) = @_;

    my $self = $class->next::method( $app_class, $args );

    if ( $self->isa('CatalystX::CRUD::REST') ) {

        # must merge hashes manually due to inheritance bug with C::D::I
        # this only seems to happen when inheriting also from CXC::REST
        # either because the inheritance chain is too deep or something
        # else mysterious...
        $self->config(
            $self->merge_config_hashes( $self->_config, __PACKAGE__->config )
        );
        for my $key ( keys %{ $self->config } ) {
            next unless $self->can($key);
            next if defined $self->$key;
            $self->$key( $self->config->{$key} );
        }

    }
    return $self;
}

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
    for my $param_name (qw( cxc-dir _dir )) {
        if ( exists $c->req->params->{$param_name} ) {
            $c->req->params->{$param_name} =~ s/yui\-dt\-//;
            last;
        }
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
    $c->stash( view_on_single_result => 0 );
    $self->do_search( $c, @arg );
    $c->stash( template => 'crud/yui_datatable.tt' );
    $c->response->content_type( $self->json_mime );
}

=head2 yui_datatable_count( I<context>, I<arg> )

Public URI method. Like calling count() but returns JSON
in format the YUI DataTable expects.

=cut

sub yui_datatable_count : Local {
    my ( $self, $c, @arg ) = @_;
    $c->stash(
        fetch_no_results      => 1,
        view_on_single_result => 0,
    );
    $self->do_search( $c, @arg );
    $c->stash( template => 'crud/yui_datatable_count.tt' );
    $c->response->content_type( $self->json_mime );
}

=head2 yui_related_datatable( I<oid>, I<relationship_name> )

Public URI method. Returns JSON like yui_datatable but for the records
referred to by I<relationship_name>.

=cut

sub yui_related_datatable : PathPart Chained('fetch') Args(1) {
    my ( $self, $c, $rel_name ) = @_;
    $c->stash( view_on_single_result => 0 );
    $self->do_related_search( $c, $rel_name );
    $c->stash( template => 'crud/yui_datatable.tt' );
    $c->response->content_type( $self->json_mime );
}

=head2 do_related_search( I<context>, I<relationship_name> )

Sets up stash() to mimic the foreign controller 
represented by I<relationship_name>.

=cut

sub do_related_search {
    my ( $self, $c, $rel_name ) = @_;

    my $obj     = $c->stash->{object};
    my $query   = $self->do_model( $c, 'make_sql_query' );
    my $count   = $obj->has_related($rel_name);
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
        controller  => $relinfo->get_controller,
        method_name => $rel_name,
        form        => $relinfo->get_controller->form($c),
        field_names =>
            $relinfo->get_controller->form($c)->metadata->field_methods
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
        $c->log->error($@);
        $c->log->error($_) for @{ $c->error };
        $c->clear_errors;
        $c->res->body("Error removing related object");
        $c->res->status(500);
        return;
    }
    else {
        $c->response->body('Ok');
        $c->response->status(200);    # because we are returning content
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
    for my $rec ( $obj->$rel ) {
        my $pk = $rec->primary_key_uri_escaped;

        #warn "add compare: $pk <-> $foreign_pk_value";
        if ( $pk eq $foreign_pk_value ) {
            $c->res->body(
                "Related $rel record $foreign_pk_value already associated.");
            $c->res->status(400);
            return;
        }
    }

    eval { $self->next::method($c) };

    if ( $@ or $self->has_errors($c) ) {
        $c->log->error($@);
        $c->log->error($_) for @{ $c->error };
        $c->clear_errors;
        $c->res->body("Error adding related object");
        $c->res->status(500);
        return;
    }

    my $record;
    for my $rec ( $obj->$rel ) {
        my $pk = $rec->primary_key_uri_escaped;
        if ( $pk eq $foreign_pk_value ) {
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
    my $foreign_controller
        = $self->form($c)->metadata->relationship_info($rel)->get_controller;
    my $foreign_form = $foreign_controller->form($c);
    my $foreign_pk   = $foreign_controller->primary_key;

    # list of columns must include PK but that is often not in Form
    # if is an autoincrem value
    my @fields = @{ $foreign_form->metadata->field_methods };
    push( @fields, ref $foreign_pk ? @$foreign_pk : $foreign_pk );
    $c->stash(
        template    => 'crud/jsonify.tt',
        serial_args => {
            object => $record,
            parent => $obj,
            takes_object_as_argument =>
                $foreign_form->metadata->takes_object_as_argument,
            col_names => \@fields,
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

    # check for o2m via datatable-click to avoid
    # re-saving duplicates
    if ( $c->req->params->{'cxc-o2m'} ) {
        my $obj      = $c->stash->{object};
        my $match    = 0;
        my $eligible = 0;
        for my $param ( keys %{ $c->req->params } ) {
            if ( $obj->can($param) ) {
                $eligible++;
                if ( $obj->$param eq $c->req->params->{$param} ) {
                    $match++;
                    $c->log->debug( "object already has $param = "
                            . $c->req->params->{$param} )
                        if $c->debug;
                }
            }
        }
        if ( $match == $eligible ) {
            $c->response->body('Object already related');
            $c->response->status(400);
            return;
        }
    }

    my $obj = $self->next::method($c);

    if (   !$obj
        && exists $c->req->params->{'cxc-fmt'}
        && $c->req->params->{'cxc-fmt'} eq 'json' )
    {
        $c->response->status(500);
        my $err = $self->all_form_errors( $c->stash->{form} );
        $err =~ s,\n,<br />,g;
        $c->response->body($err);
    }
    return $obj;
}

=head2 postcommit

Overrides base method to re-read object from db.

=cut

sub postcommit {
    my ( $self, $c, $obj ) = @_;

    $c->log->debug("postcommit YUI") if $c->debug;

    # get whatever auto-set values were set.
    unless ( $c->action->name eq 'rm' ) {
        if ( $self->model_adapter ) {
            $self->model_adapter->read( $c, $obj );
        }
        else {
            $obj->read;
        }
    }

    $self->next::method( $c, $obj );

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
    return $self->autocomplete_columns;
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

    $p->{'cxc-fuzzy'}     = 1;
    $p->{'cxc-page_size'} = $p->{l};
    $p->{'cxc-op'}        = 'OR';
    $p->{'cxc-fmt'}       = 'json';
    $p->{$_} = $p->{query} for @$ac_columns;
    my $query = $self->do_model( $c, 'make_query', $ac_columns );

    $c->stash->{results}    = $self->do_model( $c, 'search', $query );
    $c->stash->{ac_field}   = $p->{c};
    $c->stash->{ac_method}  = $ac_method;
    $c->stash->{ac_columns} = $ac_columns;
    $c->stash->{template}   = 'crud/autocomplete.tt';
}

=head2 end

Uses the RenderView ActionClass.

Prior to passing to view, sets C<current_view> based
on the C<cxc-fmt> request parameter, defaulting
to 'YUI'.

B<NOTE:>This assumes you have a View class called
C<YUI> that inherits from CatalystX::CRUD::YUI::View.

=cut

sub end : ActionClass('RenderView') {
    my ( $self, $c, @arg ) = @_;
    my $fmt = $c->req->params->{'cxc-fmt'} || 'html';

    if ($fmt) {
        $c->log->debug("fmt = $fmt") if $c->debug;
        my $view_class = $self->fmt_to_view_map->{$fmt}
            || $self->default_view;
        $c->stash->{current_view} ||= $view_class;

        # special case for add() and save()
        if ( $fmt eq 'json' and defined $c->stash->{object} ) {

            # catch errors and abort so we don't return json
            if ( $self->has_errors($c) ) {
                my @err = @{ $c->error };
                $c->log->error($_) for @err;
                $c->clear_errors;
                $c->response->body('Server error');
                $c->response->status(500);
                return;
            }

            $c->log->debug("JSONifying object for response") if $c->debug;
            $c->stash( template => 'crud/jsonify.tt' )
                unless defined $c->stash->{template};
            $c->stash(
                serial_args => {
                    object => $c->stash->{object},
                    takes_object_as_argument =>
                        $self->form($c)->metadata->takes_object_as_argument,
                    col_names => $self->form($c)->metadata->field_methods,
                }
            );

            unless ( defined $c->res->status and $c->res->status =~ m/^[45]/ )
            {
                $c->res->content_type( $self->json_mime );

                # in case postcommit() set these
                $c->res->location('');
                $c->res->status(200);
            }
        }

        $c->log->debug("view set to $view_class") if $c->debug;
    }
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


This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

