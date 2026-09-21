#!/usr/bin/perl

use Modern::Perl;

use Test::More tests => 1;

use Dancer::Test;
use Template;

use lib 'lib';

# From NCIP
use NCIP::Dancing;
use Dancer ':syntax';

# From Koha
use t::lib::Mocks;

my $tt = Template->new({
    INCLUDE_PATH => 't/templates',
    INTERPOLATE  => 1,
}) || die "$Template::ERROR\n";

my $ncip_message;
$tt->process('v2/LookupVersion.xml', {}, \$ncip_message) || die $tt->error(), "\n";

t::lib::Mocks::mock_preference( 'NcipRequireToken', 0 );

subtest 'The first request a worker handles is logged' => sub {
    plan tests => 1;

    # Nothing has initialized Log4perl in this process yet, just like a fresh worker
    my $stderr = q{};
    {
        open my $capture, '>', \$stderr or die "Could not capture STDERR: $!";
        local *STDERR = $capture;
        dancer_response( POST => '/', { body => $ncip_message } );
    }

    like( $stderr, qr/INCOMING REQUEST/, 'Log4perl is initialized in time to log the first request' );
};
