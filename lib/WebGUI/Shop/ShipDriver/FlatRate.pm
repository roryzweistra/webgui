package WebGUI::Shop::ShipDriver::FlatRate;

use strict;
use base qw/WebGUI::Shop::ShipDriver/;

=head1 NAME

Package WebGUI::Shop::ShipDriver::FlatRate

=head1 DESCRIPTION

This Shipping driver allows for calculating shipping costs without any
tie-ins to external shippers.

=head1 SYNOPSIS

=head1 METHODS

See the master class, WebGUI::Shop::ShipDriver for information about
base methods.  These methods are customized in this class:

=cut

#-------------------------------------------------------------------

=head2 calculate ( $cart )

Returns a shipping price. Calculates the shipping price using the following formula:

    total price of shippable items * percentageOfPrice
    + flatFee
    + total weight of shippable items * pricePerWeight
    + total quantity of shippable items * pricePerItem

=head3 $cart

A WebGUI::Shop::Cart object.  The contents of the cart are analyzed to calculate
the shipping costs.

=cut

sub calculate {
    my $self = shift;
    return;
}

#-------------------------------------------------------------------

=head2 definition ( $session )

This subroutine returns an arrayref of hashrefs, used to validate data put into
the object by the user, and to automatically generate the edit form to show
the user.

=cut

sub definition {
    my $class      = shift;
    my $session    = shift;
    croak "Definition requires a session object"
        unless ref $session eq 'WebGUI::Session';
    my $definition = shift || [];
    my $i18n = WebGUI::International->new($session, 'ShipDriver');
    tie my %properties, 'Tie::IxHash';
    %properties = (
        name => 'Flat Rate',
        fields => {
            flatFee => {
                fieldType    => 'float',
                label        => $i18n->get('flatFee'),
                hoverHelp    => $i18n->get('flatFee help'),
                defaultValue => 0,
            },
            percentageOfPrice => {
                fieldType    => 'float',
                label        => $i18n->get('percentageOfPrice'),
                hoverHelp    => $i18n->get('percentageOfPrice help'),
                defaultValue => 0,
            },
            pricePerWeight => {
                fieldType    => 'float',
                label        => $i18n->get('pricePerWeight'),
                hoverHelp    => $i18n->get('pricePerWeight help'),
                defaultValue => 0,
            },
            pricePerItem => {
                fieldType    => 'float',
                label        => $i18n->get('pricePerItem'),
                hoverHelp    => $i18n->get('pricePerItem help'),
                defaultValue => 0,
            },
        },
    );
    push @{ $definition }, \%properties;
    return $class->SUPER::definition($session, $definition);
}

1;
