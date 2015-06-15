use Test::Stream;
use Test::Stream::XS qw/get_todo_xs hid_xs refcount/;

use Devel::Peek;

my $hub = Test::Stream::Hub->new;

my $control_foo = $hub->set_todo('foo');
is(get_todo_xs($hub), "foo", "got the first todo");

my $control_bar = $hub->set_todo('bar');
is(get_todo_xs($hub), "bar", "got the second todo");

my $control_baz = $hub->set_todo('baz');
is(get_todo_xs($hub), "baz", "got the third todo");

$control_bar = undef;
is(get_todo_xs($hub), "baz", "got the third todo after second went away");

$control_baz = undef;
is(get_todo_xs($hub), "foo", "got the first todo since both others are gone");

$control_foo = undef;
is(get_todo_xs($hub), undef, "no more todo");

my $hid = hid_xs($hub);
is($hid, $hub->{hid}, "got hid");
is(refcount(\$hid), 2, "2 copies");
$hid = undef;
is(refcount(\$hid), 2, "1 copy");

is(hid_xs({}), undef, "no hid");

done_testing;
