package Mojolicious::Plugin::Thruk::ExcelRenderer;

use strict;
use warnings;
use Mojo::Base 'Mojolicious::Plugin';
use Carp qw/confess/;

=head1 METHODS

=head2 register

    register this renderer

=cut
sub register {
    my ($self, $app) = @_;

    $app->renderer->add_handler('excel' => sub {
        #my($renderer, $controller, $output, $options) = @_;

        require IO::String;
        require Excel::Template;
        my $worksheets = Mojolicious::Plugin::Thruk::ToolkitRenderer::render_tt(@_);
        my $fh = IO::String->new($worksheets);
        $fh->pos(0);

        my $excel_template = eval { Excel::Template->new(file => $fh) };
        if($@) {
            warn $$worksheets;
            confess $@;
        }
        ${$_[2]} = "".$excel_template->output;

        # no automatic encoding
        delete $_[3]->{encoding};

        $_[1]->res->headers->content_type('application/x-msexcel');
        return $_[2];
    });

    $app->helper(
        'render_excel' => sub {
            shift->render( 'handler' => 'excel', @_ );
        }
    );

    return;
}

1;
__END__

=head1 SYNOPSIS

    # Mojolicious
    $self->plugin('ExcelRenderer', {}, );
    $self->render_excel();

=head1 DESCRIPTION

This module is a Mojolicious plugin for easy use of L<use Excel::Template::Plus;> data. It
adds a "excel" handler and provides a "render_excel" helper method.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Plugin>, L<JSON::XS>.

=cut
