#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2009 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------


use FindBin;
use strict;
use lib "$FindBin::Bin/lib";
use Tie::IxHash;

use WebGUI::Test;
use WebGUI::Session;

use Test::More tests => 57; # increment this value for each test you create
use Test::Deep;

my $session = WebGUI::Test->session;

# isIn
ok(WebGUI::Utility::isIn("webgui", qw(cars trucks webgui trains)), 'isIn()');


# round
is(WebGUI::Utility::round(47.133984233, 0), 47, 'round() - 0 significant digits');
is(WebGUI::Utility::round(47.133984233, 3), 47.134, 'round() - multiple significant digits');
is(WebGUI::Utility::round(47.6, 0), 48, 'round() - rounds up, too');

{
	# Just some basic tests for now.

	my (%hash1, %hash2, %hash3);
	my %hash1 = ('a' => 5, 'b' => 3, 'c' => 2, 'd' => 4, 'e' => 1);
	tie my %hash2, 'Tie::IxHash';
	tie my %hash3, 'Tie::IxHash';
	%hash2 = WebGUI::Utility::sortHash(%hash1);
	is_deeply([keys %hash2], [qw/e c b d a/], 'sortHash');
}


# isInSubnets
is(WebGUI::Utility::isInSubnet('192.168.0.1', []), 0, 'isInSubnet: comparing against an empty array ref');
is(WebGUI::Utility::isInSubnet('192.168.0.1', ['192.168.0.1/32']), 1, 'isInSubnet: comparing against an exact match');
is(WebGUI::Utility::isInSubnet('192.168.0.2', ['192.168.0.1/32']), 0, 'isInSubnet: comparing against a mismatch');
is(WebGUI::Utility::isInSubnet('192.168.0.2', ['192.168.0.1/30']), 1, 'isInSubnet: comparing against a match with mask');
is(WebGUI::Utility::isInSubnet('256.168.0.2', ['192.168.0.1/30']), 0, 'isInSubnet: ip is out of range');
is(WebGUI::Utility::isInSubnet('192.168.0.1', ['192.168.0.1/33']), undef, 'isInSubnet: mask is out of range');
is(WebGUI::Utility::isInSubnet('192.168.0.1', ['192.168.0.0.1/33']), undef, 'isInSubnet: ip has too many dots');
is(WebGUI::Utility::isInSubnet('192.168.0.1', ['0.0.1/33']), undef, 'isInSubnet: ip has too few dots');
is(WebGUI::Utility::isInSubnet('192.168.0.1', ['192.168.0.1']), undef, 'isInSubnet: ip is missing mask');
is(WebGUI::Utility::isInSubnet('192.168.0.1', ['256.168.0.1/32']), undef, 'isInSubnet: ip has an out of range quad');
is(WebGUI::Utility::isInSubnet('192.168.0.1', ['192.257.0.1/32']), undef, 'isInSubnet: ip has an out of range quad');
is(WebGUI::Utility::isInSubnet('192.168.0.1', ['192.168.258.1/32']), undef, 'isInSubnet: ip has an out of range quad');
is(WebGUI::Utility::isInSubnet('192.168.0.1', ['192.168.0.259/32']), undef, 'isInSubnet: ip has an out of range quad');

TODO: {
    local $TODO = 'Things to do';
    ok(0, 'Move email validation tests out of Form/Email into here');
}

# Local variables:
# mode: cperl
# End:
