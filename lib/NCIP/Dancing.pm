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
    my $log  = Log::Log4perl->get_logger("NCIP");

    $log->debug("****************************** INCOMING REQUEST ******************************");
    $log->debug("REQUEST: " . request->to_string() );
    $log->debug("METHOD: " . request->method() );
    $log->debug("HEADERS: " . Data::Dumper::Dumper( request->headers()->as_string ) );
    $log->debug("PARAMS: " . Data::Dumper::Dumper( scalar params ) );
    $log->debug("BODY: " . Data::Dumper::Dumper( request->body ) );

    my $token = params->{token};
    my $require_token = C4::Context->preference('NcipRequireToken');
    $log->debug("RETURNING. TOKEN REQUIRED BUT NOT PROVIDED") && return "It works!" if $require_token && !$token;
    $log->debug("RETURNING. TOKEN $token DOES NOT MATCH" . C4::Context->preference('NcipToken') ) && return "It works!" if $token && $token ne C4::Context->preference('NcipToken');

    my $appdir = realpath("$FindBin::Bin/..");

    #FIXME: Why are we always looking in t for the config, even for production?
    my $ncip = NCIP->new("$appdir/t/config_sample");


    my $xml = q{};

    $xml = param 'xml';
    $log->debug("XML FOUND IN PARAM xml?: " . ( $xml ? 'yes' : 'no' ) );

    $xml ||= param 'XForms:Model';
    $log->debug("XML FOUND IN PARAM XForms:Model?: " . ( $xml ? 'yes' : 'no' ) );

    $xml ||= request->body;
    $log->debug("XML FOUND IN BODY?: " . ( $xml ? 'yes' : 'no' ) );

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
