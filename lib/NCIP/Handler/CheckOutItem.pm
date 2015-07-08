package NCIP::Handler::CheckOutItem;

=head1

  NCIP::Handler::CheckOutItem

=head1 SYNOPSIS

    Not to be called directly, NCIP::Handler will pick the appropriate Handler 
    object, given a message type

=head1 FUNCTIONS

=cut

use Modern::Perl;

use NCIP::Handler;

our @ISA = qw(NCIP::Handler);

sub handle {
    my $self   = shift;
    my $xmldoc = shift;
    if ($xmldoc) {
        my $root = $xmldoc->documentElement();
        my $xpc  = $self->xpc();

        my $userid = $xpc->findnodes( '//ns:UserIdentifierValue', $root );
        my $itemid = $xpc->findnodes( '//ns:ItemIdentifierValue', $root );

        # checkout the item
        my ( $error, $messages, $datedue ) =
          $self->ils->checkout( $userid, $itemid );
        my $vars;
        my $output;
        my ( $from, $to ) = $self->get_agencies($xmldoc);
        $vars->{'fromagency'} = $to;
        $vars->{'toagency'}   = $from;

        $vars->{'barcode'}     = $itemid;
        $vars->{'messagetype'} = 'CheckOutItemResponse';
        $vars->{'userid'}      = $userid;
        if ($error) {
            $vars->{'processingerror'}        = 1;
            $vars->{'processingerrortype'}    = $messages;
            $vars->{'processingerrorelement'} = 'UniqueItemIdentifier';
            $output = $self->render_output( 'problem.tt', $vars );
        }
        else {
            my $elements = $self->get_user_elements($xmldoc);
            $vars->{'elements'} = $elements;
            $vars->{'datedue'}  = $datedue;
            $output = $self->render_output( 'response.tt', $vars );
        }
        return $output;
    }
}

1;
