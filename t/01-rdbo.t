use Test::More tests => 13;

BEGIN {
    $ENV{CATALYST_DEBUG} ||= 0;
    use lib '../Rose-HTMLx-Form-Related/lib';
}

SKIP: {

    eval "use Rose::DB::Object";
    if ($@) {
        skip "install Rose::DB::Object to test MyRDBO app", 13;
    }
    eval "use Rose::DBx::Object::MoreHelpers";
    if ($@) {
        skip "Rose::DBx::Object::MoreHelpers required to test MyRDBO app", 13;
    }
    eval "use CatalystX::CRUD::Model::RDBO";
    if ($@ or $CatalystX::CRUD::Model::RDBO::VERSION < 0.14) {
        skip "CatalystX::CRUD::Model::RDBO 0.14 required to test MyRDBO app",
            13;
    }

    use lib 't/MyRDBO/lib';

    # require to defer till skip checks
    require Catalyst::Test;
    Catalyst::Test->import('MyRDBO');

    use HTTP::Request::Common;
    use Data::Dump qw( dump );
    use JSON::XS;
    
    #dump MyRDBO::Controller::CRUD::Test::Foo->config;

    ok( get('/crud/test/foo'), "get /crud/test/foo" );

    ok( my $res = request('/crud/test/foo'), "response for /crud/test/foo" );

    #dump $res;

    is( $res->headers->{status}, '302', "redirect" );
    like( $res->headers->{location},
        qr{/crud/test/foo/count}, "redirect to count" );

    ok( $res = request('/crud/test/foo/1/view'), "view foo 1" );

    like(
        $res->content,
        qr/1972-03-29 06:30:00/,
        "view foo 1 contains correct ctime"
    );

    ok( $res = request('/crud/test/foo/1/yui_related_datatable/foogoos'),
        "related table" );

    #dump $res;

    ok( my $json = decode_json( $res->content ), "decode JSON" );

    #dump $json;

    is_deeply(
        $json,
        {   dir      => "",
            offset   => "",
            page     => 1,
            pageSize => 50,
            records  => [
                { id => 2, name => "orange" }, { id => 1, name => "blue" }
            ],
            recordsReturned => 2,
            rowsPerPage     => 50,
            "sort"          => "",
            totalRecords    => 2,
        },
        "json response"
    );

    ok( my $chain_rest_test = request('/crud/test/foorest/1/chain_test'),
        "chain_rest_test" );
    is( $chain_rest_test->headers->{status}, 200, "chain test" );

    #dump $chain_rest_test;

    ok( my $create_form_test = request('/crud/test/foo/create'),
        "create action" );
    is( $create_form_test->headers->{status}, 200, "create action works" );

    #dump $create_form_test;

}
