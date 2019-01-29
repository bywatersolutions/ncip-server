#!/usr/bin/perl

use Modern::Perl;

use Test::More tests => 8;

use Dancer::Test;
use Template;
use XML::Hash;

use lib 'lib';

# From NCIP
use NCIP::Dancing;
use Dancer ':syntax';

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

my $tt = Template->new({
    INCLUDE_PATH => 't/templates',
    INTERPOLATE  => 1,
}) || die "$Template::ERROR\n";

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
            BlockExpiredPatronOpacActions => -1,    # Pick the pref value
        }
    }
);
my $user_password = 'Th3 Tr$th 1s 0u7 7h3r3';
my $patron_1 = $builder->build_object(
    {
        class => 'Koha::Patrons',
        value => {
            surname      => 'Hall',
            firstname    => 'Kyle',
            categorycode => $patron_category->{categorycode},
            dateexpiry   => '2032-12-31',
	    password     => $user_password,
        }
    }
);
$patron_1->set_password( { password => $user_password, skip_validation => 1 } );

my $lookupuser;
$tt->process('v1/LookupUser.xml', {
    user_identifier => $patron_1->cardnumber,
    user_password   => $user_password,
}, \$lookupuser) || die $tt->error(), "\n";

### Set defaults ###
config->{koha}->{lookup_user_id}     = 'cardnumber';
config->{koha}->{format_ValidToDate} = undef;

subtest 'LookupUser: Test setting "lookup_user_id"' => sub {
    plan tests => 6;

    $response = dancer_response( POST => '/', { body => $lookupuser } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );
    is(
        $dom->{NCIPMessage}->{LookupUserResponse}->{UniqueUserId}->{UserIdentifierValue}->{text},
        $patron_1->cardnumber,
        'LookupUserResponse returns cardnumber for lookup_user_id => cardnumber'
    );
    is(
        $dom->{NCIPMessage}->{LookupUserResponse}->{UserOptionalFields}
          ->{NameInformation}->{PersonalNameInformation}
          ->{StructuredPersonalUserName}->{GivenName}->{text},
        'Kyle', 'LookupUserResponse has correct first name'
    );
    is(
        $dom->{NCIPMessage}->{LookupUserResponse}->{UserOptionalFields}
          ->{NameInformation}->{PersonalNameInformation}
          ->{StructuredPersonalUserName}->{Surname}->{text},
        'Hall', 'LookupUserResponse has correct last name'
    );
    is(
        $dom->{NCIPMessage}->{LookupUserResponse}->{UserOptionalFields}
          ->{UserPrivilege}->[2]->{ValidToDate}->{text},
        '2032-12-31',
        'LookupUserResponse has correct ValidToDate date and default format'
    );

    config->{koha}->{lookup_user_id} = 'userid';
    $response = dancer_response( POST => '/', { body => $lookupuser } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );
    is(
        $dom->{NCIPMessage}->{LookupUserResponse}->{UniqueUserId}->{UserIdentifierValue}->{text},
        $patron_1->userid,
        'LookupUserResponse returns userid for lookup_user_id => userid'
    );

    config->{koha}->{lookup_user_id} = 'same';
    $response = dancer_response( POST => '/', { body => $lookupuser } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );
    is(
        $dom->{NCIPMessage}->{LookupUserResponse}->{UniqueUserId}->{UserIdentifierValue}->{text},
        $patron_1->cardnumber,
	'LookupUserResponse returns cardnumber for lookup_user_id => same, cardnumber sent in query'
    );

    # Reset lookup_user_id
    config->{koha}->{lookup_user_id} = 'cardnumber';
};

subtest 'LookupUser: Test setting "format_ValidToDate"' => sub {
    plan tests => 1;

    config->{koha}->{format_ValidToDate} = '%Y-%d-%mT%H-%M-%S';
    $response = dancer_response( POST => '/', { body => $lookupuser } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );
    is(
        $dom->{NCIPMessage}->{LookupUserResponse}->{UserOptionalFields}
          ->{UserPrivilege}->[2]->{ValidToDate}->{text},
        '2032-31-12T00-00-00',
        'LookupUserResponse has correct ValidToDate date and default format'
    );

    # Reset format_ValidToDate
    config->{koha}->{format_ValidToDate} = undef;
};

subtest 'Test ability to strip DOCTYPE lines' => sub {
    plan tests => 4;

    # Minify xml
    $lookupuser =~ s/>\s+</></g;
    $lookupuser =~ s/[\r\n]+$//g;
    #print "MINIFIED LookupUser: $lookupuser\n";

    $response = dancer_response( POST => '/', { body => $lookupuser } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );
    is(
        $dom->{NCIPMessage}->{LookupUserResponse}->{UniqueUserId}->{UserIdentifierValue}->{text},
        $patron_1->cardnumber,
        'LookupUserResponse returns cardnumber for lookup_user_id => cardnumber with DOCTYPE in message'
    );
    is(
        $dom->{NCIPMessage}->{LookupUserResponse}->{UserOptionalFields}
          ->{NameInformation}->{PersonalNameInformation}
          ->{StructuredPersonalUserName}->{GivenName}->{text},
        'Kyle', 'LookupUserResponse has correct first name with DOCTYPE in message'
    );
    is(
        $dom->{NCIPMessage}->{LookupUserResponse}->{UserOptionalFields}
          ->{NameInformation}->{PersonalNameInformation}
          ->{StructuredPersonalUserName}->{Surname}->{text},
        'Hall', 'LookupUserResponse has correct last name with DOCTYPE in message'
    );
    is(
        $dom->{NCIPMessage}->{LookupUserResponse}->{UserOptionalFields}
          ->{UserPrivilege}->[2]->{ValidToDate}->{text},
        '2032-12-31',
        'LookupUserResponse has correct ValidToDate date and default format with DOCTYPE in message'
    );
};
