package Test::Stream::XS;
use strict;
use warnings;
use 5.008;

our $VERSION = '1.302004';

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

use Test::Stream::Exporter;
exports(
    # Utiliy
    qw/refcount test_caller noop/,

    # Test::Stream
#    qw/ts_ok_xs/,

    # Test::Builder
#    qw/tb_ok_xs/,

    # Test::Stream::TAP
#    qw/write_xs/,

    # Test::Stream::Context
    qw/release_xs context_xs/, # ok_xs/,

    # Test::Stream::Hub
    qw/get_todo_xs hid_xs/, # process_xs send_xs/,

    # Test::Stream::Stack
    qw/top_xs peek_xs/,

    # Test::Stream::Util
    qw/get_tid_xs/,

    # For testing only
    qw{
        _test_run_hooks     _test_run_hook
        _test_get_stack     _test_get_hub
        _test_get_level     _test_get_wrap        _test_get_fudge
        _test_get_on_init   _test_get_on_release
        _test_new_debuginfo _test_new_context

        _test_ctx_add_on_release
        _test_ctx_clear_canon _test_ctx_set_canon
        _test_ctx_is_canon    _test_ctx_get_canon
        _test_ctx_init
    },
);
no Test::Stream::Exporter;

1;

__END__

=pod

=head1 NAME

Test::Stream::XS - XS Enhancement library for L<Test::Stream>

=head1 DESCRIPTION

TODO

=head1 CONVENTIONS

=over 4

=item name_xs(...)

If an xsub has an _xs postfix then it is intended to be called from perl, and
re-implements a pure-perl sub of the same name.

=item name(...)

If an xsub has no prefix or postfix then it is completely new functionality.
These are intended for use in perl code.

=item _test_name(...)

If an xsub has the C<_test_> prefix then it is not intended for use outside
this module, it is intended only for testing purposes. It generally means it is
an xsub interface to a C function used by other xsubs. The point of these is to
test the C code directly.

=back

=head1 EXPORTS

TODO

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2014 Chad Granum

Test-Stream-XS is free software; Standard perl license (GPL and Artistic).

Test-Stream-XS is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the license for more details.

=cut

