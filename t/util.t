use Test::Stream::XS qw/get_tid_xs noop/;
use Test::Stream;

is(get_tid_xs(), 0, "no threads, is 0");
ok(!$INC{'threads.pm'}, "no threads");
ok(!threads->can('tid'), "no normal way to get tid");

is(noop, undef, "noop does nothing");

if (eval { require threads; 1 }) {
    ok($INC{'threads.pm'}, "threads");
    is(get_tid_xs(), 0, "id is 0");

    my $t = threads->create(sub {
        my $tid = get_tid_xs();
        ok($tid, "not 0 ($tid)");
    });
    $t->join;
}

done_testing;
