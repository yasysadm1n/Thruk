package Thruk::Authentication::User;

=head1 NAME

Thruk::Authentication::User - Authenticate a remote user configured using a cgi.cfg

=head1 SYNOPSIS

use Thruk::Authentication::User

=head1 DESCRIPTION

This module allows you to authenticate the users.

=cut

use strict;
use warnings;

=head1 METHODS

=head2 new

create a new C<Thruk::Authentication::User> object.

 Thruk::Authentication::User->new();

=cut

sub new {
    my( $class) = @_;
    my $self = {};
    bless $self, $class;
    return $self;
}

=head2 authenticate

authenticate a user

 authenticate($c)

=cut

sub authenticate {
    my($self, $c) = @_;
    my $username;
    my $authenticated = 0;

    # TODO: check why thats empty
    my $env = $c->req->env;
use Data::Dumper; print STDERR Dumper("**** authenticated", $env);

    # authenticated by ssl
    if(defined $c->config->{'cgi_cfg'}->{'use_ssl_authentication'} and $c->config->{'cgi_cfg'}->{'use_ssl_authentication'} >= 1
        and defined $env->{'SSL_CLIENT_S_DN_CN'}) {
            $username = $env->{'SSL_CLIENT_S_DN_CN'};
    }
    # from cli
    elsif(defined $c->stash->{'remote_user'} and $c->stash->{'remote_user'} ne '?') {
        $username = $c->stash->{'remote_user'};
    }
    # basic authentication
    elsif(defined $env->{'REMOTE_USER'}) {
        $username = $env->{'REMOTE_USER'};
    }
    elsif(defined $ENV{'REMOTE_USER'}) {
        $username = $ENV{'REMOTE_USER'};
    }

    # default_user_name?
    elsif(defined $c->config->{'cgi_cfg'}->{'default_user_name'}) {
        $username = $c->config->{'cgi_cfg'}->{'default_user_name'};
    }

    elsif(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'CLI') {
        $username = $c->config->{'default_cli_user_name'};
    }

    if(!defined $username or $username eq '') {
        return;
    }

    # change case?
    $username = lc($username) if $c->config->{'make_auth_user_lowercase'};
    $username = uc($username) if $c->config->{'make_auth_user_uppercase'};

    # regex replace?
    if($c->config->{'make_auth_replace_regex'}) {
        $c->log->debug("authentication regex replace before: ".$username);
        ## no critic
        eval('$username =~ '.$c->config->{'make_auth_replace_regex'});
        ## use critic
        $c->log->error("authentication regex replace error: ".$@) if $@;
        $c->log->debug("authentication regex replace after : ".$username);
    }

    $self->{'username'} = $username;
    return $self;
}

1;
