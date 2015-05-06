use strict;
use warnings;
use Test::More;
use Data::Dumper;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $cmds = {
  "grep -nr 'stash' lib/ plugins/plugins-available/*/" => {},
};

# find all wrong stash values
for my $cmd (keys %{$cmds}) {
  my $opt = $cmds->{$cmd};
  open(my $ph, '-|', $cmd.' 2>&1') or die('cmd '.$cmd.' failed: '.$!);
  ok($ph, 'cmd started');
  while(<$ph>) {
    my $line = $_;
    chomp($line);
    $line =~ s|//|/|gmxo;
    next if $line =~ m|:\d+:\s*\#|mxo;

    for my $forbidden (qw/action app cb controller data extends format handler json layout namespace path status template text variant/) {
        if($line =~ m|\$c\->stash->{\'?\"?$forbidden\'?\"?}|mx) {
            fail($line);
        }
    }
  }
  close($ph);
}


done_testing();
