package Thruk;

=head1 NAME

Thruk - Mojolicious based monitoring web interface

=head1 DESCRIPTION

Mojolicious based monitoring web interface for Naemon, Nagios, Icinga and Shinken

=cut

use strict;
use warnings;

use 5.008000;
use Mojo::Base 'Mojolicious';

our $VERSION = '1.88';

###################################################
# create connection pool
# has to be done before the binmode
# or even earlier to save memory
use Thruk::Backend::Pool;
BEGIN {
    Thruk::Backend::Pool::init_backend_thread_pool();
};

###################################################
# load timing class
BEGIN {
    #use Thruk::Timer qw/timing_breakpoint/;
    #&timing_breakpoint('starting thruk');
};

###################################################
# clean up env
BEGIN {
    ## no critic
    eval "use Time::HiRes qw/gettimeofday tv_interval/;" if ($ENV{'THRUK_PERFORMANCE_DEBUG'} and $ENV{'THRUK_PERFORMANCE_DEBUG'} >= 0);
    eval "use Thruk::Template::Context;"                 if ($ENV{'THRUK_PERFORMANCE_DEBUG'} and $ENV{'THRUK_PERFORMANCE_DEBUG'} >= 3);
    ## use critic
}
use Carp qw/confess/;
use POSIX qw(tzset);
use Digest::MD5 qw(md5_hex);
use File::Slurp qw(read_file);
use Data::Dumper;
use Module::Load qw/load/;
use Thruk::Config;
use Thruk::Utils;
use Thruk::Utils::Auth;
use Thruk::Utils::External;
use Thruk::Utils::Livecache;
use Thruk::Utils::Menu;
use Thruk::Utils::Status;
use Thruk::Utils::Cache qw/cache/;
use Thruk::Stats;
use Thruk::Request;
use Thruk::Action::AddDefaults;
use Thruk::Backend::Manager;
use Thruk::Authentication::User;

use constant {
    ADD_DEFAULTS        => 0,
    ADD_SAFE_DEFAULTS   => 1,
    ADD_CACHED_DEFAULTS => 2,
};

###################################################
$Data::Dumper::Sortkeys = 1;
our $config;

###################################################

=head1 METHODS

=head2 startup

called by Mojolicious on startup

=cut
sub startup {
    my($self) = @_;

    #&timing_breakpoint('startup()');

    $self->secrets(['Thruk rocks']);
    $self->{'errors'} = [] unless defined $self->{'errors'};

    $config = Thruk::Config::get_config();
    $self->app->config($config);
    #&timing_breakpoint('startup() config loaded');

    # setup renderer
    $self->plugin('Thruk::ToolkitRenderer', {config => $config->{'View::TT'}});
    $self->plugin('Thruk::JSONRenderer', {});
    $self->plugin('Thruk::ExcelRenderer', {config => $config->{'View::Excel::Template::Plus'}});
    $self->plugin('Thruk::GDRenderer', {});
    $self->renderer->default_handler('tt');

    _init_logging($self, $config);
    _init_cache($config);
    #&timing_breakpoint('startup() cache created');

    ###################################################
    # load routes dynamically from plugins
    my $r = $self->routes;
    load 'Thruk::Controller::Root';
    Thruk::Controller::Root::add_routes($r);
    load 'Thruk::Controller::error';
    #&timing_breakpoint('startup() root routes added');

    ###################################################
    # load static routes
    $r->any('/*/cgi-bin/avail.cgi'        )->to(controller => 'Controller::avail',         action => 'index');
    $r->any('/*/cgi-bin/cmd.cgi'          )->to(controller => 'Controller::cmd',           action => 'index');
    $r->any('/*/cgi-bin/config.cgi'       )->to(controller => 'Controller::config',        action => 'index');
    $r->any('/*/cgi-bin/extinfo.cgi'      )->to(controller => 'Controller::extinfo',       action => 'index');
    $r->any('/*/cgi-bin/history.cgi'      )->to(controller => 'Controller::history',       action => 'index');
    $r->any('/*/cgi-bin/login.cgi'        )->to(controller => 'Controller::login',         action => 'index');
    $r->any('/*/cgi-bin/notifications.cgi')->to(controller => 'Controller::notifications', action => 'index');
    $r->any('/*/cgi-bin/outages.cgi'      )->to(controller => 'Controller::outages',       action => 'index');
    $r->any('/*/cgi-bin/remote.cgi'       )->to(controller => 'Controller::remote',        action => 'index');
    $r->any('/*/cgi-bin/restricted.cgi'   )->to(controller => 'Controller::restricted',    action => 'index');
    $r->any('/*/cgi-bin/showlog.cgi'      )->to(controller => 'Controller::showlog',       action => 'index');
    $r->any('/*/cgi-bin/status.cgi'       )->to(controller => 'Controller::status',        action => 'index');
    $r->any('/*/cgi-bin/summary.cgi'      )->to(controller => 'Controller::summary',       action => 'index');
    $r->any('/*/cgi-bin/tac.cgi'          )->to(controller => 'Controller::tac',           action => 'index');
    $r->any('/*/cgi-bin/trends.cgi'       )->to(controller => 'Controller::trends',        action => 'index');
    $r->any('/*/cgi-bin/test.cgi'         )->to(controller => 'Controller::test',          action => 'index');
    #&timing_breakpoint('startup() local routes added');

    ###################################################
    # load routes dynamically from plugins
    for my $plugin_dir (glob($config->{'plugin_path'}.'/plugins-enabled/*/lib/Thruk/Controller/*.pm')) {
        $plugin_dir =~ s|^.*/plugins-enabled/[^/]+/lib/(.*)\.pm||gmx;
        my $plugin = $1;
        $plugin =~ s|/|::|gmx;
        load $plugin;
        $plugin->add_routes($self, $r);
    }
    #&timing_breakpoint('startup() plugins loaded');

    ###################################################
    # create backends
    $self->app->{'db'} = Thruk::Backend::Manager->new();
    #&timing_breakpoint('startup() backends created');

    ###################################################
    # create helpers
    $self->helper('stats'   => \&Thruk::Stats::new);
    $self->helper('request' => \&Thruk::Request::new);
    $self->helper('res'     => sub { my($c) = @_; return($c->response) });
    $self->helper('cache'   => \&cache);
    $self->helper('detach'  => sub {
        if(!$_[0]->{'errored'} && $_[1] =~ m|/error/index/(\d+)$|mx) {
            return(Thruk::Controller::error::index($_[0], $1));
        }
        confess("detach: ".$_[1]." at ".$_[0]->req->url->path);
    });
    $self->helper('error'   => sub {
        #my($c, $err) = @_;
        return($self->{'errors'}) unless $_[1];
        push @{$self->{'errors'}}, $_[1];
    });
    $self->helper('clear_errors'                => sub { $self->{'errors'} = []; });
    $self->helper('db'                          => sub { $_[0]->{'db'} });
    $self->helper('user_exists'                 => sub { return(defined $_[0]->{'user'}) });
    $self->helper('user'                        => sub { return($_[0]->{'user'}); });
    $self->helper('authenticate'                => sub { $_[0]->{'user'} = Thruk::Authentication::User->new($_[0]); });
    $self->helper('check_user_roles'            => sub { return(defined $_[0]->{'user'} && $_[0]->{'user'}->check_user_roles($_[1])) });
    $self->helper('check_user_roles_wrapper'    => sub { return(defined $_[0]->{'user'} && $_[0]->{'user'}->check_user_roles($_[1])) });
    $self->helper('check_permissions'           => sub { return(defined $_[0]->{'user'} && $_[0]->{'user'}->check_permissions(@_)) });
    $self->helper('check_cmd_permissions'       => sub { return(defined $_[0]->{'user'} && $_[0]->{'user'}->check_cmd_permissions(@_)) });

    ###################################################
    # add some hooks
    $self->hook(around_action => sub {
        #my ($next, $c, $action, $last) = @_;
        my ($next, $c) = @_;
        # before
        Thruk::Request::clear();
        $c->{'errored'} = 0;
        $self->renderer->default_handler('tt');
        $Thruk::Request::c = $c;
        _before_prepare_body($c);
        Thruk::Action::AddDefaults::begin($c);
        $c->{'request'} = $c->request;
        return $next->();
    });
    $self->hook(before_render => sub {
        my($c, $args) = @_;
        if($c->{errored}) {
            $self->renderer->default_handler('ep');
            return($c);
        }
        if($args->{exception}) {
            $c->log->error("".$args->{exception});
            $c->error("".$args->{exception});
            Thruk::Controller::error::index($c, 13);
        }
        Thruk::Action::AddDefaults::end($c);
        return($c);
    });
    $self->hook(after_dispatch => \&_after_finalize );

    #&timing_breakpoint('start done');
    return;
}

###################################################

=head2 config

    make config accessible via Thruk->config

=cut
sub config {
    $config = Thruk::Config::get_config() unless defined $config;
    return($config);
}

###################################################

=head2 debug

    make debug accessible via Thruk->debug

=cut
sub debug {
    if($ENV{'THRUK_VERBOSE'} || $ENV{'MORBO_VERBOSE'}) {
        return(1);
    }
    return(0);
}

###################################################
# init cache
sub _init_cache {
    my($config) = @_;
    Thruk::Utils::IO::mkdir($config->{'tmp_path'});
    return __PACKAGE__->cache($config->{'tmp_path'}.'/thruk.cache');
}

###################################################
# save pid
# TODO: ...
#my $pidfile  = __PACKAGE__->config->{'tmp_path'}.'/thruk.pid';
#sub _remove_pid {
#    $SIG{PIPE} = 'IGNORE';
#    if(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'FastCGI') {
#        if($pidfile && -f $pidfile) {
#            my $pids = [split(/\s/mx, read_file($pidfile))];
#            my $remaining = [];
#            for my $pid (@{$pids}) {
#                next unless($pid and $pid =~ m/^\d+$/mx);
#                next if $pid == $$;
#                next if kill(0, $pid) == 0;
#                push @{$remaining}, $pid;
#            }
#            if(scalar @{$remaining} == 0) {
#                unlink($pidfile);
#                if(__PACKAGE__->config->{'use_shadow_naemon'} and __PACKAGE__->config->{'use_shadow_naemon'} ne 'start_only') {
#                    Thruk::Utils::Livecache::shutdown_shadow_naemon_procs(__PACKAGE__->config);
#                }
#            } else {
#                open(my $fh, '>', $pidfile);
#                print $fh join("\n", @{$remaining}),"\n";
#                CORE::close($fh);
#            }
#        }
#    }
#    if(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'DebugServer') {
#        # debug server has no pid file, so just kill our shadows
#        if(__PACKAGE__->config->{'use_shadow_naemon'} and __PACKAGE__->config->{'use_shadow_naemon'} ne 'start_only') {
#            Thruk::Utils::Livecache::shutdown_shadow_naemon_procs(__PACKAGE__->config);
#        }
#    }
#    return;
#}
#if(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'FastCGI') {
#    -s $pidfile || unlink(__PACKAGE__->config->{'tmp_path'}.'/thruk.cache');
#    open(my $fh, '>>', $pidfile) || warn("cannot write $pidfile: $!");
#    print $fh $$."\n";
#    Thruk::Utils::IO::close($fh, $pidfile);
#}
#$SIG{INT}  = sub { _remove_pid(); exit; };
#$SIG{TERM} = sub { _remove_pid(); exit; };
#END {
#    _remove_pid();
#};

###################################################
# create secret file
# TODO: ...
#if(!defined $ENV{'THRUK_SRC'} or $ENV{'THRUK_SRC'} ne 'SCRIPTS') {
#    my $var_path   = __PACKAGE__->config->{'var_path'} or die("no var path!");
#    my $secretfile = $var_path.'/secret.key';
#    unless(-s $secretfile) {
#        my $digest = md5_hex(rand(1000).time());
#        chomp($digest);
#        open(my $fh, ">$secretfile") or warn("cannot write to $secretfile: $!");
#        if(defined $fh) {
#            print $fh $digest;
#            Thruk::Utils::IO::close($fh, $secretfile);
#            chmod(0640, $secretfile);
#        }
#        __PACKAGE__->config->{'secret_key'} = $digest;
#    } else {
#        my $secret_key = read_file($secretfile);
#        chomp($secret_key);
#        __PACKAGE__->config->{'secret_key'} = $secret_key;
#    }
#}

###################################################
# set timezone
# TODO: ...
#my $timezone = __PACKAGE__->config->{'use_timezone'};
#if(defined $timezone) {
#    $ENV{'TZ'} = $timezone;
#    POSIX::tzset();
#}

###################################################
# set installed server side includes
# TODO: ...
#my $ssi_dir = __PACKAGE__->config->{'ssi_path'};
#my (%ssi, $dh);
#if(!-e $ssi_dir) {
#    warn("cannot access ssi_path $ssi_dir: $!");
#} else {
#    opendir( $dh, $ssi_dir) or die "can't opendir '$ssi_dir': $!";
#    for my $entry (readdir($dh)) {
#        next if $entry eq '.' or $entry eq '..';
#        next if $entry !~ /\.ssi$/mx;
#        $ssi{$entry} = { name => $entry }
#    }
#    closedir $dh;
#}
#__PACKAGE__->config->{'ssi_includes'} = \%ssi;
#__PACKAGE__->config->{'ssi_path'}     = $ssi_dir;

###################################################
# load and parse cgi.cfg into $c->config
# TODO: ...
#unless(Thruk::Utils::read_cgi_cfg(undef, __PACKAGE__->config)) {
#    die("\n\n*****\nfailed to load cgi config: ".__PACKAGE__->config->{'cgi.cfg'}."\n*****\n\n");
#}


###################################################
# Logging
sub _init_logging {
    my($self, $config) = @_;
    my $log4perl_conf;
    if(!defined $ENV{'THRUK_SRC'} or ($ENV{'THRUK_SRC'} ne 'CLI' and $ENV{'THRUK_SRC'} ne 'SCRIPTS')) {
        if(defined $config->{'log4perl_conf'} and ! -s $config->{'log4perl_conf'} ) {
            die("\n\n*****\nfailed to load log4perl config: ".$config->{'log4perl_conf'}.": ".$!."\n*****\n\n");
        }
        $log4perl_conf = $config->{'log4perl_conf'} || $config->{'home'}.'/log4perl.conf';
    }
    if(defined $log4perl_conf and -s $log4perl_conf) {
        require Log::Log4perl;
        Log::Log4perl::init($log4perl_conf);
        my $logger = Log::Log4perl::get_logger();
        $self->helper('log' => sub { return($logger) });
        $config->{'log4perl_conf_in_use'} = $log4perl_conf;
    }
    else {
        $self->helper('log' => sub { return($self->log) });
        if(!Thruk->debug) {
            $self->log->level('info');
        }
    }
    return;
}

###################################################
# SizeMe and other devel internals
if($ENV{'SIZEME'}) {
    # add signal handler to print memory information
    # ps -efl | grep perl | grep thruk_server.pl | awk '{print $4}' | xargs kill -USR1
    $SIG{'USR1'} = sub {
        printf(STDERR "mem:% 7s MB  before devel::sizeme\n", Thruk::Backend::Pool::get_memory_usage());
        eval {
            require Devel::SizeMe;
            Devel::SizeMe::perl_size();
        };
        print STDERR $@ if $@;
    }
}
if($ENV{'MALLINFO'}) {
    # add signal handler to print memory information
    # ps -efl | grep perl | grep thruk_server.pl | awk '{print $4}' | xargs kill -USR2
    $SIG{'USR2'} = sub {
        eval {
            require Devel::Mallinfo;
            require Data::Dumper;
            my $info = Devel::Mallinfo::mallinfo();
            printf STDERR "%s\n", '*******************************************';
            printf STDERR "%-30s    %5.1f %2s\n", 'arena',                              Thruk::Utils::reduce_number($info->{'arena'}, 'B');
            printf STDERR "   %-30s %5.1f %2s\n", 'bytes in use, ordinary blocks',  Thruk::Utils::reduce_number($info->{'uordblks'}, 'B');
            printf STDERR "   %-30s %5.1f %2s\n", 'bytes in use, small blocks',     Thruk::Utils::reduce_number($info->{'usmblks'}, 'B');
            printf STDERR "   %-30s %5.1f %2s\n", 'free bytes, ordinary blocks',    Thruk::Utils::reduce_number($info->{'fordblks'}, 'B');
            printf STDERR "   %-30s %5.1f %2s\n", 'free bytes, small blocks',       Thruk::Utils::reduce_number($info->{'fsmblks'}, 'B');
            printf STDERR "%-30s\n", 'total';
            printf STDERR "   %-30s %5.1f %2s\n", 'taken from the system',    Thruk::Utils::reduce_number($info->{'arena'} + $info->{'hblkhd'}, 'B');
            printf STDERR "   %-30s %5.1f %2s\n", 'in use by program',        Thruk::Utils::reduce_number($info->{'uordblks'} + $info->{'usmblks'} + $info->{'hblkhd'}, 'B');
            printf STDERR "   %-30s %5.1f %2s\n", 'free within program',      Thruk::Utils::reduce_number($info->{'fordblks'} + $info->{'fsmblks'}, 'B');
        };
        print STDERR $@ if $@;
    }
}

#sub prepare_path {
#   TODO: ...
#    # collect statistics when running external command or if enabled by env variable
#    if($ENV{'THRUK_JOB_DIR'} || ($ENV{'THRUK_PERFORMANCE_DEBUG'} && $ENV{'THRUK_PERFORMANCE_DEBUG'} >= 2)) {
#        $c->stats->enable(1);
#    }
#}

###################################################

=head2 run_after_request

run callbacks after the request had been send to the client

=cut
sub run_after_request {
    my ($c, $sub) = @_;
    $c->stash->{'run_after_request_cb'} = [] unless defined $c->stash->{'run_after_request_cb'};
    push @{$c->stash->{'run_after_request_cb'}}, $sub;
    return;
}

sub _after_finalize {
    my($c) = @_;
    $c->stats->profile(end => "finalize");
    $c->stats->profile(begin => "after finalize");

    while(my $sub = shift @{$c->stash->{'run_after_request_cb'}}) {
        ## no critic
        eval($sub);
        ## use critic
        $c->log->info($@) if $@;
    }
    $c->stats->profile(end => "after finalize");

    if($ENV{'THRUK_PERFORMANCE_DEBUG'} and $c->stash->{'memory_begin'}) {
        my $elapsed = tv_interval($c->stash->{'time_begin'});
        $c->stash->{'memory_end'} = Thruk::Backend::Pool::get_memory_usage();
        my($url) = ($c->request->uri =~ m#.*?/thruk/(.*)#mxo);
        $url     = $c->request->uri unless $url;
        $url     =~ s/^cgi\-bin\///mxo;
        if(length($url) > 60) { $url = substr($url, 0, 60).'...' }
        $c->log->info(sprintf("mem:% 7s MB  % 10.2f MB     %.2fs %8s    %s",
                                $c->stash->{'memory_end'},
                                ($c->stash->{'memory_end'}-$c->stash->{'memory_begin'}),
                                $elapsed,
                                defined $c->stash->{'total_backend_waited'} ? sprintf('(%.2fs)', $c->stash->{'total_backend_waited'}) : '',
                                $url,
                    ));
    }

    if($ENV{'THRUK_PERFORMANCE_DEBUG'} and $ENV{'THRUK_PERFORMANCE_DEBUG'} >= 2) {
        Thruk::Utils::External::log_profile($c);
    }

    if($c->res->code() == 302) {
        $c->res->body("This item has moved");
    }
    Thruk::Utils::External::save_profile($c, $ENV{'THRUK_JOB_DIR'}) if $ENV{'THRUK_JOB_DIR'};
    return;
};

###################################################

=head2 use_stats

switch for various internal catalyst sub wether to gather statistics or not

=cut
#sub use_stats {
#    my($c) = @_;
#    # save previous error, otherwise we would
#    # overwrite real error which has not yet been thrown
#    my $error = $@;
#    eval { # newer Catalyst::Middleware::Stash versions die if called to early
#        if($c->stash->{'no_more_profile'})  { return; }
#    };
#    # restore original error
#    $@ = $error;
#    if($ENV{'THRUK_PERFORMANCE_DEBUG'} and $ENV{'THRUK_PERFORMANCE_DEBUG'} > 1) { return(1); }
#    return;
#}

###################################################
# add some more profiles
sub _before_prepare_body {
    my($c) = @_;
    if($ENV{'THRUK_PERFORMANCE_DEBUG'}) {
        $c->stash->{'memory_begin'} = Thruk::Backend::Pool::get_memory_usage();
        $c->stash->{'time_begin'}   = [gettimeofday()];
    }
    $c->stats->profile(begin => "prepare_body");
    return;
};

=head1 SEE ALSO

L<Thruk::Controller::Root>, L<Mojolicious>

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
