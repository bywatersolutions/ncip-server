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
    Log::Log4perl->init($config_dir . "/log4perl.conf");
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
    my $self           = shift;
    my $xml            = shift;
    my ($request_type) = $self->handle_initiation($xml);
    unless ($request_type) {

      # We have invalid xml, or we can't figure out what kind of request this is
      # Handle error here
#        warn "We can't find request type";
        my $output = $self->_error("We can't find request type");
        return $output;
    }
    my $handler = NCIP::Handler->new(
        {
            namespace    => $self->namespace(),
            type         => $request_type,
            ils          => $self->ils,
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
            return;
        }
        my $request_type = $self->parse_request($dom);

        # do whatever we should do to initiate, then hand back request_type
        if ($request_type) {
            $self->{xmldoc} = $dom;
            return $request_type;
        }
    }
    else {
        $log->info("We have no DOM");

        return;
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
        warn "Bad xml, caught error: $_";
        return;
    };

    # we could validate against the dtd here, might be good?
    # my $dtd = XML::LibXML::Dtd->parse_string($dtd_str);
    # $dom->validate($dtd);
    # perhaps we could check the ncip version and validate that too
    return 1;
}

sub parse_request {
    my $self = shift;
    my $dom  = shift;
    my $nodes =
      $dom->getElementsByTagNameNS( $self->namespace(), 'NCIPMessage' );
    if ($nodes) {
        my @childnodes = $nodes->[0]->childNodes();
        if ( $childnodes[1] ) {
            return $childnodes[1]->localname();
        }
        else {
            warn "Got a node, but no child node";
            return;
        }
    }
    else {
        warn "Invalid XML";
        return;
    }
    return;
}

sub _error {
    my $self         = shift;
    my $error_detail = shift;
    my $vars;
    $vars->{'error_detail'} = $error_detail;
    $vars->{'messagetype'} = 'ItemRequestedResponse'; # No idea what this type should be 
    my $template = Template->new(
        { INCLUDE_PATH => $self->config->('NCIP.templates.value'), } );
    my $output;
    $template->process( 'problem.tt', $vars, \$output );
    return $output;
}
1;
