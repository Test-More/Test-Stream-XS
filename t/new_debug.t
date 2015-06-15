use Test::Stream;
use Test::Stream::XS qw/_test_new_debuginfo refcount/;

my $hub = Test::Stream::Hub->new;

my $frame = [__PACKAGE__, __FILE__, __LINE__, 'xxx'];
my $dbg = _test_new_debuginfo($hub, $frame);
ok($dbg, "got dbg");
isa_ok($dbg, 'Test::Stream::DebugInfo');
is(refcount($dbg), 1, "Only 1 ref to the debug object");

is($dbg->frame, $frame, "Same Frame");
is(refcount($dbg->frame), 2, "2 refs to the frame");
is($dbg->pid, $$, "Correct pid");
is($dbg->tid, 0, "Correct tid");
is($dbg->todo, undef, "Not todo");
ok(!$dbg->parent_todo, "No parent todo");

my $todo = $hub->set_todo("foo");
$hub->set_parent_todo(1);
$dbg = _test_new_debuginfo($hub, $frame);
is(refcount($dbg), 1, "Only 1 ref to the debug object");

is($dbg->frame, $frame, "Same Frame");
is(refcount($dbg->frame), 2, "2 refs to the frame");
is($dbg->pid, $$, "Correct pid");
is($dbg->tid, 0, "Correct tid");
is($dbg->todo, "foo", "is todo");
ok($dbg->parent_todo, "parent todo");

if (eval { require threads; 1}) {
    my $tid = threads->tid;
    threads->create(sub {
        my $dbg = _test_new_debuginfo($hub, $frame);
        ok($dbg->tid != $tid, "Different thread id");
    })->join;
}

done_testing;
