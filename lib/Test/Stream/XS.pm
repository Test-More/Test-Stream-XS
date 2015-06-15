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

This module exports XS variations of several key subs in the L<Test::Stream>
tools. This module provides significant performance enhancements.

=head1 SYNOPSYS

B<Just install it.> Test::Stream will automatically use Test::Stream::XS for
you if it is installed.

    use Test::Stream;

    ... XS used automatically if installed ...

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

=head2 GENERAL

=over 4

=item $count = refcount($ref)

This will get the refcount of the item the argument ref is pointing at. This
will throw an exception if the item you pass in is not a reference.

=item $frame = test_caller($level, $wrap, $fudge)

This is used internally to find the stack frame to which errors should be
reported. It will return an arrayref with the C<PACKAGE>, C<FILE>, C<LINE>,
C<SUBNAME>, and C<DEPTH>.

This is not typically useful outside of the C<context()> function. It is
provided specifically for tools that want to emulate C<context()> without
directly using it.

=item noop()

This is an empty xsub, it takes no arguments, and returns nothing. This is for
use in base classes that have empty subs that get called when subclasses do not
override them. It is suprising what kind of a speed boost this can bring.

Instead of:

    sub foo {   }

do:

    *foo = \&Test::Stream::XS::noop;

B<Note> In some cases you will need to wrap the above in C<BEGIN { ... }> for
it to work properly.

=back

=head2 Test::Stream::Context

=over 4

=item $ctx = context_xs(%PARAMS)

See L<Test::Stream::Context> for details, this xsub takes the place of the
usual C<context()> function. All arguments to the pure-perl version are also
accepted by the XS version.

=item $ctx->release_xs

See L<Test::Stream::Context> for details, this xsub takes the place of the
usual C<release()> method.

=back

=head2 Test::Stream::Hub

=over 4

=item $hid = hid_xs($hub)

Get the hid string from an instance of L<Test::Stream::Hub>. This replaces the
normal C<hid> accessor.

=item $todo = get_todo_xs($hub)

Get the TODO string from an instance of L<Test::Stream::Hub>. This replaces the
normal C<get_todo> accessor. TODO is a stack, and this method can be slow since
it also cleans up empty entries from the stack, the XS version is notably
faster.

=back

=head2 Test::Stream::Stack

=over 4

=item $hub = top_xs($stack)

Replaces the C<top> accessor in L<Test::Stream::Stack>.

=item $hub = peek_xs($stack)

Replaces the C<peek> accessor in L<Test::Stream::Stack>.

=back

=head2 Test::Stream::Util

=over 4

=item $tid = get_tid_xs()

Get the current threads id. This will check if threads are loaded, if they are
it will return the current thread id. If threads are not loaded this will
return 0.

=back

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2014 Chad Granum

Test-Stream-XS is free software; Standard perl license (GPL and Artistic).

Test-Stream-XS is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the license for more details.

=cut

