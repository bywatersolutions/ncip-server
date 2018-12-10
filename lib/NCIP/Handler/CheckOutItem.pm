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

        my $userid;
        my $itemid;
        my $date_due;

        if ( $self->{ncip_version} == 1 ) {
            $userid   = $xpc->findnodes( '//UserIdentifierValue', $root );
            $itemid   = $xpc->findnodes( '//ItemIdentifierValue', $root );
            $date_due = $xpc->findnodes( '//DesiredDateDue',      $root );
        } else { # $self->{ncip_version} == 2
            $userid   = $xpc->findnodes( '//ns:UserIdentifierValue', $root );
            $itemid   = $xpc->findnodes( '//ns:ItemIdentifierValue', $root );
            $date_due = $xpc->findnodes( '//ns:DesiredDateDue',      $root );
        }

        # checkout the item
        my $data = $self->ils->checkout( $userid, $itemid, $date_due );

        my ( $from, $to ) = $self->get_agencies($xmldoc);

        if ( $data->{success} ) {
            my $elements = $self->get_user_elements($xmldoc);
            return $self->render_output(
                'response.tt',
                {
                    message_type => 'CheckOutItemResponse',
                    from_agency  => $to,
                    to_agency    => $from,
                    barcode      => $itemid,
                    userid       => $userid,
                    elements     => $elements,
                    datedue      => $data->{date_due},
                }
            );
        }
        else {
            return $self->render_output(
                'problem.tt',
                {
                    message_type => 'CheckOutItemResponse',
                    problems     => $data->{problems},
                    from_agency  => $to,
                    to_agency    => $from,
                }
            );
        }
    }
}

1;
