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

        # Given our xml document, lets find the itemid
        my ($user_id) =
          $xmldoc->getElementsByTagNameNS( $self->namespace(),
            'UserIdentifierValue' );

        my $user = NCIP::User->new(
            { userid => $user_id->textContent(), ils => $self->ils } );
        $user->initialise();
        my $vars;
        $vars->{'messagetype'} = 'LookupUserResponse';
        $vars->{'user'} = $user;
        my $output = $self->render_output('response.tt',$vars);
        return $output;

    }
}

1;
