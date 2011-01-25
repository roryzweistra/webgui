# vim:syntax=perl
#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2009 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#------------------------------------------------------------------

# Test the getUserPrefsForm, editOverrides form and 
# 
#

use FindBin;
use strict;
use lib "$FindBin::Bin/lib";
use Test::More;
use WebGUI::Test; # Must use this before any other WebGUI modules
use WebGUI::Session;
use WebGUI::Test::Mechanize;

#----------------------------------------------------------------------------
# Init
my $session = WebGUI::Test->session;
$session->user({ userId => 3 });

my $page = WebGUI::Test->asset( className => 'WebGUI::Asset::Wobject::Dashboard' );
my $asset = WebGUI::Test->asset(
    className       => 'WebGUI::Asset::Wobject::Article',
    description     => 'Description',
);
my $shortcut = $page->addChild( {
    className       => 'WebGUI::Asset::Shortcut',
    shortcutToAssetId => $asset->getId,
    prefFieldsToShow => 'alias',
} );

#----------------------------------------------------------------------------
# Tests

#----------------------------------------------------------------------------
# getUserPrefsForm
my $mech = WebGUI::Test::Mechanize->new( config => WebGUI::Test->file );
$mech->get_ok( '/' );
$mech->session->user({ userId => 3 });

$mech->get_ok( $shortcut->getUrl( 'func=getUserPrefsForm' ) );
$mech->submit_form_ok( {
    fields => { alias => "myself" },
} );
is( $mech->session->user->get('alias'), "myself", "alias gets set" );

#----------------------------------------------------------------------------
# editOverrides

# form field
my $mech = WebGUI::Test::Mechanize->new( config => WebGUI::Test->file );
$mech->get_ok('/');
$mech->session->user({ userId => 3 });

$mech->get_ok( $shortcut->getUrl( 'func=editOverride;fieldName=title' ) );
$mech->submit_form_ok( {
    fields => { title => "New Title" },
} );
$shortcut = WebGUI::Asset->newById( $mech->session, $shortcut->getId );
my %overrides = $shortcut->getOverrides;
is( $overrides{overrides}{title}{newValue}, "New Title" );

# textarea
my $mech = WebGUI::Test::Mechanize->new( config => WebGUI::Test->file );
$mech->get_ok('/');
$mech->session->user({ userId => 3 });

$mech->get_ok( $shortcut->getUrl( 'func=editOverride;fieldName=description' ) );
$mech->submit_form_ok( {
    fields => { newOverrideValueText => "New" },
} );
$shortcut = WebGUI::Asset->newById( $mech->session, $shortcut->getId );
my %overrides = $shortcut->getOverrides;
is( $overrides{overrides}{description}{newValue}, "New" );


done_testing;
#vim:ft=perl
