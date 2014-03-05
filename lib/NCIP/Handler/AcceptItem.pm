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
        my $xpc  = XML::LibXML::XPathContext->new;
        $xpc->registerNs( 'ns', $self->namespace() );
        my $itemid = $xpc->findnodes( '//ns:ItemId', $root );

        # checkin the item
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
            $vars->{'elements'} = $elements;
            $vars->{'accept'}   = $accepted;
            $output = $self->render_output( 'response.tt', $vars );
        }
        return $output;
    }
}

1;
