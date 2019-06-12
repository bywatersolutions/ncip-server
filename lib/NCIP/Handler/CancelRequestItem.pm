package NCIP::Handler::CancelRequestItem;

=head1

  NCIP::Handler::CancelRequestItem

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
        my $root      = $xmldoc->documentElement();
        my $xpc       = $self->xpc();
        my $userid    = $xpc->findnodes( '//ns:UserIdentifierValue', $root );
        my $requestid = $xpc->findnodes( '//ns:RequestIdentifierValue', $root );

        my $data = $self->ils->cancelrequest($requestid);

        my $elements = $self->get_user_elements($xmldoc);

        if ($data->{success}) {
            return $self->render_output(
                'response.tt',
                {
                    message_type => 'CancelRequestItemResponse',
                    request_id   => $requestid,
                }
            );
        }
        else {
            return $self->render_output(
                'problem.tt',
                {
                    message_type => 'CancelRequestItemResponse',
                    problems     => [
                        {
                            problem_type    => 'Unknown Request',
                            problem_detail  => 'Request is not known.',
                            problem_element => 'RequestIdentifierValue',
                            problem_value   => $requestid,
                        }
                    ]
                }
            );
        }
    }
}

1;
