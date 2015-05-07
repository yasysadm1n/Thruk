package Mojolicious::Plugin::Thruk::GDRenderer;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Plugin';
use Carp qw/confess/;

=head1 METHODS

=head2 register

    register this renderer

=cut
sub register {
    my($self, $app) = @_;
    $app->renderer->add_handler('gd' => sub {
        #my($renderer, $controller, $output, $options) = @_;
        my $gd_image = $_[1]->stash->{gd_image} or die('no gd_image found in stash');
        ${$_[2]}     = $gd_image->png;
        $_[1]->res->headers->content_type('image/png');
        # no automatic encoding
        delete $_[3]->{encoding};
        return $_[2];
    });

    $app->helper(
        'render_gd' => sub {
            shift->render( 'handler' => 'gd', @_ );
        }
    );

    return;
}

1;
__END__

=head1 SYNOPSIS

    # Mojolicious
    $self->plugin('GDRenderer', {});
    $self->render_gd();

=head1 DESCRIPTION

This module is a Mojolicious plugin for easy use of L<GD> data. It
adds a "gd" handler and provides a "render_gd" helper method.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Plugin>, L<GD>.

=cut
