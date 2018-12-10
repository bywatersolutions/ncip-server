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

        my $config = $self->{config}->{koha};

        my ( $itemid, $action, $request, $request_agency, $request_id,
            $user_id, $item_info );

        my ( $bibliographic, $author, $date, $publisher, $medium );
        my $itemdata = {};

        if ( $self->{ncip_version} == 1 ) {
            $itemid = $xpc->find( '//ItemIdentifierValue', $root );
            $itemid = $xpc->find( '//RequestIdentifierValue', $root ) if $config->{request_identifier_value_as_barcode};

            ($action) = $xpc->find( '//RequestedActionType//Value', $root );
            $request_agency =
              $xpc->find( '//FromAgencyId/UniqueAgencyId/Value', $root );
            $request_id = $xpc->find( '//RequestIdentifierValue', $root );
            $user_id    = $xpc->find( '//UserIdentifierValue',    $root );

            $item_info = $xpc->find( '//ItemOptionalFields', $root );

            if ( $item_info->[0] ) {
                my $bibliographic =
                  $xpc->find( '//BibliographicDescription', $item_info->[0] );
                my $title = $xpc->find( '//Title', $bibliographic->[0] );
                if ( $title->[0] ) {
                    $itemdata->{title} = $title->[0]->textContent();
                }
                my $author = $xpc->find( '//Author', $bibliographic->[0] );
                if ( $author->[0] ) {
                    $itemdata->{author} = $author->[0]->textContent();
                }
                my $date =
                  $xpc->find( '//PublicationDate', $bibliographic->[0] );
                if ( $date->[0] ) {
                    $itemdata->{publicationdate} = $date->[0]->textContent();
                }
                my $publisher =
                  $xpc->find( '//Publisher', $bibliographic->[0] );
                if ( $publisher->[0] ) {
                    $itemdata->{publisher} = $publisher->[0]->textContent();
                }
                my $medium = $xpc->find( '//Mediumtype', $bibliographic->[0] );
                if ( $medium->[0] ) {
                    $itemdata->{mediumtype} = $medium->[0]->textContent();
                }
                my $format = $xpc->find( '//Format', $bibliographic->[0] );
                if ( $format->[0] ) {
                    my $f = $format->[0]->textContent();
                    my $itemtype = $config->{itemtype_map}->{$f};
                    $itemdata->{itemtype} = $itemtype if $itemtype;
                }

                my $item_description =
                  $xpc->find( '//ItemDescription', $item_info->[0] );
                if ($item_description) {
                    my $itemcallnumber = $xpc->find( '//CallNumber', $item_description->[0] );
                    if ( $itemcallnumber->[0] ) {
                        $itemdata->{itemcallnumber} = $itemcallnumber->[0]->textContent();
                    }
                }
            }

            # accept the item
        }
        else {    # $version == 2
            $itemid = $xpc->find( '//ns:ItemIdentifierValue', $root );
            $itemid = $xpc->find( '//ns:RequestIdentifierValue', $root ) if $config->{request_identifier_value_as_barcode};

            ($action)  = $xpc->findnodes( '//ns:RequestedActionType', $root );
            ($request) = $xpc->findnodes( '//ns:RequestId',           $root );
            $request_agency = $xpc->find( 'ns:AgencyId', $request );
            $request_id = $xpc->find( '//ns:RequestIdentifierValue', $request );
            $user_id    = $xpc->find( '//ns:UserIdentifierValue',    $root );

            if ($action) {
                $action = $action->textContent();
            }

            $item_info = $xpc->find( '//ns:ItemOptionalFields', $root );

            if ( $item_info->[0] ) {
                my $bibliographic =
                  $xpc->find( '//ns:BibliographicDescription', $item_info->[0] );
                my $title = $xpc->find( '//ns:Title', $bibliographic->[0] );
                if ( $title->[0] ) {
                    $itemdata->{title} = $title->[0]->textContent();
                }
                my $author = $xpc->find( '//ns:Author', $bibliographic->[0] );
                if ( $author->[0] ) {
                    $itemdata->{author} = $author->[0]->textContent();
                }
                my $date =
                  $xpc->find( '//ns:PublicationDate', $bibliographic->[0] );
                if ( $date->[0] ) {
                    $itemdata->{publicationdate} = $date->[0]->textContent();
                }
                my $publisher =
                  $xpc->find( '//ns:Publisher', $bibliographic->[0] );
                if ( $publisher->[0] ) {
                    $itemdata->{publisher} = $publisher->[0]->textContent();
                }
                my $medium = $xpc->find( '//ns:Mediumtype', $bibliographic->[0] );
                if ( $medium->[0] ) {
                    $itemdata->{mediumtype} = $medium->[0]->textContent();
                }
                my $format = $xpc->find( '//ns:Format', $bibliographic->[0] );
                if ( $format->[0] ) {
                    my $f = $format->[0]->textContent();
                    my $itemtype = $config->{itemtype_map}->{$f};
                    $itemdata->{itemtype} = $itemtype if $itemtype;
                }

                my $item_description =
                  $xpc->find( '//ns:ItemDescription', $item_info->[0] );
                if ( $item_description ) {
                    my $itemcallnumber = $xpc->find( '//ns:CallNumber', $item_description->[0] );
                    if ( $itemcallnumber->[0] ) {
                        $itemdata->{itemcallnumber} = $itemcallnumber->[0]->textContent();
                    }
                }
            }
        }

        my ( $from, $to ) = $self->get_agencies($xmldoc);

        # Autographics workflow is for an accept item i
        # to create the item then do what is in $action
        # my $create = 0;
        # if ( $from && $from =~ /CPomAG/ ) {
        #    $create = 1;
        # }
        my $create = 1;    # Same for Relais and Clio, just always create for now

        my $pickup_location;
        $pickup_location ||= $xpc->find( '//ns:PickupLocation', $root );
        $pickup_location ||= $to->[0]->textContent() if $to && $to->[0];

        my $data =
          $self->ils->acceptitem( $itemid, $user_id, $action, $create,
            $itemdata, $pickup_location, $config );

        my $output;
        my $vars;

        # we switch these for the templates
        # because we are responding, to becomes from, from becomes to
        if ( !$data->{success} ) {
            $output = $self->render_output(
                'problem.tt',
                {
                    message_type => 'AcceptItemResponse',
                    problems     => $data->{problems},
                    from_agency    => $to,
                    to_agency      => $from,
                },
                $self->{ncip_version},
            );
        }
        else {
            my $elements = $self->get_user_elements($xmldoc);
            $output = $self->render_output(
                'response.tt',
                {
                    from_agency    => $to,
                    to_agency      => $from,
                    message_type   => 'AcceptItemResponse',
                    barcode        => $itemid,
                    request_agency => $request_agency,
                    requestid      => $request_id,
                    newbarcode     => $data->{'newbarcode'} || $itemid,
                    elements       => $elements,
                    accept         => $data,
                }
            );
        }
        return $output;
    }
}

1;
