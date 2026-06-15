#!/usr/bin/perl

use Modern::Perl;

use Test::More tests => 1;

use Dancer::Test;
use Template;
use XML::Hash;

use lib 'lib';

# From NCIP
use NCIP::Dancing;
use NCIP::Const;
use Dancer ':syntax';

my $dom_converter = XML::Hash->new();

my $tt = Template->new({
    INCLUDE_PATH => 't/templates',
    INTERPOLATE  => 1,
}) || die "$Template::ERROR\n";

my $response;
my $dom;

subtest 'Test LookupVersion returns the supported versions' => sub {
    plan tests => 2;

    my $ncip_message;
    $tt->process('v2/LookupVersion.xml', {}, \$ncip_message) || die $tt->error(), "\n";

    $response = dancer_response( POST => '/', { body => $ncip_message } );
    $dom = $dom_converter->fromXMLStringtoHash( $response->content );

    my $versions = $dom->{NCIPMessage}->{LookupVersionResponse}->{VersionSupported};

    # XML::Hash returns an arrayref when there is more than one element
    my @supported = map { $_->{text} =~ s/^\s+|\s+$//gr } @{$versions};

    is(
        scalar @supported,
        scalar( () = NCIP::Const::SUPPORTED_VERSIONS ),
        'LookupVersionResponse returns one VersionSupported per supported version'
    );
    ok(
        ( grep { $_ eq 'http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd' } @supported ),
        'LookupVersionResponse advertises the NCIP v2.02 schema'
    );
};
