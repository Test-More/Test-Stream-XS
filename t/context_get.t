use Test::Stream;
use Test::Stream::XS qw{
    refcount context_xs
    _test_ctx_clear_canon _test_ctx_set_canon _test_ctx_is_canon _test_ctx_get_canon
};
use Test::Stream::Interceptor qw/dies warns/;

my %CONTEXTS;

my $stack = Test::Stream::Stack->new;
my $hub   = Test::Stream::Hub->new;
my $dbg   = Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'foo']);

my ($ctx, $got, @refs, @err);
{
    no warnings 'once';
    local *Test::Stream::Context::CONTEXTS = \%CONTEXTS;

    my $ctx = Test::Stream::Context->new(hub => $hub, debug => $dbg);
    _test_ctx_set_canon($hub->hid, $ctx);

    my $got = sub { context_xs(hub => $hub) }->();

    push @refs => refcount($ctx);

    push @err => dies { context_xs(hub => $hub) };

    $ctx->set__depth(100);
    push @err => @{warns(sub { my $x = context_xs(hub => $hub) })};
    $ctx->set__depth(0);
}
is($got, $ctx, "Got the canonical one");
is($refs[0], 2, "2 copies");
like(
    $err[0],
    qr/context\(\) called, but return value is ignored/,
    "Ignored return"
);
like(
    $err[1],
    qr/was called to retrieve an existing context/,
    "Depth error"
);

%CONTEXTS = ();

my ($got2, @ran);
{
    no warnings 'once';
    local *Test::Stream::Context::CONTEXTS = \%CONTEXTS;
    local $Test::Stream::Context::STACK    = $stack;

    $got  = sub {       context_xs(on_init => sub { push @ran => 'a' }) }->();
    $got2 = sub { sub { context_xs(on_init => sub { push @ran => 'b' }) }->() }->();
}

ok($got, "got the context");
is($got, $got2, "was canonical");
is($got->hub, $stack->top, "got the hub");
is($got->stack, $stack, "got the stack");
is(refcount($got), 2, "2 refs");
is_deeply(
    \@ran,
    ['a'],
    "Only ran on_init the first time",
);

done_testing;
