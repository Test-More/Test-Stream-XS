use Test::Stream;
use Test::Stream::XS qw/refcount test_caller/;

is_deeply(test_caller(1, 0, 0), undef, "Nothing to test_caller");

sub do_it_a { test_caller(@_) };

my $test_caller = do_it_a(1, 0, 0); my $LINE = __LINE__;
is_deeply(
    $test_caller,
    [ __PACKAGE__, __FILE__, $LINE, 'main::do_it_a', 1 ],
    "Got test_caller",
);

$test_caller = sub { do_it_a(1, 0, 0) }->(); $LINE = __LINE__;
is_deeply(
    $test_caller,
    [ __PACKAGE__, __FILE__, $LINE, 'main::do_it_a', 2 ],
    "Got deeper test_caller",
);

$test_caller = sub { do_it_a(2, 0, 0) }->(); $LINE = __LINE__;
is_deeply(
    $test_caller,
    [ __PACKAGE__, __FILE__, $LINE, 'main::__ANON__', 2 ],
    "Got deeper test_caller + level",
);

$test_caller = sub { do_it_a(5, 0, 0) }->(); $LINE = __LINE__;
is_deeply(
    $test_caller,
    undef,
    "Bad Level",
);

$test_caller = sub { do_it_a(5, 0, 1) }->(); $LINE = __LINE__;
is_deeply(
    $test_caller,
    [ __PACKAGE__, __FILE__, $LINE, 'main::__ANON__', 2 ],
    "Level with fudge",
);

$test_caller = sub { do_it_a(1, 1, 0) }->(); $LINE = __LINE__;
is_deeply(
    $test_caller,
    [ __PACKAGE__, __FILE__, $LINE, 'main::do_it_a', 1 ],
    "Use wrap to hide some depth",
);

is(refcount($test_caller), 1, "1 ref to the test_caller");

done_testing;
