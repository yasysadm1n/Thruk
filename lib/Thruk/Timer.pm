package Thruk::Timer;

use warnings;
use strict;
use Time::HiRes qw/gettimeofday tv_interval/;
use Exporter 'import';
our @EXPORT_OK = qw(timing_breakpoint);

my $starttime = [gettimeofday];
my $lasttime  = $starttime;
sub timing_breakpoint {
    return if !$ENV{'THRUK_PERFORMANCE_DEBUG'} or $ENV{'THRUK_PERFORMANCE_DEBUG'} < 3;
    my($msg) = @_;
    my @caller = caller;
    my $tmp = [gettimeofday];
    my $elapsed;
    if($lasttime) {
        my $total = tv_interval($starttime);
        $elapsed  = tv_interval($lasttime);
        printf(STDERR "%-8s  %6ss     %6ss     %-40s %s:%d\n",
                        (threads->tid()||'global'),
                        sprintf("%.3f", $total),
                        sprintf("%.3f", $elapsed),
                        $msg,
                        $caller[1],
                        $caller[2],
        );
    }
    $lasttime = $tmp;
    return $elapsed;
}

1;
__END__

=head1 NAME

Thruk::Timer - Helper class to debug timings and performance

=head1 SYNOPSIS

  use Thruk::Timer;

  timing_breakpoint($msg);
  ...
  timing_breakpoint($next_msg);

=head1 DESCRIPTION

C<Thruk::Timer> provides a simple timing function.

=head1 METHODS

=head2 timing_breakpoint

    timing_breakpoint($msg)

sets breakpoint with message

=cut

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
