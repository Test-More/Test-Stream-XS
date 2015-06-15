use Test::Stream;

use Test::Stream::XS qw/_test_run_hooks _test_run_hook refcount/;

my $ctx = {};
my @ran;

_test_run_hooks($ctx, 0, [
    sub {
        is(refcount($ctx), 2, "2 refs to the context");
        is($_[0], $ctx, "got ctx A");
        push @ran => 'a';
    },
    sub {
        is(refcount($ctx), 2, "2 refs to the context");
        is($_[0], $ctx, "got ctx B");
        push @ran => 'b';
    },
]);

is_deeply(\@ran, [qw/a b/], "Both hooks ran");

@ran = ();

_test_run_hooks($ctx, 1, [
    sub {
        is(refcount($ctx), 2, "2 refs to the context");
        is($_[0], $ctx, "got ctx A");
        push @ran => 'a';
    },
    sub {
        is(refcount($ctx), 2, "2 refs to the context");
        is($_[0], $ctx, "got ctx B");
        push @ran => 'b';
    },
]);

is_deeply(\@ran, [qw/b a/], "Both hooks ran, reversed");

@ran = ();

_test_run_hook($ctx, sub { 
    is(refcount($ctx), 2, "2 refs to the context");
    is($_[0], $ctx, "got ctx IT");
    push @ran => 'IT';
});

is_deeply(\@ran, ['IT'], "Single hook");

is(refcount($ctx), 1, "1 ref to the context remains");

done_testing;
