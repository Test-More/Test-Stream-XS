use Test::Stream;
use Test::Stream::XS qw/refcount _test_new_context/;

my $stack = Test::Stream::Stack->new;
my $hub   = $stack->top;
my $dbg   = Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'foo']);

is(refcount($dbg),   1, "1 ref to debug");
is(refcount($stack), 1, "1 ref to stack");
is(refcount($hub),   2, "2 ref to hub");

$@ = "fake exception";
ok(my $ctx = _test_new_context($stack, $hub, $dbg, 2), "Created");
$@ = undef;

isa_ok($ctx, 'Test::Stream::Context');

is(refcount($ctx), 1, "1 ref to context");
is(refcount($stack), 2, "2 refs to the stack");
is(refcount($hub), 3, "3 refs to hub");
is(refcount($dbg), 2, "2 refs to debug");

is($ctx->_err, "fake exception", "Got the exception");
is($ctx->_depth, 2, "got the depth");
is($ctx->{_xs}, 1, "created via XS");

done_testing;
