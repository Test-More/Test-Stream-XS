use Test::Stream;

use Test::Stream::XS qw/refcount/;
use Test::Stream::Interceptor qw/dies/;
use Scalar::Util qw/weaken isweak/;

like(dies { refcount("") }, qr/Not a reference/, "Must use a ref");

is(refcount({}), 1, "1 ref");

my $x = {};
is(refcount($x), 1, "1 ref");
my $y = $x;
is(refcount($y), 2, "2 refs");
$x = undef;
is(refcount($y), 1, "1 ref again");

$x = {};
$y = $x;
weaken($y);
is(refcount($x), 1, "1 ref (and a weak one)");
ok(isweak($y),  "y is weak");
ok(!isweak($x), "x is not weak");

done_testing;
