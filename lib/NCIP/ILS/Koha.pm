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

use C4::Members qw{ GetMemberDetails };
use C4::Circulation qw { AddReturn CanBookBeIssued AddIssue };
use C4::Context;
use C4::Items qw { GetItem };
use C4::Reserves qw {CanBookBeReserved AddReserve GetReservesFromItemnumber};

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

sub checkin {
    my $self       = shift;
    my $barcode    = shift;
    my $branch     = shift;
    my $exemptfine = undef;
    my $dropbox    = undef;
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
    my $self           = shift;
    my $biblionumber   = shift;
    my $borrowernumber = shift;
    if ( CanBookBeReserved( $borrowernumber, $biblionumber ) ) {

        # Add reserve here
        return ( undef, "Requested" );
    }
    else {
        return ( 1, "Book can not be requested" );
    }
}

sub acceptitem {
    my $self    = shift;
    my $barcode = shift;
    my $result;

    # find hold and get branch for that, check in there
    my $itemdata = GetItem( undef, $barcode );
    my ( $reservedate, $borrowernumber, $branchcode, $reserve_id, $wait ) =
      GetReservesFromItemnumber( $itemdata->{'itemnumber'} );
    unless ($reserve_id) {
        $result = { success => 0, messages => { NO_HOLD => 1 } };
        return $result;
    }
    $result = $self->checkin( $barcode, $branchcode );
    return $result;
}
1;
