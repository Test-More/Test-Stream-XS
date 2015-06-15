use Test::Stream;
use Test::Stream::XS qw/refcount top_xs peek_xs/;

my $stack = Test::Stream::Stack->new;

is(@$stack, 0, "Nothing on the stack yet");

is(peek_xs($stack), undef, "No hub on the stack");

isa_ok(top_xs($stack), 'Test::Stream::Hub');

ok(my $top = peek_xs($stack), "got top");
is(refcount($top), 2, "correct ref count");

$top = top_xs($stack);
is(refcount($top), 2, "correct ref count from top");

done_testing;
