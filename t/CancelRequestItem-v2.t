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
use Koha::Holds;
use t::lib::Mocks;
use t::lib::TestBuilder;

my $dom_converter = XML::Hash->new();

my $schema = Koha::Database->schema;
$schema->storage->txn_begin;
my $builder = t::lib::TestBuilder->new;
my $dbh     = C4::Context->dbh;

my $tt = Template->new(
    {
        INCLUDE_PATH => 't/templates',
        INTERPOLATE  => 1,
    }
) || die "$Template::ERROR\n";

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

my $hold = Koha::Hold->new(
    {
        borrowernumber => $patron_1->id,
        biblionumber   => $item_1->biblionumber,
        branchcode     => $library->id,
        priority       => 1,
    }
)->store();

my $module = new Test::MockModule('C4::Context');
$module->mock( 'userenv', sub { { branch => $library->id } } );

subtest 'Test CancelRequestItem with valid user and valid item' => sub {
    plan tests => 2;

    my $ncip_message;
    $tt->process(
        'v2/CancelRequestItem.xml',
        {
            user_identifier   => $patron_1->cardnumber,
            pickup_branchcode => $item_1->holdingbranch,
            request_id        => $hold->id,
        },
        \$ncip_message
    ) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom      = $dom_converter->fromXMLStringtoHash( $response->content );

    my $hold_id = $dom->{NCIPMessage}->{CancelRequestItemResponse}->{RequestId}->{RequestIdentifierValue}->{text};
    is( $hold_id, $hold->id, "RequestItemResponse returned the correct request id" );

    $hold = Koha::Holds->find($hold_id);
    is( $hold, undef, "Hold has been canceled" );
};

subtest 'Test CancelRequestItem with valid user and invalid item' => sub {
    plan tests => 4;

    my $request_id = 'XXX';
    my $ncip_message;
    $tt->process(
        'v2/CancelRequestItem.xml',
        {
            user_identifier   => $patron_1->cardnumber,
            pickup_branchcode => $item_1->holdingbranch,
            request_id        => $request_id,
        },
        \$ncip_message
    ) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom      = $dom_converter->fromXMLStringtoHash( $response->content );

    is(
        $dom->{NCIPMessage}->{CancelRequestItemResponse}->{Problem}->{ProblemType}->{text},
        'Unknown Request',
        'Got correct problem type'
    );
    is( $dom->{NCIPMessage}->{CancelRequestItemResponse}->{Problem}->{ProblemElement}->{text},
        'RequestIdentifierValue',
        'Got correct problem element'
    );
    is( $dom->{NCIPMessage}->{CancelRequestItemResponse}->{Problem}->{ProblemValue}->{text},
        $request_id,
        'Got correct problem value'
    );
    is(
        $dom->{NCIPMessage}->{CancelRequestItemResponse}->{Problem}->{ProblemDetail}->{text},
        'Request is not known.',
        'Got correct problem detail'
    );
};
