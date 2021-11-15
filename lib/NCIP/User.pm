package NCIP::User;

use base qw(Class::Accessor);

# User Object needs
# Authentication Input
# Block Or Trap
# Date Of Birth
# Name Information
# Previous User Id(s)
# User Address Information
# User Language
# User Privilege
# User Id

# Make accessors for the ones that makes sense
NCIP::User->mk_accessors(qw(userid ils userdata));

sub initialise {
    my ($self) = @_;

    my $ils = $self->ils;

    my ( $userdata, $error ) = $ils->userdata( $self->userid );

    $self->{userdata} = $userdata;
}

sub is_valid {
    my ($self) = @_;

    return $self->{userdata} ? 1 : 0;
}

sub authenticate {
    my ( $self, $params ) = @_;

    my $pin = $params->{pin};

    return 0 unless $pin;

    return $self->ils->authenticate_patron(
        {
            ils_user => $self,
            pin      => $pin
        }
    );
}

1;
