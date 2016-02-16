package NCIP::Handler;
#
#===============================================================================
#
#         FILE: Hander.pm
#
#  DESCRIPTION:
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Chris Cormack (rangi), chrisc@catalyst.net.nz
# ORGANIZATION: Koha Development Team
#      VERSION: 1.0
#      CREATED: 19/09/13 10:43:14
#     REVISION: ---
#===============================================================================

# Copyright 2014 Catalyst IT <chrisc@catalyst.net.nz>

# This file is part of NCIPServer
#
# NCIPServer is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# NCIPServer is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with NCIPServer; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

=head1 NAME

    NCIP::Handler

=head1 SYNOPSIS

    use NCIP::Handler;
    my $handler = NCIP::Handler->new( { namespace    => $namespace,
                                        type         => $request_type,
                                        ils          => $ils,
                                        template_dir => $templates
                                       } );

=head1 FUNCTIONS
=cut

use Modern::Perl;
use Object::Tiny qw{ type namespace ils templates };
use Module::Load;
use Template;

=head2 new()

    Set up a new handler object, this will actually create one of the request type
    eg NCIP::Handler::LookupUser

=cut

sub new {
    my $class    = shift;
    my $params   = shift;
    my $subclass = __PACKAGE__ . "::" . $params->{type};
    load $subclass || die "Can't load module $subclass";
    my $self = bless {
        type      => $params->{type},
        namespace => $params->{namespace},
        ils       => $params->{ils},
        templates => $params->{template_dir}
    }, $subclass;
    return $self;
}

=head2 xpc()

    Give back an XPathContext Object, registered to the correct namespace

=cut

sub xpc {
    my $self = shift;
    my $xpc  = XML::LibXML::XPathContext->new;
    $xpc->registerNs( 'ns', $self->namespace() );
    return $xpc;
}

=head2 get_user_elements($xml)

    When passed an xml dom, this will find the user elements and pass convert them into an arrayref

=cut

sub get_user_elements {
    my $self   = shift;
    my $xmldoc = shift;
    my $xpc    = $self->xpc();

    my $root = $xmldoc->documentElement();
    my @elements =
      $xpc->findnodes( '//ns:LookupUser/UserElementType/Value', $root );
    unless ( $elements[0] ) {
        @elements = $xpc->findnodes( '//ns:UserElementType', $root );
    }
    warn "USER ELEMENTS: " . Data::Dumper::Dumper( \@elements );
    return \@elements;
}

sub get_agencies {
    my $self   = shift;
    my $xmldoc = shift;
    my $xpc    = XML::LibXML::XPathContext->new;
    $xpc->registerNs( 'ns', $self->namespace() );

    my $root = $xmldoc->documentElement();

    my $from = $xpc->find( '//ns:FromAgencyId', $root );
    my $to   = $xpc->find( '//ns:ToAgencyId',   $root );
    return ( $from, $to );
}

sub render_output {
    my $self         = shift;
    my $templatename = shift;

    my $vars     = shift;
warn "NAME: $templatename";
warn "INCLUDE PATH: " . $self->templates;
    my $template = Template->new(
        {
            INCLUDE_PATH => $self->templates,
            POST_CHOMP   => 1
        }
    );
    my $output;
    $template->process( $templatename, $vars, \$output ) || do {
    my $error = $template->error();
    print "error type: ", $error->type(), "\n";
    print "error info: ", $error->info(), "\n";
    print $error, "\n";
};
warn "OUTPUT: $output";
    return $output;
}
1;
