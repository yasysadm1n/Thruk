package Thruk::Stats;

use warnings;
use strict;

# TODO: implement
sub profile {
}
sub enable {
}

our $instance;
sub new {
    return($instance) if $instance;
    my $self = {};
    bless($self, __PACKAGE__);
    return($self);
}

1;
__END__

=head1 NAME

Thruk::Stats - Application profiling

=head1 SYNOPSIS

  $c->stats->profile(begin => <name>);
  ...
  $c->stats->profile(end => <name>);

=head1 DESCRIPTION

C<Thruk::Stats> provides simple profiling

=head1 METHODS

=head2 new

    new()

return new stats object

=head2 profile

    profile(begin|end => $name)

sets breakpoint with message

=head2 enable

    enable()

enable profiling

=cut

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
