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
use Koha::Items;
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

my $library = Koha::Libraries->search()->next();

my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->id } } );
config->{koha}->{userenv_borrowernumber} = $librarian->id;

subtest 'Test DeleteItem with a valid item' => sub {
    plan tests => 2;

    my $item    = $builder->build_sample_item( { library => $library->id } );
    my $barcode = $item->barcode;

    my $ncip_message;
    $tt->process('v2/DeleteItem.xml', {
        item_identifier => $barcode,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is(
        $dom->{NCIPMessage}->{DeleteItemResponse}->{UniqueItemId}->{ItemIdentifierValue}->{text},
        $barcode,
        'DeleteItemResponse returns correct item barcode'
    );
    is(
        Koha::Items->find( { barcode => $barcode } ),
        undef,
        'Item has actually been deleted from the catalog'
    );
};

subtest 'Test DeleteItem with an invalid item' => sub {
    plan tests => 4;

    my $barcode = 'This Is A Barcode That Does Not Exist';

    my $ncip_message;
    $tt->process('v2/DeleteItem.xml', {
        item_identifier => $barcode,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is(
        $dom->{NCIPMessage}->{DeleteItemResponse}->{Problem}->{ProblemType}->{text},
        'Unknown Item',
        'DeleteItemResponse returns correct problem type for an unknown item'
    );
    is(
        $dom->{NCIPMessage}->{DeleteItemResponse}->{Problem}->{ProblemDetail}->{text},
        'Item is not known.',
        'DeleteItemResponse returns correct problem detail for an unknown item'
    );
    is(
        $dom->{NCIPMessage}->{DeleteItemResponse}->{Problem}->{ProblemElement}->{text},
        'UniqueItemIdentifier',
        'DeleteItemResponse returns correct problem element for an unknown item'
    );
    is(
        $dom->{NCIPMessage}->{DeleteItemResponse}->{Problem}->{ProblemValue}->{text},
        $barcode,
        'DeleteItemResponse returns correct problem value for an unknown item'
    );
};
