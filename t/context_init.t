use Test::Stream;
use Test::Stream::XS qw/_test_ctx_init refcount/;
use Test::Stream::Interceptor qw/dies/;

my $stack = Test::Stream::Stack->new;
my $hub   = Test::Stream::Hub->new; 
my $dbg   = Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'foo']);
my $ctx   = Test::Stream::Context->new(hub => $hub, debug => $dbg);

ok( !dies { _test_ctx_init($ctx, $hub) }, "Did not die");

my @ran;

$hub->add_context_init(sub { push @ran => 'hub' });

{
    local @Test::Stream::Context::ON_INIT = (sub { push @ran => 'global' });
    _test_ctx_init($ctx, $hub, on_init => sub { push @ran => 'ctx' });
}

is_deeply(
    \@ran,
    [qw/global hub ctx/],
    'Callbacks all ran in proper order'
);

is(refcount($ctx), 1, "1 ref to context");
is(refcount($hub), 2, "2 hub refs");
is(refcount($dbg), 2, "2 debug refs");
is(refcount($stack), 1, "1 stack ref");

done_testing;
