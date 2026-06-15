#!/usr/bin/perl

use Modern::Perl;

use Test::More tests => 5;
use Test::MockModule;

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
use Koha::CirculationRules;
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

my $librarian = $builder->build_object(
    {
        class => 'Koha::Patrons',
        value => {
            branchcode   => $library->id,
            categorycode => $patron_category->{categorycode},
        }
    }
);
config->{koha}->{userenv_borrowernumber} = $librarian->id;

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

my $item_1 = $builder->build_sample_item( { library => $library->id } );

# AddIssue and AddRenewal need a branch in the userenv
my $module = Test::MockModule->new('C4::Context');
$module->mock( 'userenv', sub { { branch => $library->id, number => $librarian->id } } );

# Make renewals possible by default for this category/itemtype/branch
Koha::CirculationRules->set_rules(
    {
        categorycode => $patron_category->{categorycode},
        itemtype     => $item_1->effective_itemtype,
        branchcode   => $library->id,
        rules        => {
            renewalsallowed => 5,
            renewalperiod   => 7,
            norenewalbefore => undef,
            lengthunit      => 'days',
            issuelength     => 7,
        }
    }
);

subtest 'Test RenewItem with invalid user' => sub {
    plan tests => 4;

    my $cardnumber = 'This Is An Invalid Cardnumber';

    my $ncip_message;
    $tt->process('v2/RenewItem.xml', {
        user_identifier => $cardnumber,
        item_identifier => $item_1->barcode,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is(
        $dom->{NCIPMessage}->{RenewItemResponse}->{Problem}->{ProblemType}->{text},
        'Unknown User',
        'RenewItemResponse returns correct problem type for an unknown user'
    );
    is(
        $dom->{NCIPMessage}->{RenewItemResponse}->{Problem}->{ProblemDetail}->{text},
        'User is not known',
        'RenewItemResponse returns correct problem detail for an unknown user'
    );
    is(
        $dom->{NCIPMessage}->{RenewItemResponse}->{Problem}->{ProblemElement}->{text},
        'UserIdentifierValue',
        'RenewItemResponse returns correct problem element for an unknown user'
    );
    is(
        $dom->{NCIPMessage}->{RenewItemResponse}->{Problem}->{ProblemValue}->{text},
        $cardnumber,
        'RenewItemResponse returns correct problem value for an unknown user'
    );
};

subtest 'Test RenewItem with invalid item' => sub {
    plan tests => 4;

    my $barcode = 'This Is A Barcode That Does Not Exist';

    my $ncip_message;
    $tt->process('v2/RenewItem.xml', {
        user_identifier => $patron_1->cardnumber,
        item_identifier => $barcode,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is(
        $dom->{NCIPMessage}->{RenewItemResponse}->{Problem}->{ProblemType}->{text},
        'Unknown Item',
        'RenewItemResponse returns correct problem type for an unknown item'
    );
    is(
        $dom->{NCIPMessage}->{RenewItemResponse}->{Problem}->{ProblemDetail}->{text},
        'Item is not known.',
        'RenewItemResponse returns correct problem detail for an unknown item'
    );
    is(
        $dom->{NCIPMessage}->{RenewItemResponse}->{Problem}->{ProblemElement}->{text},
        'UniqueItemIdentifier',
        'RenewItemResponse returns correct problem element for an unknown item'
    );
    is(
        $dom->{NCIPMessage}->{RenewItemResponse}->{Problem}->{ProblemValue}->{text},
        $barcode,
        'RenewItemResponse returns correct problem value for an unknown item'
    );
};

subtest 'Test RenewItem with an item that is not checked out' => sub {
    plan tests => 4;

    my $ncip_message;
    $tt->process('v2/RenewItem.xml', {
        user_identifier => $patron_1->cardnumber,
        item_identifier => $item_1->barcode,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is(
        $dom->{NCIPMessage}->{RenewItemResponse}->{Problem}->{ProblemType}->{text},
        'Item Not Checked Out',
        'RenewItemResponse returns correct problem type for an item not checked out'
    );
    is(
        $dom->{NCIPMessage}->{RenewItemResponse}->{Problem}->{ProblemDetail}->{text},
        'There is no record of the check out of the Item.',
        'RenewItemResponse returns correct problem detail for an item not checked out'
    );
    is(
        $dom->{NCIPMessage}->{RenewItemResponse}->{Problem}->{ProblemElement}->{text},
        'UniqueItemIdentifier',
        'RenewItemResponse returns correct problem element for an item not checked out'
    );
    is(
        $dom->{NCIPMessage}->{RenewItemResponse}->{Problem}->{ProblemValue}->{text},
        $item_1->barcode,
        'RenewItemResponse returns correct problem value for an item not checked out'
    );
};

subtest 'Test RenewItem with a valid user and item' => sub {
    plan tests => 3;

    my $issue = C4::Circulation::AddIssue( $patron_1, $item_1->barcode );

    my $ncip_message;
    $tt->process('v2/RenewItem.xml', {
        user_identifier => $patron_1->cardnumber,
        item_identifier => $item_1->barcode,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is(
        $dom->{NCIPMessage}->{RenewItemResponse}->{ItemId}->{ItemIdentifierValue}->{text},
        $item_1->barcode,
        'RenewItemResponse returns correct item barcode'
    );
    is(
        $dom->{NCIPMessage}->{RenewItemResponse}->{UserId}->{UserIdentifierValue}->{text},
        $patron_1->cardnumber,
        'RenewItemResponse returns correct patron cardnumber'
    );
    ok(
        $dom->{NCIPMessage}->{RenewItemResponse}->{DateDue}->{text},
        'RenewItemResponse returns a new date due'
    );

    $issue->discard_changes;
    $issue->delete if $issue->in_storage;
};

subtest 'Test RenewItem when renewals are not allowed' => sub {
    plan tests => 1;

    Koha::CirculationRules->set_rule(
        {
            categorycode => $patron_category->{categorycode},
            itemtype     => $item_1->effective_itemtype,
            branchcode   => $library->id,
            rule_name    => 'renewalsallowed',
            rule_value   => 0,
        }
    );

    my $issue = C4::Circulation::AddIssue( $patron_1, $item_1->barcode );

    my $ncip_message;
    $tt->process('v2/RenewItem.xml', {
        user_identifier => $patron_1->cardnumber,
        item_identifier => $item_1->barcode,
    }, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    is(
        $dom->{NCIPMessage}->{RenewItemResponse}->{Problem}->{ProblemType}->{text},
        'Item Not Renewable',
        'RenewItemResponse returns correct problem type when renewals are not allowed'
    );

    $issue->discard_changes;
    $issue->delete if $issue->in_storage;
};
