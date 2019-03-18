#!/usr/bin/perl

use Modern::Perl;

use Test::More tests => 4;

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
use Koha::Holds;
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

subtest 'Test RequestItem with valid user and valid item' => sub {
    plan tests => 4;

    my $ncip_message;
    $tt->process('v2/RequestItem.xml', {
        user_identifier => $patron_1->cardnumber,
	biblionumber    => $item_1->biblionumber,
	pickup_branchcode => $item_1->holdingbranch,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    my $hold_id = $dom->{NCIPMessage}->{RequestItemResponse}->{RequestId}->{RequestIdentifierValue}->{text};
    ok( $hold_id, "RequestItemResponse returned a request id" );

    my $hold = Koha::Holds->find( $hold_id );
    ok( $hold, "Request id is valid" );

    is( $item_1->biblionumber, $hold->biblionumber, "Request with matching id is for the correct record" );
    is( $patron_1->id, $hold->borrower->id, "Request with matching id is for the correct patron" );
};

subtest 'Test RequestItem with valid user and invalid item' => sub {
    plan tests => 4;

    my $ncip_message;
    $tt->process('v2/RequestItem.xml', {
        user_identifier => $patron_1->cardnumber,
	biblionumber    => 'INVALID_BIBLIONUMBER',
	pickup_branchcode => $item_1->holdingbranch,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is( $dom->{NCIPMessage}->{RequestItemResponse}->{Problem}->{ProblemDetail}->{text}, 'Item is not known.', "RequestItemResponse for invalid item returns correct ProblemDetail" );
    is( $dom->{NCIPMessage}->{RequestItemResponse}->{Problem}->{ProblemValue}->{text}, 'INVALID_BIBLIONUMBER', "RequestItemResponse for invalid item returns correct ProblemValue" );
    is( $dom->{NCIPMessage}->{RequestItemResponse}->{Problem}->{ProblemElement}->{text}, 'BibliographicRecordIdentifier', "RequestItemResponse for invalid item returns correct ProblemElement" );
    is( $dom->{NCIPMessage}->{RequestItemResponse}->{Problem}->{ProblemType}->{text}, 'Unknown Item', "RequestItemResponse for invalid item returns correct ProblemType" );
};

subtest 'Test RequestItem with invalid user and valid item' => sub {
    plan tests => 4;

    my $ncip_message;
    $tt->process('v2/RequestItem.xml', {
        user_identifier => 'INVALID_PATRON_CARDNUMBER',
	biblionumber    => $item_1->biblionumber,
	pickup_branchcode => $item_1->holdingbranch,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is( $dom->{NCIPMessage}->{RequestItemResponse}->{Problem}->{ProblemDetail}->{text}, 'User is not known.', "RequestItemResponse for invalid item returns correct ProblemDetail" );
    is( $dom->{NCIPMessage}->{RequestItemResponse}->{Problem}->{ProblemValue}->{text}, 'INVALID_PATRON_CARDNUMBER', "RequestItemResponse for invalid item returns correct ProblemValue" );
    is( $dom->{NCIPMessage}->{RequestItemResponse}->{Problem}->{ProblemElement}->{text}, 'UserIdentifierValue', "RequestItemResponse for invalid item returns correct ProblemElement" );
    is( $dom->{NCIPMessage}->{RequestItemResponse}->{Problem}->{ProblemType}->{text}, 'Unknown User', "RequestItemResponse for invalid item returns correct ProblemType" );
};

subtest 'Test RequestItem with invalid user and valid item' => sub {
    plan tests => 4;

    my $ncip_message;
    $tt->process('v2/RequestItem.xml', {
        user_identifier => $patron_1->cardnumber,
	biblionumber    => $item_1->biblionumber,
	pickup_branchcode => 'INVALID_BRANCHCODE',
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is( $dom->{NCIPMessage}->{RequestItemResponse}->{Problem}->{ProblemDetail}->{text}, 'The library from which the item is requested is not known.', "RequestItemResponse for invalid item returns correct ProblemDetail" );
    is( $dom->{NCIPMessage}->{RequestItemResponse}->{Problem}->{ProblemValue}->{text}, 'INVALID_BRANCHCODE', "RequestItemResponse for invalid item returns correct ProblemValue" );
    is( $dom->{NCIPMessage}->{RequestItemResponse}->{Problem}->{ProblemElement}->{text}, 'ToAgencyId', "RequestItemResponse for invalid item returns correct ProblemElement" );
    is( $dom->{NCIPMessage}->{RequestItemResponse}->{Problem}->{ProblemType}->{text}, 'Unknown Agency', "RequestItemResponse for invalid item returns correct ProblemType" );
};
