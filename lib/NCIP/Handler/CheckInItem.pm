package NCIP::Handler::CheckInItem;

=head1

  NCIP::Handler::CheckInItem

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
        my $root   = $xmldoc->documentElement();
        my $xpc    = $self->xpc();
        my $itemid = $xpc->findnodes( '//ns:ItemIdentifierValue', $root );

        # checkin the item
        my $branch = undef;    # where the hell do we get this from???
        my $checkin = $self->ils->checkin( $itemid, $branch );
        my $output;
        my $vars;
        $vars->{'messagetype'} = 'CheckInItemResponse';
        $vars->{'barcode'}     = $itemid;
        my ( $from, $to ) = $self->get_agencies($xmldoc);
        $vars->{'fromagency'} = $to;
        $vars->{'toagency'}   = $from;

        if ( !$checkin->{success} ) {
            $vars->{'processingerror'}        = 1;
            $vars->{'processingerrortype'}    = $checkin->{'messages'};
            $vars->{'processingerrorelement'} = 'UniqueItemIdentifier';
            $output = $self->render_output( 'problem.tt', $vars );
        }
        else {

            $vars->{'elements'} = $self->get_user_elements($xmldoc);
            $vars->{'checkin'}  = $checkin;
            $output = $self->render_output( 'response.tt', $vars );
        }
        return $output;
    }
}

1;
