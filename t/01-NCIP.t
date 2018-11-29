#!/usr/bin/perl

use Modern::Perl;

use Test::More tests => 8;

use Dancer::Test;
use File::Slurp;
use XML::Hash;

use lib 'lib';

# From NCIP
use NCIP::Dancing;

# From Koha
use Koha::Database;
use t::lib::Mocks;
use t::lib::TestBuilder;

my $dom_converter = XML::Hash->new();

use_ok('NCIP');
use_ok('NCIP::Handler');

my $schema = Koha::Database->schema;
$schema->storage->txn_begin;
my $builder = t::lib::TestBuilder->new;
my $dbh     = C4::Context->dbh;

# Start transaction
$dbh->{RaiseError} = 1;

response_status_is [ GET => '/' ], 200, "GET / is found";

my $response;
my $dom;

$response = dancer_response( POST => '/' );
$dom = $dom_converter->fromXMLStringtoHash( $response->content );
is(
    $dom->{NCIPMessage}->{xmlns},
    'http://www.niso.org/2008/ncip',
    "Got correct default xmlns"
);
is(
    $dom->{NCIPMessage}->{version},
    'http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd',
    "Got correct xml version"
);

my $patron_category = $builder->build(
    {
        source => 'Category',
        value  => {
            category_type                 => 'P',
            enrolmentfee                  => 0,
            BlockExpiredPatronOpacActions => -1,       # Pick the pref value
        }
    }
);
my $patron_1 = $builder->build_object(
    {
        class => 'Koha::Patrons',
        value => {
            surname      => 'Hall',
            firstname    => 'Kyle',
            categorycode => $patron_category->{categorycode},
            cardnumber   => '123456789'
        }
    }
);

my $lookupuser = read_file('t/sample_data/LookupUser.xml') || die "Cant open file";
$response = dancer_response( POST => '/', { body => $lookupuser } );
$dom = $dom_converter->fromXMLStringtoHash( $response->content );
is( $dom->{NCIPMessage}->{LookupUserResponse}->{UserId}->{UserIdentifierValue}->{text}, '123456789', 'LookupUserResponse has correct cardnumber' );
is( $dom->{NCIPMessage}->{LookupUserResponse}->{UserOptionalFields}->{NameInformation}->{PersonalNameInformation}->{StructuredPersonalUserName}->{GivenName}->{text}, 'Kyle', 'LookupUserResponse has correct first name' );
is( $dom->{NCIPMessage}->{LookupUserResponse}->{UserOptionalFields}->{NameInformation}->{PersonalNameInformation}->{StructuredPersonalUserName}->{Surname}->{text}, 'Hall', 'LookupUserResponse has correct last name' );
