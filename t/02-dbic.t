use Test::More tests => 9;

BEGIN {
    $ENV{CATALYST_DEBUG} ||= 0;
    use lib '../Rose-HTMLx-Form-Related/lib';
}

SKIP: {

    eval "use DBIx::Class";
    if ($@) {
        skip "install DBIx::Class to test MyDBIC app", 9;
    }
    eval "use DBIx::Class::RDBOHelpers";
    if ($@) {
        skip "install DBIx::Class::RDBOHelpers to test MyDBIC app", 9;
    }

    use lib 't/MyDBIC/lib';

    # require to defer till skip checks
    require Catalyst::Test;
    Catalyst::Test->import('MyDBIC');

    use HTTP::Request::Common;
    use Data::Dump qw( dump );
    use JSON::XS;

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
                { id => 1, name => "blue" }, { id => 2, name => "orange" }
            ],
            recordsReturned => 2,
            rowsPerPage     => 50,
            "sort"          => "",
            totalRecords    => 2,
        },
        "json response"
    );


}
