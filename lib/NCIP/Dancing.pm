package NCIP::Dancing;

use Cwd qw/realpath/;
use Dancer ':syntax';
use FindBin;
use Log::Log4perl;
use XML::Tidy::Tiny qw(xml_tidy);
use XML::Tidy;
use Try::Tiny;

use C4::Context;

use NCIP;

our $VERSION = '0.1';

any [ 'get', 'post' ] => '/' => \&process_ncip_request;

any [ 'get', 'post' ] => '/:token' => \&process_ncip_request;

sub process_ncip_request {
    my $token = params->{token};
    my $require_token = C4::Context->preference('NcipRequireToken');
    return "It works!" if $require_token && !$token;
    return "It works!" if $token && $token ne C4::Context->preference('NcipToken');

    my $appdir = realpath("$FindBin::Bin/..");

    #FIXME: Why are we always looking in t for the config, even for production?
    my $ncip = NCIP->new("$appdir/t/config_sample");
    my $log  = Log::Log4perl->get_logger("NCIP");

    $log->debug("MESSAGE INCOMING");
    $log->debug("INCOMING PARAMS: " . Data::Dumper::Dumper( scalar params ) );

    my $xml = param 'xml';
    $xml ||= param 'XForms:Model';
    if ( !$xml && request->is_post ) {
        $xml = request->body;
    }

    $xml ||= q{};
    $log->debug("RAW XML: **$xml**");

    # Gets rid of DOCTYPE stanzas, our parser chokes on them
    $xml =~ s/<!DOCTYPE[^>[]*(\[[^]]*\])?>//g;

    # Tidy's and validates XML.
    try {
        $xml = XML::Tidy->new( xml  => $xml )->tidy()->toString() if $xml;
    } catch {
        $log->debug("ERROR FORMATTING XML: $_");
    };
    $log->debug("FORMATTED: $xml");

    my $content;
    try {
        $content = $ncip->process_request( $xml, config );
    } catch {
        $log->debug("ERROR PROCESSING REQUEST: $_");
    };
    $content ||= "It works!"; # No NCIP message was passed in

    $log->debug("NCIP::Dancing: Finished processing request");
    $log->debug("NCIP::Dancing: About to generate XML response");

    my $xml_response = template 'main', { content => $content, ncip_version => $ncip->{ncip_protocol_version} };
    $xml_response = xml_tidy($xml_response);

    $log->debug("XML RESPONSE: \n$xml_response");

    return $xml_response;
};

true;
