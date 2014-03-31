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

use MARC::Record;
use MARC::Field;

use C4::Members qw{ GetMemberDetails };
use C4::Circulation qw { AddReturn CanBookBeIssued AddIssue };
use C4::Context;
use C4::Items qw { GetItem };
use C4::Reserves
  qw {CanBookBeReserved AddReserve GetReservesFromItemnumber CancelReserve};
use C4::Biblio qw {AddBiblio GetMarcFromKohaField};
use C4::Barcodes::ValueBuilder;
use C4::Items qw{AddItem};

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
    my $self    = shift;
    my @USERENV = (
        1,
        'test',
        'MASTERTEST',
        'Test',
        'Test',
        'AS',    #branchcode need to set this properly
        'Auckland',
        0,
    );

    C4::Context->_new_userenv('DUMMY_SESSION_ID');
    C4::Context->set_userenv(@USERENV);
    return;
}

sub checkin {
    my $self       = shift;
    my $barcode    = shift;
    my $branch     = shift;
    my $exemptfine = undef;
    my $dropbox    = undef;
    $self->userenv();
    my ( $success, $messages, $issue, $borrower ) =
      AddReturn( $barcode, $branch, $exemptfine, $dropbox );
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
    my $error;
    my $confirm;
    $self->userenv();
    if ($borrower) {

        ( $error, $confirm ) = CanBookBeIssued( $borrower, $barcode );

  #( $issuingimpossible, $needsconfirmation ) =  CanBookBeIssued( $borrower,
  #                      $barcode, $duedatespec, $inprocess, $ignore_reserves );
        if (%$error) {

            # Can't issue item, return error hash
            return ( 1, $error );
        }
        elsif (%$confirm) {
            return ( 1, $confirm );
        }
        else {
            my $datedue = AddIssue( $borrower, $barcode );
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
    my $self      = shift;
    my $carnumber = shift;
    my $barcode   = shift;
    my my $borrower = GetMemberDetails( undef, $cardnumber );
    my $result;
    unless ($borrower) {
        $result = { success => 0, messages => { 'BORROWER_NOT_FOUND' => 1 } };
        return $result;
    }
    my $Itemdata = GetItem( undef, $barcode );
    unless ($itemdata) {
        $result = { success => 0, messages => {'ITEM_NOT_FOUND'} };
        return $result;
    }
    $self->userenv();
    if (
        CanBookBeReserved(
            $borrower->{borrowernumber},
            $itemdata->{biblionumber}
        )
      )
    {
        my $biblioitemnumber = $itemdata->{biblionumber};
        my $branchcode       = 'AS';

        # Add reserve here
        AddReserve(
            $branch,                   $borrower->{borrwerborrowernumber},
            $itemdata->{biblionumber}, 'a',
            [$biblioitemnumber],       1,
            undef,                     undef,
            'Placed By ILL',           '',
            $itemdata->{'itemnumber'}, undef
        );

        $result = { success => 1, request_id => 'something' };
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

    my $result = { success => 1 };
    return $result;
}

sub acceptitem {
    my $self    = shift || die "Not called as a method, we must bail out";
    my $barcode = shift || die "No barcode passed can not continue";
    my $user    = shift;
    my $action  = shift;
    my $create  = shift;
    my $iteminfo = shift;
    my $result;

    $self->userenv();    # set userenvironment
    my ( $biblionumber, $biblioitemnumber );
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
        my $itemnumber;

        my %args;
        ( $args{tag}, $args{subfield} ) =
          GetMarcFromKohaField( "items.barcode", '' );
        my ( $nextnum, $scr ) =
          C4::Barcodes::ValueBuilder::incremental::get_barcode( \%args );
        my $item = { 'barcode' => $nextnum };
        ( $biblionumber, $biblioitemnumber, $itemnumber ) =
          AddItem( $item, $biblionumber );
        $barcode = $nextnum;
    }

    # find hold and get branch for that, check in there
    my $itemdata = GetItem( undef, $barcode );

    my ( $reservedate, $borrowernumber, $branchcode, $reserve_id, $wait ) =
      GetReservesFromItemnumber( $itemdata->{'itemnumber'} );

    # now we have to check the requested action
    if ( $action =~ /^Hold For Pickup And Notify/ ) {
        unless ($reserve_id) {
            $branchcode = 'AS';    # set this properly
                                   # no reserve, place one
            if ($user) {
                my $borrower = GetMemberDetails( undef, $user );
                if ($borrower) {
                    AddReserve(
                        $branchcode,
                        $borrower->{'borrowernumber'},
                        $biblionumber,
                        'a',
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
      AddReturn( $barcode, $branchcode, undef, undef );
    if ( $messages->{'NotIssued'} ) {
        $success = 1
          ; # we do this because we are only doing the return to trigger the reserve
    }

    $result = {
        success         => $success,
        messages        => $messages,
        iteminformation => $issue,
        borrower        => $borrower,
        newbarcode      => $barcode
    };

    return $result;
}
1;
