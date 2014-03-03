package NCIP::Handler::LookupUser;

=head1

  NCIP::Handler::LookupUser

=head1 SYNOPSIS

    Not to be called directly, NCIP::Handler will pick the appropriate Handler 
    object, given a message type

=head1 FUNCTIONS

=cut

use Modern::Perl;

use NCIP::Handler;
use NCIP::User;

our @ISA = qw(NCIP::Handler);

sub handle {
    my $self   = shift;
    my $xmldoc = shift;
    if ($xmldoc) {

        # Given our xml document, lets find our userid
        my ($user_id) =
          $xmldoc->getElementsByTagNameNS( $self->namespace(),
            'UserIdentifierValue' );
        my $xpc = XML::LibXML::XPathContext->new;
        $xpc->registerNs( 'ns', $self->namespace() );
        unless ($user_id) {

            # We may get a password, username combo instead of userid
            # Need to deal with that also
            my $root = $xmldoc->documentElement();
            my @authtypes =
              $xpc->findnodes( '//ns:AuthenticationInput', $root );
            my $barcode;
            my $pin;
            foreach my $node (@authtypes) {
                my $class =
                  $xpc->findnodes( './ns:AuthenticationInputType', $node );
                my $value =
                  $xpc->findnodes( './ns:AuthenticationInputData', $node );
                if ( $class->[0]->textContent eq 'Barcode Id' ) {
                    $barcode = $value->[0]->textContent;
                }
                elsif ( $class->[0]->textContent eq 'PIN' ) {
                    $pin = $value->[0]->textContent;
                }

            }
            $user_id = $barcode;
        }
        else {
            $user_id = $user_id->textContent();
        }

        # We may get a password, username combo instead of userid
        # Need to deal with that also

        my $user = NCIP::User->new( { userid => $user_id, ils => $self->ils } );
        $user->initialise();
        my $vars;
        
#  this bit should be at a lower level

        my ($from,$to) = $self->get_agencies($xmldoc); 
        
        # we switch these for the templates
        # because we are responding, to becomes from, from becomes to
        $vars->{'fromagency'} = $to;
        $vars->{'toagency'} = $from;

        # if we have blank user, we need to return that
        # and can skip looking for elementtypes
        if ( $user->userdata->{'borrowernumber'} eq '' ) {
            $vars->{'messagetype'}  = 'LookupUserResponse';
            $vars->{'error_detail'} = "Borrower not found";
            my $output = $self->render_output( 'problem.tt', $vars );
            return $output;
        }
        my $elements = $self->get_user_elements($xmldoc);

        #set up the variables for our template
        $vars->{'messagetype'} = 'LookupUserResponse';
        $vars->{'elements'}    = $elements;
        $vars->{'user'}        = $user;
        my $output = $self->render_output( 'response.tt', $vars );
        return $output;

    }
}

1;
