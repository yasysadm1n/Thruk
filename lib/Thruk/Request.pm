package Thruk::Request;

use warnings;
use strict;
use Thruk::Request::Cookie;

=head1 NAME

Thruk::Request - Wrapper for some common request methods

=head1 SYNOPSIS

  use Thruk::Request;

=head1 DESCRIPTION

C<Thruk::Request> Request wrapper

=head1 METHODS

=head2 new

    new()

return new request object

=cut
our $instance;
sub new {
    return($instance) if $instance;
    my $self = {
        parameters => $Thruk::Request::c->req->params->to_hash,
    };
    bless($self, __PACKAGE__);
    $instance = $self;
    return($self);
}

=head2 clear

clear current request object

=cut
sub clear {
    our $instance = undef;
    return;
}

=head2 cookie

return cookies for this request

=cut
sub cookie {
    my $value = $Thruk::Request::c->cookie($_[0]);
    return unless defined $value;
    my $cookie = Thruk::Request::Cookie->new($value);
    return($cookie);
}

=head2 method

return request method

=cut
sub method {
    return($Thruk::Request::c->req->method);
}

=head2 address

return request address

=cut
sub address {
    return($Thruk::Request::c->tx->remote_address);
}

=head2 action

return action of this request uri

=cut
sub action {
    return($Thruk::Request::c->req->url->path);
}

=head2 path

return path of this request uri

=cut
sub path {
    return($Thruk::Request::c->req->url->path);
}

=head2 uri

return request uri

=cut
sub uri {
    return($Thruk::Request::c->req->url->path);
}

=head2 parameters

return request parameters

=cut
sub parameters {
    my($self) = @_;
    return($self->{'parameters'});
}

=head2 query_keywords

return request query_keywords

=cut
sub query_keywords {
    # TODO: deprecate
    require URI;
    my $uri = URI->new($Thruk::Request::c->req->url);
    return($uri->query_keywords);
}

1;
__END__

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
