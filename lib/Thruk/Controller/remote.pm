package Thruk::Controller::remote;

use strict;
use warnings;
use Module::Load qw/load/;
use Mojo::Base 'Mojolicious::Controller';

=head1 NAME

Thruk::Controller::remote - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

##########################################################
sub index {
    my ( $c ) = @_;

    if(!$c->config->{'remote_modules_loaded'}) {
        load Data::Dumper;
        load Thruk::Utils::CLI;
        load File::Slurp, qw/read_file/;
        $c->config->{'remote_modules_loaded'} = 1;
    }
    Thruk::Utils::check_pid_file($c);

    $c->stash->{'_text'} = 'OK';
    if(defined $c->{'request'}->{'parameters'}->{'data'}) {
        $c->stash->{'_text'} = Thruk::Utils::CLI::_from_fcgi($c, $c->{'request'}->{'parameters'}->{'data'});
    }
    $c->stash->{'_template'} = 'passthrough.tt';

    my $action = $c->{'request'}->query || '';

    # startup request?
    if($action eq 'startup') {
        if(!$c->config->{'started'}) {
            $c->config->{'started'} = 1;
            $c->log->info("started ($$)");
            $c->stash->{'_text'} = 'startup done';
            if(defined $c->{'request'}->{'headers'}->{'user-agent'} and $c->{'request'}->{'headers'}->{'user-agent'} =~ m/wget/mix) {
                # compile templates in background
                $c->run_after_request('Thruk::Utils::precompile_templates($c)');
            }
        }
        return;
    }

    # compile request?
    if($action eq 'compile' or exists $c->{'request'}->{'parameters'}->{'compile'}) {
        if($c->config->{'precompile_templates'} == 2) {
            $c->stash->{'_text'} = 'already compiled';
        } else {
            $c->stash->{'_text'} = Thruk::Utils::precompile_templates($c);
            $c->log->info($c->stash->{'_text'});
        }
        return;
    }

    # log requests?
    if($action eq 'log' and $c->{'request'}->{'method'} eq 'POST') {
        my $body = $c->{'request'}->body();
        if($body) {
            if(ref $body eq 'File::Temp') {
                my $file = $body->filename();
                if($file and -e $file) {
                    my $msg = read_file($file);
                    unlink($file);
                    $c->log->error($msg);
                    return;
                }
            }
        }
        $c->log->error('log request without a file: '.Dumper($c->{'request'}));
        return;
    }

    return;
}

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
