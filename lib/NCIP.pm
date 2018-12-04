package NCIP;
use NCIP::Configuration;
use NCIP::Handler;
use Modern::Perl;
use XML::LibXML;
use Try::Tiny;
use Module::Load;
use Template;
use Log::Log4perl;

use Object::Tiny qw{xmldoc config namespace ils};

our $VERSION           = '0.01';
our $strict_validation = 0;        # move to config file

=head1 NAME
  
    NCIP

=head1 SYNOPSIS

    use NCIP;
    my $nicp = NCIP->new($config_dir);

=head1 FUNCTIONS

=cut

sub new {
    my $proto      = shift;
    my $class      = ref $proto || $proto;
    my $config_dir = shift;
    my $self       = {};
    my $config     = NCIP::Configuration->new($config_dir);
    $self->{config}    = $config;
    $self->{namespace} = $config->('NCIP.namespace.value');
    Log::Log4perl->init( $config_dir . "/log4perl.conf" );

    # load the ILS dependent module
    my $module = 'NCIP::ILS::' . $config->('NCIP.ils.value');
    load $module || die "Can not load ILS module $module";
    my $ils = $module->new( name => $config->('NCIP.ils.value') );
    $self->{'ils'} = $ils;
    return bless $self, $class;

}

=head2 process_request()

 my $response = $ncip->process_request($xml);

=cut

sub process_request {
    my $self   = shift;
    my $xml    = shift;
    my $config = shift;

    my ( $request_type, $ncip_version ) = $self->handle_initiation($xml);
    $self->{ncip_protocol_version} = $ncip_version;

    unless ($request_type) {

      # We have invalid xml, or we can't figure out what kind of request this is
      # Handle error here
        my $output = $self->_error("We can't find request type");
        return $output;
    }

    my $handler = NCIP::Handler->new(
        {
            namespace    => $self->namespace(),
            type         => $request_type,
            ils          => $self->ils,
            config       => $config,
            ncip_version => $ncip_version,
            template_dir => $self->config->('NCIP.templates.value'),
        }
    );

    return $handler->handle( $self->xmldoc );
}

=head2 handle_initiation

=cut

sub handle_initiation {
    my $self = shift;
    my $xml  = shift;
    my $dom;
    my $log = Log::Log4perl->get_logger("NCIP");
    eval { $dom = XML::LibXML->load_xml( string => $xml ); };
    if ($@) {
        $log->info("Invalid xml we can not parse it ");
    }

    if ($dom) {

        # should check validity with validate at this point
        if ( $strict_validation && !$self->validate($dom) ) {

            # we want strict validation, bail out if dom doesnt validate
            #            warn " Not valid xml";

            # throw/log error
            $log->error("INVALID XML DOM!");

            return ( undef, '2' ); # Hard code default of NCIP version 2
        }
        my ( $request_type, $ncip_version ) = $self->parse_request($dom);
        $log->info("REQUEST TYPE: $request_type") if $request_type;
        $log->info("NCIP VERSION: $ncip_version") if $ncip_version;

        # do whatever we should do to initiate, then hand back request_type
        if ($request_type) {
            $self->{xmldoc} = $dom;
            return ( $request_type, $ncip_version );
        }
    }
    else {
        $log->info("We have no DOM");

        return ( undef, '2' ); # Hard code default of NCIP version 2
    }
}

sub validate {

    # this should perhaps be in it's own module
    my $self = shift;
    my $dom  = shift;
    try {
        $dom->validate();
    }
    catch {
        return;
    };

    # we could validate against the schema here, might be good?
    # my $schema = XML::LibXML::Schema->new(string => $schema_str);
    # eval { $schema->validate($dom); }
    # perhaps we could check the ncip version and validate that too
    return 1;
}

sub parse_request {
    my $self = shift;
    my $dom  = shift;
    my $nodes =
      $dom->getElementsByTagName( 'NCIPMessage' );

    if ($nodes) {
        my $version = 1;
        if  ($nodes->[0]->hasAttributeNS($self->namespace(), 'version')) {
            $version = index($nodes->[0]->getAttributeNS($self->namespace(), 'version'), 'v2') != -1 ? 2 : 1;
        }
        elsif ($nodes->[0]->hasAttribute('version')) {
            $version = index($nodes->[0]->getAttribute('version'), 'v2') != -1 ? 2 : 1;
        }

        my @childnodes = $nodes->[0]->childNodes();
        # The message tag ( e.g. <LookupUser> ) location changes based on line breaks
        # so we need to check the first and second nodes to see where it is.
        # Weird, right?
        if ( $childnodes[0] && $childnodes[0]->localname() ) {
            return ( $childnodes[0]->localname(), $version );
        }
        elsif ( $childnodes[1] && $childnodes[1]->localname() ) {
            return ( $childnodes[1]->localname(), $version );
        }
        else {
            return;
        }
    }
    else {
        return;
    }
    return;
}

sub _error {
    my $self         = shift;
    my $ProblemDetail = shift;
    my $vars;
    $vars->{'ProblemDetail'} = $ProblemDetail;
    $vars->{'message_type'} =
      'ItemRequestedResponse';    # No idea what this type should be
    my $template = Template->new(
        { INCLUDE_PATH => $self->config->('NCIP.templates.value'), } );
    my $output;
    $template->process( 'problem.tt', $vars, \$output );
    return $output;
}
1;
