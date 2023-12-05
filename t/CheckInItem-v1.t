#!/usr/bin/perl

use Modern::Perl;

use Test::More tests => 2;

use Dancer::Test;
use Template;
use XML::Hash;

use lib 'lib';

# From NCIP
use NCIP::Dancing;
use Dancer ':syntax';

# From Koha
use Koha::Database;
use Koha::Libraries;
use Koha::Patrons;
use t::lib::Mocks;
use t::lib::TestBuilder;

my $dom_converter = XML::Hash->new();

my $schema = Koha::Database->schema;
$schema->storage->txn_begin;
my $builder = t::lib::TestBuilder->new;
my $dbh     = C4::Context->dbh;

my $tt = Template->new({
    INCLUDE_PATH => 't/templates',
    INTERPOLATE  => 1,
}) || die "$Template::ERROR\n";

# Start transaction
$dbh->{RaiseError} = 1;

my $response;
my $dom;

my $patron_category = $builder->build(
    {
        source => 'Category',
        value  => {
            category_type                 => 'P',
            enrolmentfee                  => 0,
            BlockExpiredPatronOpacActions => -1,    # Pick the pref value
        }
    }
);

my $library = Koha::Libraries->search()->next();

my $patron_1 = $builder->build_object(
    {
        class => 'Koha::Patrons',
        value => {
            branchcode   => $library->id,
            categorycode => $patron_category->{categorycode},
            dateexpiry   => '2032-12-31',
            firstname    => 'Kyle',
            surname      => 'Hall',
            userid       => 'khall',
        }
    }
);

my $item_1 = Koha::Items->search()->next();
$item_1->homebranch( $library->id );
$item_1->holdingbranch( $library->id );
$item_1->update();
#
# Need to mock userenv for AddIssue
my $module = new Test::MockModule('C4::Context');
$module->mock('userenv', sub { { branch => $library->id } });

subtest 'Test CheckInItem with valid user and item' => sub {
    plan tests => 1;

    config->{koha}->{no_error_on_return_without_checkout} = 1;
    config->{koha}->{trap_hold_on_checkin} = 0;

    my $issue = C4::Circulation::AddIssue( $patron_1, $item_1->barcode );

    my $ncip_message;
    $tt->process('v1/CheckInItem.xml', {
        item_identifier => $item_1->barcode,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is(
        $dom->{NCIPMessage}->{CheckInItemResponse}->{UniqueItemId}->{ItemIdentifierValue}->{text},
        $item_1->barcode,
        'CheckInItemResponse returns correct item barcode for item checked out by patron'
    );

    $issue->delete(); # Just in case checkin fails
};

subtest 'Test CheckInItem without checkout' => sub {
    plan tests => 5;

    config->{koha}->{no_error_on_return_without_checkout} = 1;
    config->{koha}->{trap_hold_on_checkin} = 0;

    my $ncip_message;
    $tt->process('v1/CheckInItem.xml', {
        item_identifier => $item_1->barcode,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is(
        $dom->{NCIPMessage}->{CheckInItemResponse}->{UniqueItemId}->{ItemIdentifierValue}->{text},
        $item_1->barcode,
        'CheckInItemResponse returns correct item barcode for item not checked out by a patron, no_error_on_return_without_checkout = 1'
    );

    config->{koha}->{no_error_on_return_without_checkout} = 0;
    config->{koha}->{trap_hold_on_checkin} = 0;

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is(
        $dom->{NCIPMessage}->{CheckInItemResponse}->{Problem}->{ProcessingError}->{ProcessingErrorType}->{Value}->{text},
	'Item Not Checked Out',
        'CheckInItemResponse returns correct problem type for item not checked out by a patron, no_error_on_return_without_checkout = 0, trap_hold_on_checkin = 0'
    );

    is(
        $dom->{NCIPMessage}->{CheckInItemResponse}->{Problem}->{ProcessingError}->{ProcessingErrorElement}->{ElementName}->{text},
	'UniqueItemIdentifier',
        'CheckInItemResponse returns correct problem element for item not checked out by a patron, no_error_on_return_without_checkout = 0, trap_hold_on_checkin = 0'
    );

    is(
        $dom->{NCIPMessage}->{CheckInItemResponse}->{Problem}->{ProcessingError}->{ProcessingErrorElement}->{ProcessingErrorValue}->{text},
        $item_1->barcode,
        'CheckInItemResponse returns correct problem value for item not checked out by a patron, no_error_on_return_without_checkout = 0, trap_hold_on_checkin = 0'
    );

    is(
        $dom->{NCIPMessage}->{CheckInItemResponse}->{Problem}->{ProcessingError}->{ProcessingErrorDetail}->{Value}->{text},
	undef,
        'CheckInItemResponse returns *no* problem type for NCIP v1'
    );
};
