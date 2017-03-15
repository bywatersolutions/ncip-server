#
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

use Data::Dumper;

use MARC::Record;
use MARC::Field;

use C4::Members qw{ GetMemberDetails };
use C4::Circulation qw { AddReturn CanBookBeIssued AddIssue };
use C4::Context;
use C4::Items qw { GetItem };
use C4::Reserves
  qw {CanBookBeReserved AddReserve GetReservesFromItemnumber CancelReserve GetReservesFromBiblionumber CanItemBeReserved};
use C4::Biblio qw {AddBiblio GetMarcFromKohaField GetBiblioData};
use C4::Barcodes::ValueBuilder;
use C4::Items qw{AddItem GetItemsInfo};
use Koha::Items;

sub itemdata {
    my $self     = shift;
    my $barcode  = shift;
    my $itemdata = GetItem( undef, $barcode );
    if ($itemdata) {
        return ( $itemdata, undef );
    }
    else {
        return ( undef, 1 );    # item not found error
    }
}

sub userdata {
    my $self     = shift;
    my $userid   = shift;
    my $userdata = GetMemberDetails( undef, $userid );
    return $userdata;
}

sub userenv {
    #this needs to come from config, on the new call

    my $self    = shift;
    my $branch  = shift || 'AS';
    my @USERENV = (
        106212,
        'NCIP',
        '2996601200068930',
        'NCIP',
        'User',
         $branch,    #branchcode need to set this properly
        'Auckland',
        1,
    );

    C4::Context->_new_userenv('DUMMY_SESSION_ID');
    C4::Context::set_userenv(@USERENV);
    return;
}

sub checkin {
    my $self       = shift;
    my $barcode    = shift;
    my $branch     = shift;
    my $exemptfine = undef;
    my $dropbox    = undef;

    $self->userenv();
    unless ($branch){
        my $item = GetItem( undef, $barcode);
        $branch = $item->{holdingbranch};
    }
    my ( $success, $messages, $issue, $borrower ) =
      AddReturn( $barcode, $branch, $exemptfine, $dropbox );

# Should we force the item to waiting? doesn't seem like a good idea
#C4::Reserves::ModReserveStatus($item->{'itemnumber'}, 'W');

    my $result = {
        success         => $success,
        messages        => $messages,
        iteminformation => $issue,
        borrower        => $borrower
    };

    return $result;
}

sub checkout {
    my $self     = shift;
    my $userid   = shift;
    my $barcode  = shift;
    my $borrower = GetMemberDetails( undef, $userid );
    my $item     = GetItem( undef, $barcode );
    my $error;
    my $confirm;
    $self->userenv( $item->{holdingbranch} );

    if ($borrower) {

        ( $error, $confirm ) = CanBookBeIssued( $borrower, $barcode );

        if (%$error) {

            # Can't issue item, return error hash
            return ( 1, $error );
        }
        elsif (%$confirm) {
            return ( 1, $confirm );
        }
        else {
            my $issue = AddIssue( $borrower, $barcode );
            my $datedue = $issue->date_due();
            $datedue =~ s/ /T/;
            return ( 0, undef, $datedue );    #successfully issued
        }
    }
    else {
        $error->{'badborrower'} = 1;
        return ( 1, $error );
    }
}

sub renew {
    my $self     = shift;
    my $barcode  = shift;
    my $userid   = shift;
    my $borrower = GetMemberDetails( undef, $userid );
    if ($borrower) {
        my $datedue = AddRenewal( $barcode, $borrower->{'borrowernumber'} );
        my $result = {
            success => 1,
            datedue => $datedue
        };
        return $result;

    }
    else {
        #handle stuff here
    }
}

sub request {
    my $self         = shift;
    my $cardnumber   = shift;
    my $barcode      = shift;
    my $biblionumber = shift;
    my $type         = shift;
    my $branchcode   = shift;
    my $borrower     = GetMemberDetails( undef, $cardnumber );
    my $result;
    $branchcode =~ s/^\s+|\s+$//g;

    unless ($branchcode) {
        $result = { success => 0, messages => { 'BRANCH_NOT_FOUND' => 1 } };
        return $result;
    }

    unless ($borrower) {
        $result = { success => 0, messages => { 'BORROWER_NOT_FOUND' => 1 } };
        return $result;
    }
 
    my $item;

    if ($barcode) { # Find specific item requested
        $item = GetItem( undef, $barcode );

        # Autographics will send a request for items from a specific library
        # we don't want to deal with items from any other library
        $item = undef unless $item->{homebranch} eq $branchcode; 

        # Autographics needs this item to be available for hold fulfillment *now*
        my ( $issuingimpossible, $needsconfirmation ) =  CanBookBeIssued( $borrower, $item->{barcode} );
        $item = undef if ( keys %$issuingimpossible || keys %$needsconfirmation  );

        $item = undef unless CanItemBeReserved( $borrower->{borrowernumber}, $item->{itemnumber} ) eq 'OK';
    }

    unless ($item) { # Fallback to finding another item
        my @items;

        if ( $type eq 'SYSNUMBER' ) {
            @items = Koha::Items->search({ biblionumber => $biblionumber });
        }
        elsif ( $type eq 'ISBN' ) {
            #FIXME deal with this
        }

warn "ITEMS: @items: " . scalar @items;
        foreach my $i ( @items ) {
            $item = $i->unblessed();

            # Autographics will send a request for items from a specific library
            # we don't want to deal with items from any other library
            $item = undef unless $item->{homebranch} eq $branchcode; 

            if ( $item ) {
                # Autographics needs this item to be available for hold fulfillment *now*
                my ( $issuingimpossible, $needsconfirmation ) =  CanBookBeIssued( $borrower, $item->{barcode} );
                $item = undef if ( keys %$issuingimpossible || keys %$needsconfirmation  );
            }

            if ( $item ) {
                $item = undef unless CanItemBeReserved( $borrower->{borrowernumber}, $item->{itemnumber} ) eq 'OK';
            }

            last if $item; # We found an item that is available and holdable, we can stop looking now
        }
    }


    unless ($item) {
        $result = { success => 0, messages => {'ITEM_NOT_FOUND'} };
        return $result;
    }

    $self->userenv();
    
    if (
        CanBookBeReserved(
            $borrower->{borrowernumber},
            $item->{biblionumber}
        )
      )
    {
        my $biblioitemnumber = $item->{biblionumber}; # FIXME: This isn't always true

        # Add reserve here
        my $request_id = AddReserve(
            $branchcode,               $borrower->{borrowernumber},
            $item->{biblionumber},
            [$biblioitemnumber],       1,
            undef,                     undef,
            'Placed By ILL',           '',
            $item->{'itemnumber'},     undef
        );

        $result = {
            success  => 1,
            messages => { request_id => $request_id }
        };
        return $result;
    }
    else {
        $result = { success => 0, messages => { CANNOT_REQUEST => 1 } };
        return $result;

    }
}

sub cancelrequest {
    my $self      = shift;
    my $requestid = shift;
    CancelReserve( { reserve_id => $requestid } );

    my $result = { success => 1, messages => { request_id => $requestid } };
    return $result;
}

sub acceptitem {
    my $self    = shift || die "Not called as a method, we must bail out";
    my $barcode = shift || die "No barcode passed can not continue";
    my $user    = shift;
    my $action  = shift;
    my $create  = shift;
    my $iteminfo   = shift;
    my $branchcode = shift;
    $branchcode =~ s/^\s+|\s+$//g;

    my $result;
    $self->userenv();    # set userenvironment
    my ( $biblionumber, $biblioitemnumber, $itemnumber );
    if ($create) {
        my $record;
        my $frameworkcode = 'FA';    # we should get this from config

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
                MARC::Field->new( '100', '1', '0', 'a' => $iteminfo->{author} ),
                MARC::Field->new( '245', '1', '0', 'a' => $iteminfo->{title} ),
                MARC::Field->new(
                    '260', '1', '0',
                    'b' => $iteminfo->{publisher},
                    'c' => $iteminfo->{publicationdate}
                ),
                MARC::Field->new(
                    '942', '1', '0', 'c' => $iteminfo->{mediumtype}
                )
            );

        }

        ( $biblionumber, $biblioitemnumber ) =
          AddBiblio( $record, $frameworkcode );

        $barcode = 'ILL' . $biblionumber . time unless $barcode;

        my $item = {
            'barcode'       => $barcode,
            'holdingbranch' => $branchcode,
            'homebranch'    => $branchcode,
            'itemnotes_nonpublic' => 'Created for ILL', #FIXME: Why didn't this work?
        };

        C4::Items::_check_itembarcode($item); # Prefix the barcode if needed
        while ( GetItem( undef, $item->{barcode} ) ) {
            # If the baroce already exists, just make up a new one
            $item->{barcode} = 'ILL' . $biblionumber . time;
        }

        ( $biblionumber, $biblioitemnumber, $itemnumber ) =
          AddItem( $item, $biblionumber );

    }

    my $itemdata;
    if ( $itemnumber ) {
        $itemdata = GetItem( $itemnumber );
    } else {
        # Prefix this barcode before calling GetItem, needed for Koha with barcode prefixes patch
        my $item = { barcode => $barcode, homebranch => $branchcode };
        C4::Items::_check_itembarcode($item);
        $barcode = $item->{barcode};

        # find hold and get branch for that, check in there
        $itemdata = GetItem( undef, $barcode );
    }

    my ( $reservedate, $borrowernumber, $branchcode2, $reserve_id, $wait ) =
      GetReservesFromItemnumber( $itemdata->{'itemnumber'} );

    # now we have to check the requested action
    if ( $action =~ /^Hold For Pickup And Notify/ ) {
        unless ($reserve_id) {
            # no reserve, place one
            if ($user) {
                my $borrower = GetMemberDetails( undef, $user );
                if ($borrower) {
                    AddReserve(
                        $branchcode,
                        $borrower->{'borrowernumber'},
                        $biblionumber,
                        [$biblioitemnumber],
                        1,
                        undef,
                        undef,
                        'Placed By ILL',
                        '',
                        $itemdata->{'itemnumber'},
                        undef
                    );
                }
                else {
                    $result =
                      { success => 0, messages => { NO_BORROWER => 1 } };
                    return $result;
                }
            }
            else {
                $result =
                  { success => 0, messages => { NO_HOLD_BORROWER => 1 } };
                return $result;
            }
        }
    }
    else {
        unless ($reserve_id) {
            $result = { success => 0, messages => { NO_HOLD => 1 } };
            return $result;
        }
    }

    my ( $success, $messages, $issue, $borrower ) =
      AddReturn( $itemdata->{barcode}, $branchcode, undef, undef );
    if ( $messages->{'NotIssued'} ) {
        $success = 1
          ; # we do this because we are only doing the return to trigger the reserve
    }

    $result = {
        success         => $success,
        messages        => $messages,
        iteminformation => $issue,
        borrower        => $borrower,
        newbarcode      => $itemdata->{barcode},
    };

    return $result;
}
1;
