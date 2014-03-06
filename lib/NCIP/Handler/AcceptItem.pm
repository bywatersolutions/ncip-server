package NCIP::Handler::AcceptItem;

=head1

  NCIP::Handler::AcceptItem

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
        my $itemid =
          $xpc->findnodes( '//ns:ItemId/ItemIdentifierValue', $root );
        my ($action)  = $xpc->findnodes( '//ns:RequestedActionType', $root );
        my ($request) = $xpc->findnodes( '//ns:RequestId',           $root );
        my $requestagency = $xpc->find( 'ns:AgencyId', $request );
        my $requestid = $xpc->find( '//ns:RequestIdentifierValue', $request );

        # accept the item
        my $accepted = $self->ils->acceptitem($itemid);
        my $output;
        my $vars;
        my ( $from, $to ) = $self->get_agencies($xmldoc);

        # we switch these for the templates
        # because we are responding, to becomes from, from becomes to
        $vars->{'fromagency'} = $to;
        $vars->{'toagency'}   = $from;

        $vars->{'messagetype'} = 'AcceptItemResponse';
        $vars->{'barcode'}     = $itemid;
        if ( !$accepted->{success} ) {
            $vars->{'processingerror'}        = 1;
            $vars->{'processingerrortype'}    = $accepted->{'messages'};
            $vars->{'processingerrorelement'} = 'UniqueItemIdentifier';
            $output = $self->render_output( 'problem.tt', $vars );
        }
        else {
            my $elements = $self->get_user_elements($xmldoc);
            $vars->{'requestagency'} = $requestagency;
            $vars->{'requestid'}     = $requestid;

            $vars->{'elements'} = $elements;
            $vars->{'accept'}   = $accepted;
            $output = $self->render_output( 'response.tt', $vars );
        }
        return $output;
    }
}

1;
