package WebGUI::Style;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2003 Plain Black LLC.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut


use strict;
use Tie::CPHash;
use WebGUI::Session;
use WebGUI::SQL;
use WebGUI::Template;


=head1 NAME

Package WebGUI::Style

=head1 DESCRIPTION

This package contains utility methods for WebGUI's style system.

=head1 SYNOPSIS

 use WebGUI::Style;
 $template = WebGUI::Style::getTemplate();
 $html = WebGUI::Style::process($content);

=head1 SUBROUTINES 

These subroutines are available from this package:

=cut


#-------------------------------------------------------------------

=head2 getTemplate ( [ templateId ] )

Retrieves the template for this style.

=over

=item templateId

The unique identifier for the template to retrieve. Defaults to the style template tied to the current page.

=back

=cut

sub getTemplate {
	my $templateId = shift || $session{page}{styleId};
	return WebGUI::Template::get($templateId,"style");
}


#-------------------------------------------------------------------

=head2 process ( content [ , templateId ] )

Returns a parsed style with content based upon the current WebGUI session information.

=over

=item content

The content to be parsed into the style. Usually generated by WebGUI::Page::generate().

=item templateId

The unique identifier for the template to retrieve. Defaults to the style template tied to the current page.

=back

=cut

sub process {
	my %var;
	$var{'body.content'} = shift;
	my $templateId = shift;
	if ($session{page}{makePrintable}) {
		$templateId = $session{page}{printableStyleId};
	} elsif ($session{page}{useAdminStyle} ne "" && $session{setting}{useAdminStyle}) {
		$templateId = $session{setting}{adminStyleId};
	} elsif ($session{scratch}{personalStyleId} ne "") {
		$templateId = $session{scratch}{personalStyleId};
	}
        my $type = lc($session{setting}{siteicon});
        $type =~ s/.*\.(.*?)$/$1/;
	$var{'head.tags'} = '
		<meta name="generator" content="WebGUI '.$WebGUI::VERSION.'" />
		<meta http-equiv="Content-Type" content="text/html; charset='.($session{header}{charset}||$session{language}{characterSet}||"ISO-8859-1").'" />
		<link rel="icon" href="'.$session{setting}{siteicon}.'" type="image/'.$type.'" />
		<link rel="SHORTCUT ICON" href="'.$session{setting}{favicon}.'" />
		'.$session{page}{head}{raw};
        # generate additional link tags
	foreach my $url (keys %{$session{page}{head}{link}}) {
		$var{'head.tags'} .= '<link href="'.$url.'"';
		foreach my $name (keys %{$session{page}{head}{link}{$url}}) {
			$var{'head.tags'} .= ' '.$name.'="'.$session{page}{head}{link}{$url}{$name}.'"';
		}
		$var{'head.tags'} .= ' />'."\n";
	}
	# generate additional javascript tags
	foreach my $url (keys %{$session{page}{head}{javascript}}) {
		$var{'head.tags'} .= '<script src="'.$url.'"';
		foreach my $name (keys %{$session{page}{head}{javascript}{$url}}) {
			$var{'head.tags'} .= ' '.$name.'="'.$session{page}{head}{javascript}{$url}{$name}.'"';
		}
		$var{'head.tags'} .= '></script>'."\n";
	}
	# generate additional meta tags
	foreach my $tag (@{$session{page}{head}{meta}}) {
		$var{'head.tags'} .= '<meta';
		foreach my $name (keys %{$tag}) {
			$var{'head.tags'} .= ' '.$name.'="'.$tag->{$name}.'"';
		}
		$var{'head.tags'} .= ' />'."\n";
	}
	$var{'head.tags'} .= $session{page}{metaTags};
	if ($session{var}{adminOn}) {
                # This "triple incantation" panders to the delicate tastes of various browsers for reliable cache suppression.
		$var{'head.tags'} .= '
                	<meta http-equiv="Pragma" content="no-cache" />
                	<meta http-equiv="Cache-Control" content="no-cache, must-revalidate, max_age=0" />
                	<meta http-equiv="Expires" content="0" />
			';
        }
	if ($session{page}{defaultMetaTags}) {
 		$var{'head.tags'} .= '
			<meta http-equiv="Keywords" name="Keywords" content="'.$session{page}{title}.', '.$session{setting}{companyName}.'" />
			';
                if ($session{page}{synopsis}) {
                        $var{'head.tags'} .= '
				<meta http-equiv="Description" name="Description" content="'.$session{page}{synopsis}.'" />
				';
                }
        }
	return WebGUI::Template::process(getTemplate($templateId),\%var);
}	



1;

