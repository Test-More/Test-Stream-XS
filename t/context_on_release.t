use Test::Stream;
use Test::Stream::XS qw/refcount _test_ctx_add_on_release/;
use Test::Stream::Interceptor qw/dies/;

my $stack = Test::Stream::Stack->new;
my $hub   = Test::Stream::Hub->new; 
my $dbg   = Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'foo']);
my $ctx = Test::Stream::Context->new(hub => $hub, debug => $dbg);

# Test No-Ops

ok(!dies{_test_ctx_add_on_release($ctx, 1 => 1) }, "did not die");
is(refcount($ctx), 1, "no added refs");

my $cb = sub { 1 };
my $count = refcount($cb);

_test_ctx_add_on_release($ctx, on_release => $cb);
is_deeply(
    $ctx->_on_release,
    [$cb],
    "Initialized"
);

is(refcount($ctx), 1, "no added ctx refs");
is(refcount($ctx->{_on_release}), 1, "1 ref to the new array");
is(refcount($cb), $count + 1, "1 new ref to the callback");

_test_ctx_add_on_release($ctx, on_release => $cb);
is_deeply(
    $ctx->_on_release,
    [$cb, $cb],
    "Added another one"
);
is(refcount($cb), $count + 2, "another new ref to the callback");

$ctx = undef;

is(refcount($cb), $count, "Original ref count of the callback");

done_testing;
