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
        my $result    = $self->ils->cancelrequest($requestid);
        my $vars;
        my $output;
        $vars->{'messagetype'} = 'CancelRequestItemResponse';
        if ( !$result->{'success'} ) {
            $vars->{'processingerror'}        = 1;
            $vars->{'processingerrortype'}    = $result->{'messages'};
            $vars->{'processingerrorelement'} = 'UniqueRequestIdentifier';
            $output = $self->render_output( 'problem.tt', $vars );
        }
        else {
            my $elements = $self->get_user_elements($xmldoc);
            $vars->{'messages'} = $result->{'messages'};
            $vars->{'elements'} = $elements;
            $output = $self->render_output( 'response.tt', $vars );
        }
        return $output;
    }
}

1;
