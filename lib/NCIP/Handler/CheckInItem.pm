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

        my $config = $self->{config}->{koha};

        my $itemid;
        if ( $self->{ncip_version} == 1 ) {
            $itemid = $xpc->findnodes( '//ItemIdentifierValue', $root );
        } else {
            $itemid = $xpc->findnodes( '//ns:ItemIdentifierValue', $root );
        }

        # check in the item
        my $branch = undef;    # where the hell do we get this from???
        my ( $from, $to ) = $self->get_agencies($xmldoc);

        my $checkin = $self->ils->checkin(
            {
                barcode => $itemid,
                branch  => $branch,
                config  => $config,
            }
        );

        if ( $checkin->{success} ) {
            return $self->render_output(
                'response.tt',
                {
                    message_type => 'CheckInItemResponse',
                    barcode      => $itemid,
                    from_agency  => $to,
                    to_agency    => $from,
                    elements     => $self->get_user_elements($xmldoc),
                    checkin      => $checkin,
                }
            );
        }
        else {
            return $self->render_output(
                'problem.tt',
                {
                    message_type => 'CheckInItemResponse',
                    problems     => $checkin->{problems},
                    from_agency  => $to,
                    to_agency    => $from,
                }
            );
        }
    }
}

1;
