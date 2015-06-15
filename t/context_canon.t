use Test::Stream;
use Test::Stream::XS qw/refcount _test_ctx_clear_canon _test_ctx_set_canon _test_ctx_is_canon _test_ctx_get_canon/;

my %CONTEXTS;

my $stack = Test::Stream::Stack->new;
my $hub   = Test::Stream::Hub->new; 
my $dbg   = Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'foo']);
my $ctx   = Test::Stream::Context->new(hub => $hub, debug => $dbg);

{
    no warnings 'once';
    local *Test::Stream::Context::CONTEXTS = \%CONTEXTS;

    ok(!_test_ctx_is_canon($hub->hid, $ctx), "not canon");
    _test_ctx_set_canon($hub->hid, $ctx);
    ok(_test_ctx_is_canon($hub->hid, $ctx), "now canon");
    is(refcount($ctx), 1, "Did not add a ref");

    delete $CONTEXTS{$hub->hid};
    ok(!_test_ctx_is_canon($hub->hid, $ctx), "not canon anymore");
    is(refcount($ctx), 1, "Did not add a ref");

    _test_ctx_set_canon($hub->hid, $ctx);
    ok(_test_ctx_is_canon($hub->hid, $ctx), "now canon");
    is(refcount($ctx), 1, "Did not add a ref");
    $ctx->release;
    is($CONTEXTS{$hub->hid}, undef, "was weak, now undef");

    $ctx = Test::Stream::Context->new(hub => $hub, debug => $dbg);
    _test_ctx_set_canon($hub->hid, $ctx);
    ok(_test_ctx_is_canon($hub->hid, $ctx), "now canon");
    is(refcount($ctx), 1, "Did not add a ref");
    my $canon = _test_ctx_get_canon($hub->hid);
    ok($canon, "got one");
    is($ctx, $canon, "got the same ref!");
    is(refcount($ctx), 2, "The one we got is not weak");
    $canon = undef;
    is(refcount($ctx), 1, "1 ref left");

    _test_ctx_clear_canon($hub->hid);
    ok(!_test_ctx_is_canon($hub->hid, $ctx), "not canon anymore");
    is(refcount($ctx), 1, "Did not add a ref");
}

$ctx = undef;

done_testing;
