package NCIP::Handler::RequestItem;

=head1

  NCIP::Handler::RequestItem

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

        my $userid;
        my $itemid;
        my $biblionumber;
        my $branchcode;

        if ( $self->{ncip_version} == 1 ) {
            ($userid) = $xpc->findnodes( '//UserIdentifierValue', $root );
            $userid = $userid->textContent() if $userid;

            ($itemid) = $xpc->findnodes( '//ItemIdentifierValue', $root );
            $itemid = $itemid->textContent() if $itemid;

            ($biblionumber) = $xpc->findnodes( '//BibliographicRecordIdentifier', $root );
            $biblionumber = $biblionumber->textContent() if $biblionumber;
        } else {
            ($userid) = $xpc->findnodes( '//ns:UserIdentifierValue', $root );
            $userid = $userid->textContent() if $userid;

            ($itemid) = $xpc->findnodes( '//ns:ItemIdentifierValue', $root );
            $itemid = $itemid->textContent() if $itemid;

            ($biblionumber) = $xpc->findnodes( '//ns:BibliographicRecordIdentifier', $root );
            $biblionumber = $biblionumber->textContent() if $biblionumber;
        }

        my $type = 'SYSNUMBER';

        my ( $from, $to ) = $self->get_agencies($xmldoc);

        $branchcode = $to->[0]->textContent() if $to;

        my $config = $self->{config}->{koha};

        my $data =
          $self->ils->request( $userid, $itemid, $biblionumber, $type,
            $branchcode, $config );

        if ( $data->{success} ) {
            my $elements = $self->get_user_elements($xmldoc);
            return $self->render_output(
                'response.tt',
                {
                    message_type => 'RequestItemResponse',
                    from_agency  => $to,
                    to_agency    => $from,
                    barcode      => $itemid,
                    request_id   => $data->{request_id},
                    elements     => $elements,
                }
            );
        }
        else {
            return $self->render_output(
                'problem.tt',
                {
                    message_type => 'RequestItemResponse',
                    problems     => $data->{problems},
                    from_agency  => $to,
                    to_agency    => $from,
                }

            );
        }
    }
}

1;
