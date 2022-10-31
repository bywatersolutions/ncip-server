#!/usr/bin/perl

use Modern::Perl;

use Test::More tests => 3;

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
use Koha::Items;
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

my $libraries = Koha::Libraries->search();
my $library_1 = $libraries->next();
my $library_2 = $libraries->next();
my $library_3 = $libraries->next();

my $patron_1 = $builder->build_object(
    {
        class => 'Koha::Patrons',
        value => {
            branchcode   => $library_1->id,
            categorycode => $patron_category->{categorycode},
            dateexpiry   => '2032-12-31',
            firstname    => 'Kyle',
            surname      => 'Hall',
            userid       => 'khall',
        }
    }
);

# Need to mock userenv for AddIssue
#my $module = new Test::MockModule('C4::Context');
#$module->mock('userenv', sub { { branch => $library_2->id } });

subtest 'Test AcceptItem with valid user' => sub {
    plan tests => 10;

    config->{koha}->{framework} = 'FA';
    config->{koha}->{replacement_price} = undef;
    config->{koha}->{barcode_prefix} = undef;
    config->{koha}->{item_branchcode} = undef;
    config->{koha}->{always_generate_barcode} = undef;
    config->{koha}->{trap_hold_on_accept_item} = undef;
    #TODO: itemtype_map
    config->{koha}->{item_callnumber} = undef;
    config->{koha}->{item_itemtype} = undef;
    config->{koha}->{item_ccode} = undef;
    config->{koha}->{item_location} = undef;

    my $ncip_message;
    $tt->process('v2/AcceptItem.xml', {
	patron_cardnumber => $patron_1->cardnumber,
	pickup_location => $library_2->id,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is(
        $dom->{NCIPMessage}->{AcceptItemResponse}->{RequestId}->{RequestIdentifierValue}->{text},
	'KOHA-123456789',
	'AcceptItemResponse gives correct RequestIdentifierValue',
    );

    is(
        $dom->{NCIPMessage}->{AcceptItemResponse}->{RequestId}->{AgencyId}->{text},
	'KOHA',
	'AcceptItemResponse gives correct AgencyId',
    );

    is(
        $dom->{NCIPMessage}->{AcceptItemResponse}->{ItemId}->{ItemIdentifierType}->{text},
	'Item Barcode',
	'AcceptItemResponse gives correct ItemIdentifierType',
    );

    my $item_barcode = $dom->{NCIPMessage}->{AcceptItemResponse}->{ItemId}->{ItemIdentifierValue}->{text};
    ok(
	$item_barcode,
	'AcceptItemResponse gives an ItemIdentifierValue'
    );

    my $item = Koha::Items->find({ barcode => $item_barcode });
    is( ref($item), 'Koha::Item', 'Found item with corrosponding item barcode' );

    my $b = $item->biblio;
    is( $b->frameworkcode, 'FA', 'Bib has correct framework code' );
    is( $b->copyrightdate, '2001', 'Bib has correct copyright date' );
    is( $b->author, 'Guertin, Mike.', 'Bib has correct author' );
    is( $b->title, 'Precision framing', 'Bib has correct title' );

    my $bi = $item->biblioitem;
    is( $bi->publishercode, 'Taunton Press ; Publishers Group West [distributor]', 'Bib has correct publisher' );
};

subtest 'Test AcceptItem with item_branchcode set to a valid branchcode' => sub {
    plan tests => 12;

    config->{koha}->{framework} = 'FA';
    config->{koha}->{replacement_price} = undef;
    config->{koha}->{barcode_prefix} = undef;
    config->{koha}->{item_branchcode} = $library_3->branchcode;
    config->{koha}->{always_generate_barcode} = undef;
    config->{koha}->{trap_hold_on_accept_item} = undef;
    #TODO: itemtype_map
    config->{koha}->{item_callnumber} = undef;
    config->{koha}->{item_itemtype} = undef;
    config->{koha}->{item_ccode} = undef;
    config->{koha}->{item_location} = undef;

    my $ncip_message;
    $tt->process('v2/AcceptItem.xml', {
	patron_cardnumber => $patron_1->cardnumber,
	pickup_location => $library_2->id,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is(
        $dom->{NCIPMessage}->{AcceptItemResponse}->{RequestId}->{RequestIdentifierValue}->{text},
	'KOHA-123456789',
	'AcceptItemResponse gives correct RequestIdentifierValue',
    );

    is(
        $dom->{NCIPMessage}->{AcceptItemResponse}->{RequestId}->{AgencyId}->{text},
	'KOHA',
	'AcceptItemResponse gives correct AgencyId',
    );

    is(
        $dom->{NCIPMessage}->{AcceptItemResponse}->{ItemId}->{ItemIdentifierType}->{text},
	'Item Barcode',
	'AcceptItemResponse gives correct ItemIdentifierType',
    );

    my $item_barcode = $dom->{NCIPMessage}->{AcceptItemResponse}->{ItemId}->{ItemIdentifierValue}->{text};
    ok(
	$item_barcode,
	'AcceptItemResponse gives an ItemIdentifierValue'
    );

    my $item = Koha::Items->find({ barcode => $item_barcode });
    is( ref($item), 'Koha::Item', 'Found item with corrosponding item barcode' );

    my $b = $item->biblio;
    is( $b->frameworkcode, 'FA', 'Bib has correct framework code' );
    is( $b->copyrightdate, '2001', 'Bib has correct copyright date' );
    is( $b->author, 'Guertin, Mike.', 'Bib has correct author' );
    is( $b->title, 'Precision framing', 'Bib has correct title' );

    my $bi = $item->biblioitem;
    is( $bi->publishercode, 'Taunton Press ; Publishers Group West [distributor]', 'Bib has correct publisher' );

    is( $item->homebranch, $library_3->branchcode, "Item homebranch is set to the correct branchcode" );
    is( $item->holdingbranch, $library_3->branchcode, "Item holdingbranch is set to the correct branchcode" );
};

subtest 'Test AcceptItem with item_branchcode set to __PATRON__BRANCHCODE__' => sub {
    plan tests => 12;

    config->{koha}->{framework} = 'FA';
    config->{koha}->{replacement_price} = undef;
    config->{koha}->{barcode_prefix} = undef;
    config->{koha}->{item_branchcode} = '__PATRON_BRANCHCODE__';
    config->{koha}->{always_generate_barcode} = undef;
    config->{koha}->{trap_hold_on_accept_item} = undef;
    #TODO: itemtype_map
    config->{koha}->{item_callnumber} = undef;
    config->{koha}->{item_itemtype} = undef;
    config->{koha}->{item_ccode} = undef;
    config->{koha}->{item_location} = undef;

    my $ncip_message;
    $tt->process('v2/AcceptItem.xml', {
	patron_cardnumber => $patron_1->cardnumber,
	pickup_location => $library_2->id,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is(
        $dom->{NCIPMessage}->{AcceptItemResponse}->{RequestId}->{RequestIdentifierValue}->{text},
	'KOHA-123456789',
	'AcceptItemResponse gives correct RequestIdentifierValue',
    );

    is(
        $dom->{NCIPMessage}->{AcceptItemResponse}->{RequestId}->{AgencyId}->{text},
	'KOHA',
	'AcceptItemResponse gives correct AgencyId',
    );

    is(
        $dom->{NCIPMessage}->{AcceptItemResponse}->{ItemId}->{ItemIdentifierType}->{text},
	'Item Barcode',
	'AcceptItemResponse gives correct ItemIdentifierType',
    );

    my $item_barcode = $dom->{NCIPMessage}->{AcceptItemResponse}->{ItemId}->{ItemIdentifierValue}->{text};
    ok(
	$item_barcode,
	'AcceptItemResponse gives an ItemIdentifierValue'
    );

    my $item = Koha::Items->find({ barcode => $item_barcode });
    is( ref($item), 'Koha::Item', 'Found item with corrosponding item barcode' );

    my $b = $item->biblio;
    is( $b->frameworkcode, 'FA', 'Bib has correct framework code' );
    is( $b->copyrightdate, '2001', 'Bib has correct copyright date' );
    is( $b->author, 'Guertin, Mike.', 'Bib has correct author' );
    is( $b->title, 'Precision framing', 'Bib has correct title' );

    my $bi = $item->biblioitem;
    is( $bi->publishercode, 'Taunton Press ; Publishers Group West [distributor]', 'Bib has correct publisher' );

    is( $item->homebranch, $patron_1->branchcode, "Item homebranch is set to the patron's branchcode" );
    is( $item->holdingbranch, $patron_1->branchcode, "Item holdingbranch is set to the patron's branchcode" );
};
