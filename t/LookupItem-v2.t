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
my $item_1  = $builder->build_sample_item( { library => $library->id } );

subtest 'Test LookupItem with a valid item' => sub {
    plan tests => 2;

    my $ncip_message;
    $tt->process('v2/LookupItem.xml', {
        item_identifier => $item_1->barcode,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is(
        $dom->{NCIPMessage}->{LookupItemResponse}->{ItemId}->{ItemIdentifierValue}->{text},
        $item_1->barcode,
        'LookupItemResponse returns correct item barcode'
    );
    # The template wraps the status in whitespace, so trim before comparing
    ( my $circulation_status = $dom->{NCIPMessage}->{LookupItemResponse}->{UserOptionalFields}->{CirculationStatus}->{text} ) =~ s/^\s+|\s+$//g;
    is(
        $circulation_status,
        'Checked In',
        'LookupItemResponse returns the correct circulation status for an available item'
    );
};

subtest 'Test LookupItem with an invalid item' => sub {
    plan tests => 4;

    my $barcode = 'This Is A Barcode That Does Not Exist';

    my $ncip_message;
    $tt->process('v2/LookupItem.xml', {
        item_identifier => $barcode,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is(
        $dom->{NCIPMessage}->{LookupItemResponse}->{Problem}->{ProblemType}->{text},
        'Unknown Item',
        'LookupItemResponse returns correct problem type for an unknown item'
    );
    is(
        $dom->{NCIPMessage}->{LookupItemResponse}->{Problem}->{ProblemDetail}->{text},
        'Item is not known.',
        'LookupItemResponse returns correct problem detail for an unknown item'
    );
    is(
        $dom->{NCIPMessage}->{LookupItemResponse}->{Problem}->{ProblemElement}->{text},
        'ItemIdentifierValue',
        'LookupItemResponse returns correct problem element for an unknown item'
    );
    is(
        $dom->{NCIPMessage}->{LookupItemResponse}->{Problem}->{ProblemValue}->{text},
        $barcode,
        'LookupItemResponse returns correct problem value for an unknown item'
    );
};
