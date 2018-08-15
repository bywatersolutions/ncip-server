#===============================================================================
#
#         FILE: Koha.pm
#
#  DESCRIPTION:
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Chris Cormack (rangi), chrisc@catalyst.net.nz
# ORGANIZATION: Koha Development Team
#      VERSION: 1.0
#      CREATED: 05/11/13 11:14:09
#     REVISION: ---
#===============================================================================
package NCIP::ILS::Koha;

use Modern::Perl;
use Object::Tiny qw{ name };

use MARC::Record;
use MARC::Field;

use C4::Auth qw{
  checkpw_hash
};

#  IsMemberBlocked
use Koha::Patrons;
use C4::Circulation qw{
  AddReturn
  CanBookBeIssued
  AddIssue
  GetTransfers
  CanBookBeRenewed
  AddRenewal
};
use C4::Context;
use C4::Items qw{
  GetItem
  DelItem
};
use C4::Reserves qw{
  CanBookBeReserved
  CanItemBeReserved
  AddReserve
  GetReserveStatus
  ModReserveAffect
};
use C4::Biblio qw{
  AddBiblio
  DelBiblio
  GetMarcFromKohaField
  GetBiblioData
  GetMarcBiblio
};
use C4::Barcodes::ValueBuilder;
use C4::Items qw{
  AddItem
  ModItemTransfer
};
use Koha::Database;
use Koha::Holds;
use Koha::Items;
use Koha::Libraries;
use Koha::Patrons;

sub itemdata {
    my $self    = shift;
    my $barcode = shift;

    my $item = GetItem( undef, $barcode );

    if ($item) {
        my $biblio = GetBiblioData( $item->{biblionumber} );
        $item->{biblio} = $biblio;

        my $record = GetMarcBiblio({ biblionumber => $item->{biblionumber}});
        $item->{record} = $record;

        my $itemtype = Koha::Database->new()->schema()->resultset('Itemtype')
          ->find( $item->{itype} );
        $item->{itemtype} = $itemtype;

        my $hold = GetReserveStatus( $item->{itemnumber} );
        $item->{hold} = $hold;

        my @holds = Koha::Holds->search( { biblionumber =>  $item->{biblionumber} } );
        $item->{holds} = \@holds;

        my @transfers = GetTransfers( $item->{itemnumber} );
        $item->{transfers} = \@transfers;

        return $item;
    }
}

sub userdata {
    my $self     = shift;
    my $userid   = shift;

    my $patron = Koha::Patrons->find( { cardnumber => $userid } );
    $patron ||= Koha::Patrons->find( { userid => $userid } );

    return unless $patron;

    my $block_status;
    if ( my $debarred_date = $patron->is_debarred ) {
        $block_status = $debarred_date;
    }
    elsif ( my $num_overdues = $patron->has_overdues ) {
        $block_status = $num_overdues;
    }
    else {
        $block_status = 0;
    }

    my $patron_hashref = $patron->unblessed;

    $patron_hashref->{restricted} = $block_status;

    return $patron_hashref;
}

sub userenv {    #FIXME: This really needs to be in a config file
    my $self    = shift;
    my $branch  = shift || 'AS';
    my @USERENV = (
        undef,               #set_userenv shifts the first var for no reason
        312,                 #borrowernumber
        'NCIP',              #userid
        '24535000002009',    #cardnumber
        'NCIP',              #firstname
        'User',              #surname
        $branch,             #branchcode need to set this properly
        'Auckland',          #branchname
        1,                   #userflags
    );

    C4::Context->_new_userenv('DUMMY_SESSION_ID');
    C4::Context::set_userenv(@USERENV);
}

sub checkin {
    my ( $self, $params ) = @_;
    my $barcode     = $params->{barcode};
    my $branch      = $params->{branch};
    my $exempt_fine = $params->{exempt_fine};
    my $dropbox     = $params->{dropbox};
    my $config      = $params->{config};

    $self->userenv();

    unless ($branch) {
        my $item = GetItem( undef, $barcode );
        $branch = $item->{holdingbranch};
    }

    my ( $success, $messages, $issue, $borrower ) =
      AddReturn( $barcode, $branch, $exempt_fine, $dropbox );

    my @problems;

    $success ||= 1 if $messages->{LocalUse};

    if ( $messages->{NotIssued} ) {
        if ( $config->{no_error_on_return_without_checkout} || $config->{trap_hold_on_checkin} ) {
            $success ||= 1;
        }
        else {

            $success &&= 0;

            push(
                @problems,
                {
                    problem_type    => 'Item Not Checked Out',
                    problem_element => 'UniqueItemIdentifier',
                    problem_value   => $barcode,
                    problem_detail =>
                      'There is no record of the check out of the item.',
                }
            );
        }
    }

    if ( $messages->{ResFound} && $config->{trap_hold_on_checkin} ) {
        my $itemnumber        = $messages->{ResFound}->{itemnumber};
        my $borrowernumber    = $messages->{ResFound}->{borrowernumber};
        my $reserve_id        = $messages->{ResFound}->{reserve_id};
        my $pickup_branchcode = $messages->{ResFound}->{branchcode};

        my $item = Koha::Items->find($itemnumber);

        my $transferToDo = $item->holdingbranch ne $pickup_branchcode;
        ModReserveAffect( $itemnumber, $borrowernumber, $transferToDo,
            $reserve_id );

        if ($transferToDo) {
            my $from_branch = $item->holdingbranch;
            my $to_branch   = $pickup_branchcode;
            ModItemTransfer( $itemnumber, $from_branch, $to_branch );
        }
    }

    if ( $messages->{BadBarcode} ) {
        push(
            @problems,
            {
                problem_type    => 'Unknown Item',
                problem_element => 'UniqueItemIdentifier',
                problem_value   => $barcode,
                problem_detail  => 'Item is not known.',
            }
        );
    }

    my $result = {
        success   => $success,
        problems  => \@problems,
        item_data => $issue,
        borrower  => $borrower
    };

    return $result;
}

=head2 checkout

{ success => $success, problems => \@problems, date_due => $date_due } =
  $ils->checkout( $userid, $itemid, $date_due );

=cut

sub checkout {
    my $self     = shift;
    my $userid   = shift;
    my $barcode  = shift;
    my $date_due = shift;

    my $patron = Koha::Patrons->find( { cardnumber => $userid } );
    $patron ||= Koha::Patrons->find( { userid => $userid } );

    my $item = GetItem( undef, $barcode );

    $self->userenv( $item->{holdingbranch} );

    if ($patron) {
        my ( $error, $confirm ) =
          CanBookBeIssued( $patron->unblessed, $barcode, $date_due );

        my $reasons = { %$error, %$confirm };

        delete $reasons->{DEBT} if C4::Context->preference('AllowFineOverride');

        if (%$reasons) {
            my @problems;

            push(
                @problems,
                {
                    problem_type    => 'Unknown Item',
                    problem_detail  => 'Item is not known.',
                    problem_element => 'ItemIdentifierValue',
                    problem_value   => $barcode,
                }
            ) if $reasons->{UNKNOWN_BARCODE};

            push(
                @problems,
                {
                    problem_type => 'User Ineligible To Check Out This Item',
                    problem_detail =>
                      'Item is alredy checked out to this User.',
                    problem_element => 'ItemIdentifierValue',
                    problem_value   => $barcode,
                    problem_element => 'UserIdentifierValue',
                    problem_value   => $userid,
                }
            ) if $reasons->{BIBLIO_ALREADY_ISSUED};

            push(
                @problems,
                {
                    problem_type    => 'Invalid Date',
                    problem_detail  => 'Date due is not valid.',
                    problem_element => 'DesiredDateDue',
                    problem_value   => $date_due,
                }
            ) if $reasons->{INVALID_DATE} || $reasons->{INVALID_DATE};

            push(
                @problems,
                {
                    problem_type    => 'User Blocked',
                    problem_element => 'UserIdentifierValue',
                    problem_value   => $userid,
                    problem_detail  => $reasons->{GNA} ? 'Gone no address'
                    : $reasons->{LOST}               ? 'Card lost'
                    : $reasons->{DBARRED}            ? 'User restricted'
                    : $reasons->{EXPIRED}            ? 'User expired'
                    : $reasons->{DEBT}               ? 'User has debt'
                    : $reasons->{USERBLOCKEDOVERDUE} ? 'User has overdue items'
                    : $reasons->{USERBLOCKEDNOENDDATE} ? 'User restricted'
                    : $reasons->{AGE_RESTRICTION}      ? 'Age restriction'
                    :                                    'Reason unkown'
                }
              )
              if $reasons->{GNA}
              || $reasons->{LOST}
              || $reasons->{DBARRED}
              || $reasons->{EXPIRED}
              || $reasons->{DEBT}
              || $reasons->{USERBLOCKEDOVERDUE}
              || $reasons->{USERBLOCKEDOVERDUEDATE}
              || $reasons->{AGE_RESTRICTION};

            push(
                @problems,
                {
                    problem_type => 'Maximum Check Outs Exceeded',
                    problem_detail =>
                      'Check out cannot proceed because the User '
                      . 'already has the maximum number of items checked out.',
                    problem_element => 'UserIdentifierValue',
                    problem_value   => $userid,
                }
            ) if $reasons->{TOO_MANY};

            push(
                @problems,
                {
                    problem_type   => 'Item Does Not Circulate',
                    problem_detail => 'Check out of Item cannot proceed '
                      . 'because the Item is non-circulating.',
                    problem_element => 'ItemIdentifierValue',
                    problem_value   => $barcode,
                }
            ) if $reasons->{NOT_FOR_LOAN} || $reasons->{NOT_FOR_LOAN_FORCING};

            push(
                @problems,
                {
                    problem_type =>
                      'Check Out Not Allowed - Item Has Outstanding Requests',
                    problem_detail => 'Check out of Item cannot proceed '
                      . 'because the Item has outstanding requests.',
                    problem_element => 'ItemIdentifierValue',
                    problem_value   => $barcode,
                }
            ) if $reasons->{RESERVE_WAITING} || $reasons->{RESERVED};

            push(
                @problems,
                {
                    problem_type   => 'Resource Cannot Be Provided',
                    problem_detail => 'Check out cannot proceed because '
                      . 'the desired resource cannot be provided',
                    problem_element => 'ItemIdentifierValue',
                    problem_value   => $barcode,
                }
              )
              if $reasons->{WTHDRAWN}
              || $reasons->{RESTRICTED}
              || $reasons->{ITEM_LOST}
              || $reasons->{ITEM_LOST}
              || $reasons->{BORRNOTSAMEBRANCH}
              || $reasons->{HIGHHOLDS}
              || $reasons->{NO_RENEWAL_FOR_ONSITE_CHECKOUTS}    #FIXME: Should
              || $reasons->{NO_MORE_RENEWALS}                   #FIXME have
              || $reasons->{RENEW_ISSUE};    #FIXME different error

            return { success => 0, problems => \@problems };
        }
        else {
            my $issue = AddIssue( $patron->unblessed, $barcode, $date_due );
            $date_due = $issue->date_due();
            $date_due =~ s/ /T/;
            return {
                success    => 1,
                date_due   => $date_due,
                newbarcode => $barcode
            };
        }
    }
    else {
        my $problems = [
            {
                problem_type    => 'Unknown User',
                problem_detail  => 'User is not known',
                problem_element => 'UserIdentifierValue',
                problem_value   => $userid,
            }
        ];
        return { success => 0, problems => $problems };
    }
}

sub renew {
    my $self    = shift;
    my $barcode = shift;
    my $userid  = shift;

    my $patron = Koha::Patrons->find( { cardnumber => $userid } );
    $patron ||= Koha::Patrons->find( { userid => $userid } );
    return {
        success  => 0,
        problems => [
            {
                problem_type    => 'Unknown User',
                problem_detail  => 'User is not known',
                problem_element => 'UserIdentifierValue',
                problem_value   => $userid,
            }
        ]
      }
      unless $patron;

    my $item = GetItem( undef, $barcode );
    return {
        success  => 0,
        problems => [
            {
                problem_type    => 'Unknown Item',
                problem_detail  => 'Item is not known.',
                problem_element => 'UniqueItemIdentifier',
                problem_value   => $barcode,
            }
        ]
      }
      unless $item;

    my ( $ok, $error ) =
      CanBookBeRenewed( $patron->borrowernumber, $item->{itemnumber} );

    $error //= q{};

    return {
        success  => 0,
        problems => [
            {
                problem_type => 'Item Not Checked Out',
                problem_detail =>
                  'There is no record of the check out of the Item.',
                problem_element => 'UniqueItemIdentifier',
                problem_value   => $barcode,
            }
        ]
      }
      if $error eq 'no_checkout';

    return {
        success  => 0,
        problems => [
            {
                problem_type =>
                  'Renewal Not Allowed - Item Has Outstanding Requests',
                problem_detail =>
                  'Item may not be renewed because outstanding requests '
                  . 'take precedence over the renewal request.',
                problem_element => 'UniqueItemIdentifier',
                problem_value   => $barcode,
            }
        ]
      }
      if $error eq 'on_reserve';

    return {
        success  => 0,
        problems => [
            {
                problem_type    => 'Item Not Renewable',
                problem_detail  => 'Item may not be renewed.',
                problem_element => 'UniqueItemIdentifier',
                problem_value   => $barcode,
            }
        ]
      }
      if $error;    # Generic message for all other reasons

    my $datedue =
      AddRenewal( $patron->borrowernumber, $item->{itemnumber} );

    return {
        success => 1,
        datedue => $datedue
    };
}

sub request {
    my $self         = shift;
    my $userid       = shift;
    my $barcode      = shift;
    my $biblionumber = shift;
    my $type         = shift;
    my $branchcode   = shift;

    my $patron = Koha::Patrons->find( { cardnumber => $userid } );
    $patron ||= Koha::Patrons->find( { userid => $userid } );

    return {
        success  => 0,
        problems => [
            {
                problem_type    => 'Unknown User',
                problem_detail  => 'User is not known.',
                problem_element => 'UserIdentifierValue',
                problem_value   => $userid,
            }
        ]
      }
      unless $patron;

    #FIXME: Maybe this should be configurable?
    # If no branch is given, fall back to patron home library
    $branchcode ||= q{};
    $branchcode =~ s/^\s+|\s+$//g;
    $branchcode ||= $patron->branchcode;
    return {
        success  => 0,
        problems => [
            {
                #FIXME: probably no the most apropo type
                # but unable to find a better one
                problem_type => 'Unknown Agency',
                problem_detail =>
                  'The library from which the item is requested is not known.',
            }
        ]
      }
      unless $branchcode;

    my $itemdata = $barcode ? GetItem( undef, $barcode ) : undef;

    if ($barcode) {
        return {
            success  => 0,
            problems => [
                {
                    problem_type    => 'Unknown Item',
                    problem_detail  => 'Item is not known.',
                    problem_element => 'UniqueItemIdentifier',
                    problem_value   => $barcode,
                }
            ]
          }
          unless $itemdata;
    }

    unless ($itemdata) {
        if ( $type eq 'SYSNUMBER' ) {
            $itemdata = GetBiblioData($biblionumber);

            return {
                success  => 0,
                problems => [
                    {
                        problem_type    => 'Unknown Item',
                        problem_detail  => 'Item is not known.',
                        problem_element => 'BibliographicRecordIdentifier',
                        problem_value   => $biblionumber,
                    }
                ]
              }
              unless $itemdata;
        }
        elsif ( $type eq 'ISBN' ) {
            return {
                success  => 0,
                problems => [
                    {
                        problem_type => 'Tempaorary Processing Failure',
                        problem_detail =>
                          'Unable to handle record look up by ISBN. '
                          . 'Not yet implemented',
                        problem_element => 'BibliographicItemIdentifierCode',
                        problem_value   => $type,
                    }
                ]
            };
        }
        else {
            return {
                success  => 0,
                problems => [
                    {
                        problem_type    => 'Tempaorary Processing Failure',
                        problem_detail  => 'The identifier code is not known.',
                        problem_element => 'BibliographicItemIdentifierCode',
                        problem_value   => $type,
                    }
                ]
            };
        }
    }

    $self->userenv();

    my $borrowernumber = $patron->borrowernumber;
    my $itemnumber     = $itemdata->{itemnumber};

    my $can_reserve =
      $itemnumber
      ? CanItemBeReserved( $borrowernumber, $itemnumber )
      : CanBookBeReserved( $borrowernumber, $biblionumber );

    if ( $can_reserve eq 'OK' ) {
        my $request_id = AddReserve(
            $branchcode,
            $borrowernumber,
            $biblionumber,
            my $bibitems,
            my $priority = 1,
            my $resdate,
            my $expdate,
            my $notes = 'Placed By ILL',
            my $title,
            my $checkitem = $itemnumber,
            my $found,
        );

        if ($request_id) {
            return {
                success    => 1,
                request_id => $request_id,
            };
        }
        else {
            return {
                success  => 0,
                problems => [
                    {
                        problem_type => 'Duplicate Request',
                        problem_detail =>
                          'Request for the Item already exists; '
                          . 'acting ont his update would create a duplicate request for the Item for the User',
                    }
                ]
            };
        }
    }
    elsif ( $can_reserve eq 'damaged' ) {
        return {
            success  => 0,
            problems => [
                {
                    problem_type    => 'Item Does Not Circulate',
                    problem_detail  => 'Item is damanged.',
                    problem_element => 'UniqueItemIdentifier',
                    problem_value   => $barcode,
                }
            ]
        };
    }
    elsif ( $can_reserve eq 'ageRestricted' ) {
        return {
            success  => 0,
            problems => [
                {
                    problem_type    => 'User Ineligible To Request This Item',
                    problem_detail  => 'Item is age restricted.',
                    problem_element => 'UniqueItemIdentifier',
                    problem_value   => $barcode,
                }
            ]
        };
    }
    elsif ( $can_reserve eq 'tooManyReserves' ) {
        return {
            success  => 0,
            problems => [
                {
                    problem_type => 'User Ineligible To Request This Item',
                    problem_detail =>
                      'User has placed the maximum requests allowed.',
                    problem_element => 'UniqueItemIdentifier',
                    problem_value   => $barcode,
                }
            ]
        };
    }
    elsif ( $can_reserve eq 'notReservable' ) {
        return {
            success  => 0,
            problems => [
                {
                    problem_type    => 'User Ineligible To Request This Item',
                    problem_detail  => 'User cannot request this Item.',
                    problem_element => 'UniqueItemIdentifier',
                    problem_value   => $barcode,
                }
            ]
        };
    }
    elsif ( $can_reserve eq 'cannotReserveFromOtherBranches' ) {
        return {
            success  => 0,
            problems => [
                {
                    problem_type    => 'User Ineligible To Request This Item',
                    problem_element => 'UniqueItemIdentifier',
                    problem_value   => $barcode,
                    problem_detail  => 'User cannot request this Item to be '
                      . 'picked up at specified location.',
                }
            ]
        };
    }
    else {    # Generic fallback message
        return {
            success  => 0,
            problems => [
                {
                    problem_type    => 'User Ineligible To Request This Item',
                    problem_element => 'UniqueItemIdentifier',
                    problem_value   => $barcode,
                    problem_detail =>
                      'User cannot request this Item. ILS returned code '
                      . $can_reserve,
                }
            ]
        };
    }
}

sub cancelrequest {
    my $self       = shift;
    my $request_id = shift;

    my $hold = Koha::Holds->find( $request_id );
    $hold->cancel();

    return {
        success    => 1,
        request_id => $request_id,
    };
}

sub acceptitem {
    my $self       = shift;
    my $barcode    = shift;
    my $userid     = shift;
    my $action     = shift;
    my $create     = shift;
    my $iteminfo   = shift;
    my $branchcode = shift;
    my $config     = shift;

    $branchcode =~ s/^\s+|\s+$//g;
    $branchcode = "$branchcode";    # Convert XML::LibXML::NodeList to string

    my $frameworkcode            = $config->{framework}                || 'FA';
    my $item_branchcode          = $config->{item_branchcode}          || $branchcode;
    my $always_generate_barcode  = $config->{always_generate_barcode}  || 0;
    my $barcode_prefix           = $config->{barcode_prefix}           || q{};
    my $replacement_price        = $config->{replacement_price}        || q{};
    my $item_callnumber          = $config->{item_callnumber}          || q{};
    my $item_itemtype            = $config->{item_itemtype}            || q{};
    my $item_ccode               = $config->{item_ccode}               || q{};
    my $item_location            = $config->{item_location}            || q{};
    my $trap_hold_on_accept_item = $config->{trap_hold_on_accept_item} // 1;

    my ( $field, $subfield ) =
      GetMarcFromKohaField( 'biblioitems.itemtype', $frameworkcode );
    my $fieldslib =
      C4::Biblio::GetMarcStructure( 1, $frameworkcode, { unsafe => 1 } );
    my $itemtype =
      $iteminfo->{itemtype} || $fieldslib->{$field}{$subfield}{defaultvalue} || $item_itemtype;

    unless ($branchcode) {
        my @branches = Koha::Libraries->search();
        if ( @branches > 1 ) {
            return {
                success  => 0,
                problems => [
                    {
                        problem_type => 'Pickup Library Not Specified',
                        problem_detail =>
                          'Pickup library not specified in AcceptItem message.',
                    }
                ]
            };
        }
        else {
            #            $branchcode = $branches->[0]->{branchcode};
            $branchcode = $branches[0]->{branchcode};
        }
    }

    $self->userenv();    # set userenvironment
    my ( $itemnumber, $biblionumber, $biblioitemnumber );
    if ($create) {
        my $record;

        # we must make the item first
        # Autographics workflow is to make the item each time
        if ( C4::Context->preference('marcflavour') eq 'UNIMARC' ) {

            # TODO
        }
        elsif ( C4::Context->preference('marcflavour') eq 'NORMARC' ) {

            #TODO
        }
        else {
            # MARC21
            # create a marc record
            $record = MARC::Record->new();
            $record->leader('     nac  22     1u 4500');
            $record->insert_fields_ordered(
                MARC::Field->new(
                    '100', '1', '0', 'a' => $iteminfo->{author}
                ),
                MARC::Field->new(
                    '245', '1', '0', 'a' => $iteminfo->{title}
                ),
                MARC::Field->new(
                    '260', '1', '0',
                    'b' => $iteminfo->{publisher},
                    'c' => $iteminfo->{publicationdate}
                ),
                MARC::Field->new(
                    '942', '1', '0', 'c' => $iteminfo->{mediumtype}
                ),
                MARC::Field->new(
                    $field, '', '', $subfield => $itemtype
                ),
            );

        }

        ( $biblionumber, $biblioitemnumber ) =
          AddBiblio( $record, $frameworkcode );

        if ($barcode_prefix) {
            $barcode = $barcode_prefix . $barcode;
        }

        if ($always_generate_barcode) {
            $barcode = q{};    # Blank out the barcode so it gets regenerated
        }

        $barcode = $barcode_prefix . $biblionumber . time
          unless $barcode;     # Reasonable gurantee of uniqueness
        while ( GetItem( undef, $barcode ) )
        {    # If the barcode already exists, just make up a new one
            $barcode = $barcode_prefix . $biblionumber . time;
        }

        my $item = {
            barcode          => $barcode,
            holdingbranch    => $item_branchcode,
            homebranch       => $item_branchcode,
            itype            => $itemtype,
            replacementprice => $replacement_price,
            itemcallnumber   => $item_callnumber,
            ccode            => $item_ccode,
            location         => $item_location,
        };
        ( $biblionumber, $biblioitemnumber, $itemnumber, undef, $frameworkcode )
          = AddItem( $item, $biblionumber );
    }

    my $item = Koha::Items->find( $itemnumber );
    my $holds = $item->current_holds;
    my $first_hold = $holds->next;
    my $reserve_id = $first_hold ? $first_hold->reserve_id : undef;

    my $patron = Koha::Patrons->find( { cardnumber => $userid } );
    $patron ||= Koha::Patrons->find( { userid => $userid } );

    # Now we have to check the requested action
    if ( $action =~ /^Hold For Pickup/ || $action =~ /^Circulate/ ) {
        if ($reserve_id) { # There shouldn't be a hold already, abort if there is one
            return {
                problem_type =>
                  'Check Out Not Allowed - Item Has Outstanding Requests',
                problem_detail => 'Check out of Item cannot proceed '
                  . 'because the Item has outstanding requests.',
                problem_element => 'ItemIdentifierValue',
                problem_value   => $barcode,
            };
        }
        else { # Place hold
            if ($userid && $patron) { # Check userid as well as patron in case username "" exists
                $reserve_id = AddReserve(
                    $branchcode,
                    $patron->borrowernumber,
                    $biblionumber,
                    [$biblioitemnumber],
                    1,
                    undef,
                    undef,
                    'Placed By ILL',
                    '',
                    $itemnumber,
                    undef
                );
            }
            else {
                return {
                    success  => 0,
                    problems => [
                        {
                            problem_type    => 'Unknown User',
                            problem_detail  => 'User is not known.',
                            problem_element => 'UserIdentifierValue',
                            problem_value   => $userid,
                        }
                    ]
                };
            }
        }
    }

    # If hold should be trapped on checkin, it should be trapped at this time as well
    my ( $success, $messages, $issue, $borrower ) = AddReturn( $barcode, $item_branchcode, undef, undef );
    $success = $messages->{'NotIssued'} ? 1 : 0;

    my $problems = $success ? [] : [
        {
            problem_type   => 'Temporary Processing Failure',
            problem_detail => 'Request was placed for user but return of '
              . 'item showed the item was checked out.',
            problem_element => 'ItemIdentifierValue',
            problem_value   => $barcode,
        }
    ];

    if ( $success && $trap_hold_on_accept_item ) {
        my $transferToDo = $item->holdingbranch ne $item->homebranch;
        ModReserveAffect( $itemnumber, $patron->id, $transferToDo, $reserve_id );

        if ($transferToDo) {
           my $from_branch = $item->holdingbranch;
           my $to_branch   = $branchcode;
           ModItemTransfer( $itemnumber, $from_branch, $to_branch );
        }
    }

    return {
        success    => $success,
        problems   => $problems,
        item_data  => $issue,
        borrower   => $borrower,
        newbarcode => $barcode,
    };
}

sub delete_item {
    my ( $self, $params ) = @_;
    my $barcode = $params->{barcode};
    my $branch  = $params->{branch};
    my $config  = $params->{config};

    my $success = 1;
    my @problems;

    $self->userenv();

    my $item = Koha::Items->find( { barcode => $barcode } );
    my $biblio = Koha::Biblios->find( $item->biblionumber );

    if ($item) {
        $success = DelItem(
            { itemnumber => $item->id, biblionumber => $item->biblionumber } );

        if ( $biblio->items->count == 0 ) {
            DelBiblio( $biblio->id );
        }

        unless ($success) {
            push(
                @problems,
                {
                    problem_type    => 'Unknown Item',
                    problem_element => 'UniqueItemIdentifier',
                    problem_value   => $barcode,
                    problem_detail  => 'Item is not known.',
                }
            );
        }
    }
    else {
        $success = 0;

        push(
            @problems,
            {
                problem_type    => 'Unknown Item',
                problem_element => 'UniqueItemIdentifier',
                problem_value   => $barcode,
                problem_detail  => 'Item is not known.',
            }
        );
    }

    my $result = {
        success  => $success,
        problems => \@problems,
        item     => $item,
    };

    return $result;
}

sub authenticate_patron {
    my ( $self, $params ) = @_;

    my $ils_user = $params->{ils_user};
    my $pin      = $params->{pin};

    my $hash = $ils_user->userdata->{password};

    return checkpw_hash( $pin, $hash );
}

1;
