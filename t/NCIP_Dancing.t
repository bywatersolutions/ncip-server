#!/usr/bin/perl

use Modern::Perl;

use Test::More tests => 3;

use Dancer::Test;
use Log::Log4perl;
use Template;
use XML::Hash;

use lib 'lib';

# From NCIP
use NCIP::Dancing;
use Dancer ':syntax';

# From Koha
use t::lib::Mocks;

my $dom_converter = XML::Hash->new();

my $tt = Template->new({
    INCLUDE_PATH => 't/templates',
    INTERPOLATE  => 1,
}) || die "$Template::ERROR\n";

my $ncip_message;
$tt->process('v2/LookupVersion.xml', {}, \$ncip_message) || die $tt->error(), "\n";

t::lib::Mocks::mock_preference( 'NcipRequireToken', 1 );
t::lib::Mocks::mock_preference( 'NcipToken',        'S3CR3T' );

subtest 'Request with no token is rejected when a token is required' => sub {
    plan tests => 1;

    set_log_level_to_info();
    my $response = dancer_response( POST => '/', { body => $ncip_message } );

    is( $response->content, 'It works!', 'No NCIP response is returned when the required token is missing' );
};

subtest 'Request with the wrong token is rejected' => sub {
    plan tests => 1;

    set_log_level_to_info();
    my $response = dancer_response( POST => '/N0TS3CR3T', { body => $ncip_message } );

    is( $response->content, 'It works!', 'No NCIP response is returned when the token does not match' );
};

subtest 'Request with the correct token is processed' => sub {
    plan tests => 1;

    set_log_level_to_info();
    my $response = dancer_response( POST => '/S3CR3T', { body => $ncip_message } );
    my $dom      = $dom_converter->fromXMLStringtoHash( $response->content );

    ok( $dom->{NCIPMessage}->{LookupVersionResponse}, 'A LookupVersionResponse is returned when the token matches' );
};

# The token checks must work at any log level. NCIP->new() re-initializes Log4perl
# from t/config_sample/log4perl.conf ( DEBUG ) for every request it processes,
# so the level is set again before each request.
sub set_log_level_to_info {
    Log::Log4perl->init(
        \q{
log4perl.rootLogger             = INFO, SCREEN
log4perl.appender.SCREEN        = Log::Log4perl::Appender::Screen
log4perl.appender.SCREEN.stderr = 1
log4perl.appender.SCREEN.layout = Log::Log4perl::Layout::SimpleLayout
}
    );
}
