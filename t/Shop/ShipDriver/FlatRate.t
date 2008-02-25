# vim:syntax=perl
#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2008 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#------------------------------------------------------------------

# Write a little about what this script tests.
# 
#

use FindBin;
use strict;
use lib "$FindBin::Bin/../../lib";
use Test::More;
use Test::Deep;
use JSON;
use HTML::Form;

use WebGUI::Test; # Must use this before any other WebGUI modules
use WebGUI::Session;

#----------------------------------------------------------------------------
# Init
my $session         = WebGUI::Test->session;

#----------------------------------------------------------------------------
# Tests

my $tests = 28;
plan tests => 1 + $tests;

#----------------------------------------------------------------------------
# put your tests here

my $loaded = use_ok('WebGUI::Shop::ShipDriver::FlatRate');

my $storage;

SKIP: {

skip 'Unable to load module WebGUI::Shop::ShipDriver::FlatRate', $tests unless $loaded;

#######################################################################
#
# definition
#
#######################################################################

my $definition;

eval { $definition = WebGUI::Shop::ShipDriver::FlatRate->definition(); };
like ($@, qr/^Definition requires a session object/, 'definition croaks without a session object');

$definition = WebGUI::Shop::ShipDriver->definition($session);

cmp_deeply(
    $definition,
    [ {
        name => 'Shipper Driver',
        fields => {
            label => {
                fieldType => 'text',
                label => ignore(),
                hoverHelp => ignore(),
                defaultValue => undef,
            },
            enabled => {
                fieldType => 'yesNo',
                label => ignore(),
                hoverHelp => ignore(),
                defaultValue => 1,
            }
        }
    } ],
    ,
    'Definition returns an array of hashrefs',
);

#######################################################################
#
# create
#
#######################################################################

my $driver;

my $options = {
                label   => 'Slow and dangerous',
                enabled => 1,
              };

$driver = WebGUI::Shop::ShipDriver->create( $session, $options);

isa_ok($driver, 'WebGUI::Shop::ShipDriver::FlatRate');

isa_ok($driver, 'WebGUI::Shop::ShipDriver');


#######################################################################
#
# getName
#
#######################################################################

is ($driver->getName, 'Flat Rate', 'getName returns the human readable name of this driver');

#######################################################################
#
# getEditForm
#
#######################################################################

my $form = $driver->getEditForm;

isa_ok($form, 'WebGUI::HTMLForm', 'getEditForm returns an HTMLForm object');

my $html = $form->print;

##Any URL is fine, really
my @forms = HTML::Form->parse($html, 'http://www.webgui.org');
is (scalar @forms, 1, 'getEditForm generates just 1 form');

my @inputs = $forms[0]->inputs;
is (scalar @inputs, 5, 'getEditForm: the form has 5 controls');

my @interestingFeatures;
foreach my $input (@inputs) {
    my $name = $input->name;
    my $type = $input->type;
    push @interestingFeatures, { name => $name, type => $type };
}

cmp_deeply(
    \@interestingFeatures,
    [
        {
            name => undef,
            type => 'submit',
        },
        {
            name => 'shipperId',
            type => 'hidden',
        },
        {
            name => 'className',
            type => 'hidden',
        },
        {
            name => 'label',
            type => 'text',
        },
        {
            name => 'enabled',
            type => 'radio',
        },
    ],
    'getEditForm made the correct form with all the elements'

);

#######################################################################
#
# delete
#
#######################################################################

$driver->delete;

my $count = $session->db->quickScalar('select count(*) from shipper where shipperId=?',[$driver->shipperId]);
is($count, 0, 'delete deleted the object');

undef $driver;

#######################################################################
#
# calculate
#
#######################################################################

}

#----------------------------------------------------------------------------
# Cleanup
END {
    $session->db->write('delete from shipper');
}
