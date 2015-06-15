use Test::Stream::XS qw/release_xs refcount/;
use Test::Stream;
use Scalar::Util qw/weaken/;

our $CHECK = 0;

{
    package CHECK;

    sub DESTROY { $main::CHECK++ }
}

my @ran;

my $ctx = bless {
    hub => {
        hid => 'xxx',
        _context_release => [
            sub { push @ran => 'hub a' },
            sub { push @ran => 'hub b' },
        ],
    },
    _on_release => [
        sub { push @ran => 'ctx a' },
        sub { push @ran => 'ctx b' },
    ],
}, "CHECK";

{
    no warnings 'once';
    weaken($Test::Stream::Context::CONTEXTS{xxx} = $ctx);
}

my (@counts, @CHECKS);
my ($copy);
{
    local @Test::Stream::Context::ON_RELEASE = (
        sub { push @ran => 'global a' },
        sub { push @ran => 'global b' },
    );

    my $copy = $ctx;
    push @counts => refcount($ctx);

    release_xs($copy);
    push @counts => refcount($ctx);

    push @CHECKS => $CHECK || undef;
    release_xs($ctx);
    push @CHECKS => $CHECK || undef;
}

is($counts[0], 2, "2 refs");
is($copy, undef, "undefed copy");
is($counts[1], 1, "only original remains");
ok(!$CHECKS[0], "Nothing destroyed yet");
is($ctx, undef, "undefed ctx");
is($CHECKS[1], 1, "destroyed");
is_deeply(
    \@ran,
    [
        'ctx b',
        'ctx a',

        'hub b',
        'hub a',

        'global b',
        'global a',
    ],
    "Callbacks ran in the correct order"
);

done_testing;
