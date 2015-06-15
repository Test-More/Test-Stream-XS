use Test::Stream;
use Test::Stream::XS qw{
    refcount _test_get_level _test_get_wrap _test_get_fudge _test_get_on_init
    _test_get_on_release _test_get_stack _test_get_hub
};

is(_test_get_level(), 0, "Level with no params is 0");
is(_test_get_level(level => 5), 5, "Set level");

is(_test_get_fudge(), 0, "Fudge with no params is 0");
is(_test_get_fudge(fudge => 5), 5, "Set fudge");

is(_test_get_wrap(), 0, "Wrap with no params is 0");
is(_test_get_wrap(wrapped => 5), 5, "Set wrap");

is(_test_get_on_init(),    undef, "on_init    is undef when not specified");
is(_test_get_on_release(), undef, "on_release is undef when not specified");

sub a { 1 }

is(_test_get_on_init(on_init => \&a), \&a, "got the callback");
is(_test_get_on_release(on_release => \&a), \&a, "got the callback");

my $stack = Test::Stream::Stack->new;
my $got = _test_get_stack(stack => $stack);
is($stack, $got, "Got the stack from params");
is(refcount($stack), 2, "Correct ref count");
$got = undef;
is(refcount($stack), 1, "Correct ref count");

{
    no warnings 'once';
    local $Test::Stream::Context::STACK = $stack;
    $got = _test_get_stack();
}
is($stack, $got, "Got the stack from package var");
is(refcount($stack), 2, "Correct ref count");
$got = undef;
is(refcount($stack), 1, "Correct ref count");

{
    no warnings 'once';
    local $Test::Stream::Context::STACK = undef;
    $got = _test_get_stack();
}
is($got, undef, "Could not get the stack");

is(@$stack, 0, "Nothing on the stack yet");

done_testing;
