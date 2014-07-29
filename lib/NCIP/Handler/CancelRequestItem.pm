package NCIP::Handler::CancelRequestItem;

=head1

  NCIP::Handler::CancelRequestItem

=head1 SYNOPSIS

    Not to be called directly, NCIP::Handler will pick the appropriate Handler 
    object, given a message type

=head1 FUNCTIONS

=cut

use Modern::Perl;

use NCIP::Handler;
use NCIP::User;

our @ISA = qw(NCIP::Handler);

sub handle {
    my $self   = shift;
    my $xmldoc = shift;
    if ($xmldoc) {
        my $root      = $xmldoc->documentElement();
        my $xpc       = $self->xpc();
        my $userid    = $xpc->findnodes( '//ns:UserIdentifierValue', $root );
        my $requestid = $xpc->findnodes( '//ns:RequestIdentifierValue', $root );
        my ( $error, $messages ) = $self->ils->cancelrequest($requestid);
        if ($error) {
            $vars->{'processingerror'}        = 1;
            $vars->{'processingerrortype'}    = $messages;
            $vars->{'processingerrorelement'} = 'UniqueRequestIdentifier';
            $output = $self->render_output( 'problem.tt', $vars );
        }
        else {
            my $elements = $self->get_user_elements($xmldoc);
            $vars->{'elements'} = $elements;
            $output = $self->render_output( 'response.tt', $vars );
        }
        return $output;
    }
}

1;
