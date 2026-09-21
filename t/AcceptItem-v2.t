#!/usr/bin/perl

use Modern::Perl;

use Test::More tests => 7;

use Dancer::Test;
use Template;
use XML::Hash;

use lib 'lib';

# From NCIP
use NCIP::Dancing;
use Dancer ':syntax';

# From Koha
use C4::MarcModificationTemplates qw{ AddModificationTemplate AddModificationTemplateAction };
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

subtest 'Test AcceptItem with accept_item_marc_modification_template set' => sub {
    plan tests => 3;

    config->{koha}->{framework} = 'FA';
    config->{koha}->{replacement_price} = undef;
    config->{koha}->{barcode_prefix} = undef;
    config->{koha}->{item_branchcode} = undef;
    config->{koha}->{always_generate_barcode} = undef;
    config->{koha}->{trap_hold_on_accept_item} = undef;
    config->{koha}->{item_callnumber} = undef;
    config->{koha}->{item_itemtype} = undef;
    config->{koha}->{item_ccode} = undef;
    config->{koha}->{item_location} = undef;
    config->{koha}->{accept_item_marc_modification_template} = 'NCIP AcceptItem';

    my $template_id = AddModificationTemplate('NCIP AcceptItem');
    AddModificationTemplateAction(
        $template_id, 'copy_and_replace_field', 0,
        '245',        'a',                      '', '245', 'a',
        'Precision',  'PRECISION',              '',
        '',           '',                       '', '', '', '',
        'Copy and replace field 245$a using RegEx s/Precision/PRECISION/'
    );

    my $ncip_message;
    $tt->process('v2/AcceptItem.xml', {
	patron_cardnumber => $patron_1->cardnumber,
	pickup_location => $library_2->id,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    my $item_barcode = $dom->{NCIPMessage}->{AcceptItemResponse}->{ItemId}->{ItemIdentifierValue}->{text};
    ok(
	$item_barcode,
	'AcceptItemResponse gives an ItemIdentifierValue'
    );

    my $item = Koha::Items->find({ barcode => $item_barcode });
    is( ref($item), 'Koha::Item', 'Found item with corrosponding item barcode' );

    is( $item->biblio->title, 'PRECISION framing', 'Title was modified by the MARC modification template' );
};

subtest 'Test AcceptItem with accept_item_uppercase_fields set' => sub {
    plan tests => 5;

    config->{koha}->{framework} = 'FA';
    config->{koha}->{replacement_price} = undef;
    config->{koha}->{barcode_prefix} = undef;
    config->{koha}->{item_branchcode} = undef;
    config->{koha}->{always_generate_barcode} = undef;
    config->{koha}->{trap_hold_on_accept_item} = undef;
    config->{koha}->{item_callnumber} = undef;
    config->{koha}->{item_itemtype} = undef;
    config->{koha}->{item_ccode} = undef;
    config->{koha}->{item_location} = undef;
    config->{koha}->{accept_item_marc_modification_template} = undef;
    config->{koha}->{accept_item_uppercase_fields} = [ 'biblio.title', '100$a', 'items.itemcallnumber' ];

    my $ncip_message;
    $tt->process('v2/AcceptItem.xml', {
	patron_cardnumber => $patron_1->cardnumber,
	pickup_location => $library_2->id,
	item_callnumber => 'ill fic 694.2',
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    my $item_barcode = $dom->{NCIPMessage}->{AcceptItemResponse}->{ItemId}->{ItemIdentifierValue}->{text};
    ok(
	$item_barcode,
	'AcceptItemResponse gives an ItemIdentifierValue'
    );

    my $item = Koha::Items->find({ barcode => $item_barcode });
    is( ref($item), 'Koha::Item', 'Found item with corrosponding item barcode' );

    my $b = $item->biblio;
    is( $b->title, 'PRECISION FRAMING', 'Title was upper cased via the biblio.title mapping' );
    is( $b->author, 'GUERTIN, MIKE.', 'Author was upper cased via the 100$a entry' );

    is( $item->itemcallnumber, 'ILL FIC 694.2', 'Item callnumber was upper cased via the items.itemcallnumber entry' );
};

subtest 'Test AcceptItem with no author' => sub {
    plan tests => 3;

    config->{koha}->{framework} = 'FA';
    config->{koha}->{replacement_price} = undef;
    config->{koha}->{barcode_prefix} = undef;
    config->{koha}->{item_branchcode} = undef;
    config->{koha}->{always_generate_barcode} = undef;
    config->{koha}->{trap_hold_on_accept_item} = undef;
    config->{koha}->{item_callnumber} = undef;
    config->{koha}->{item_itemtype} = undef;
    config->{koha}->{item_ccode} = undef;
    config->{koha}->{item_location} = undef;
    config->{koha}->{accept_item_marc_modification_template} = undef;
    config->{koha}->{accept_item_uppercase_fields} = undef;

    my $ncip_message;
    $tt->process('v2/AcceptItem.xml', {
	patron_cardnumber => $patron_1->cardnumber,
	pickup_location => $library_2->id,
	no_author => 1,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    my $item_barcode = $dom->{NCIPMessage}->{AcceptItemResponse}->{ItemId}->{ItemIdentifierValue}->{text};
    ok(
	$item_barcode,
	'AcceptItemResponse gives an ItemIdentifierValue'
    );

    my $item = Koha::Items->find({ barcode => $item_barcode });
    my $biblio = $item->biblio;

    is( $biblio->metadata->record->field('100'), undef, 'No 100 field was added for a message without an author' );
    is( $biblio->author, undef, 'The record created has no author' );
};

subtest 'Test AcceptItem with MediumType' => sub {
    plan tests => 4;

    config->{koha}->{framework} = 'FA';
    config->{koha}->{replacement_price} = undef;
    config->{koha}->{barcode_prefix} = undef;
    config->{koha}->{item_branchcode} = undef;
    config->{koha}->{always_generate_barcode} = undef;
    config->{koha}->{trap_hold_on_accept_item} = undef;
    config->{koha}->{item_callnumber} = undef;
    config->{koha}->{item_itemtype} = undef;
    config->{koha}->{item_ccode} = undef;
    config->{koha}->{item_location} = undef;
    config->{koha}->{itemtype_map} = undef;
    config->{koha}->{accept_item_marc_modification_template} = undef;
    config->{koha}->{accept_item_uppercase_fields} = undef;

    # With no itemtype configured, the MediumType value lands in 942$c
    my $ncip_message;
    $tt->process('v2/AcceptItem.xml', {
	patron_cardnumber => $patron_1->cardnumber,
	pickup_location => $library_2->id,
	item_barcode => 'NCIPMEDIUM1',
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );

    my $item = Koha::Items->find({ barcode => 'NCIPMEDIUM1' });
    is( ref($item), 'Koha::Item', 'Found item with corrosponding item barcode' );

    my @medium_itemtypes = grep { defined $_ && length $_ } map { $_->subfield('c') }
        $item->biblio->metadata->record->field('942');
    is_deeply(
	\@medium_itemtypes,
	['Book'], "The MediumType value is in the created record's 942\$c"
    );

    # With an itemtype configured, the itemtype wins over MediumType
    my $itemtype = $builder->build_object({ class => 'Koha::ItemTypes' });
    config->{koha}->{itemtype_map} = { DVD => $itemtype->itemtype };

    my $ncip_message_dvd;
    $tt->process('v2/AcceptItem.xml', {
	patron_cardnumber => $patron_1->cardnumber,
	pickup_location => $library_2->id,
	item_barcode => 'NCIPMEDIUM2',
	format => 'DVD',
    }, \$ncip_message_dvd) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message_dvd } );

    $item = Koha::Items->find({ barcode => 'NCIPMEDIUM2' });
    is( ref($item), 'Koha::Item', 'Found item with corrosponding item barcode' );

    my @itemtypes = grep { defined $_ && length $_ } map { $_->subfield('c') }
        $item->biblio->metadata->record->field('942');
    is_deeply(
	\@itemtypes,
	[ $itemtype->itemtype ],
	"The mapped itemtype is the only 942\$c on the created record, MediumType did not override it"
    );

    config->{koha}->{itemtype_map} = undef;
};
