package WebGUI::Page;

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


use HTML::Template;
use strict;
use Tie::IxHash;
use WebGUI::ErrorHandler;
use WebGUI::HTMLForm;
use WebGUI::Icon;
use WebGUI::Persistent::Tree;
use WebGUI::Session;
use WebGUI::SQL;
use WebGUI::Template;
use WebGUI::Utility;
use WebGUI::DateTime;
use Data::Serializer;

our @ISA = qw(WebGUI::Persistent::Tree);

=head1 NAME

Package WebGUI::Page

=head1 DESCRIPTION

This package provides utility functions for WebGUI's page system. Some of these work in a
non-object oriented fashion. These are utility functions, not affecting the page tree hiearchy.

The methods that do affect this hiearchy should be called in a object oriented context.

=head1 SYNOPSIS

 Non OO functions
 
 use WebGUI::Page;
 $integer = WebGUI::Page::countTemplatePositions($templateId);
 $html = WebGUI::Page::drawTemplate($templateId);
 $html = WebGUI::Page::generate();
 $hashRef = WebGUI::Page::getTemplateList();
 $template = WebGUI::Page::getTemplate();
 $hashRef = WebGUI::Page::getTemplatePositions($templateId);
 $url = WebGUI::Page::makeUnique($url,$pageId);


 OO style methods

 use WebGUI::Page;
 $page = WebGUI::Page->getPage($pageId);
 $newMother = WebGUI::Page->getPage($anotherPageId);
 $page->cut;
 $page->paste($newMother);

 $page->set;	# this automatically recaches the pagetree

 $page->setWithoutRecache;
 WebGUI::Page->recachePageTree	# here we've got to recache manually

=head1 METHODS

These functions are available from this package:

=cut

#-------------------------------------------------------------------

sub classSettings {
     return { 
	properties => {
		# These fields define the place in the pagetree of a page
		pageId          => { key => 1 },
		parentId        => { defaultValue => 0 },
		sequenceNumber  => { defaultValue => 1 },

		# These are the entries that define the privileges and behaviour of a page.
		# They're in the same order as they apear in the set-statement in the www_editPageSave method 
		# of WebGUI::Operation::Page. Please keep them in this order. You will find it to be more 
		# convient when debugging.
		title			=> { quote => 1 },
		styleId         	=> { defaultValue => 0 },
		printableStyleId 	=> { defaultValue => 0 },
		ownerId         	=> { defaultValue => 0 },
		groupIdView  		=> { defaultValue => 3 },
		groupIdEdit  		=> { defaultValue => 3 },
		newWindow        	=> { defaultValue => 0 },
		wobjectPrivileges	=> { defaultValue => 0 },
		hideFromNavigation 	=> { defaultValue => 0 },
		startDate    		=> { defaultValue => 946710000 },
		endDate      		=> { defaultValue => 2082783600 },
		cacheTimeout		=> { defaultValue => 60},
		cacheTimeoutVisitor 	=> { defaultValue => 600},
		metaTags        	=> { quote => 1 },
		urlizedTitle    	=> { quote => 1 },
		redirectURL		=> { quote => 1 },
		languageId   		=> { defaultValue => 1 },
		defaultMetaTags 	=> { defaultValue => 0 },
		templateId		=> { defaultValue => 1 },
		menuTitle    		=> { quote => 1 },
		synopsis     		=> { quote => 1 },

		# The userdefined database entries.
		userDefined1 => { quote => 1 },
		userDefined2 => { quote => 1 },
		userDefined3 => { quote => 1 },
		userDefined4 => { quote => 1 },
		userDefined5 => { quote => 1 }		
		},
	useDummyRoot => 1,
        table => 'page'
	}
}

#-------------------------------------------------------------------
=head2 add ( page )

Adds page to the children of the object this method is invoked on.

=over

=item page

A WebGUI::Page instance to be added to the children of the current object.

=back

=cut

sub add {
	my ($self, $page, @daughters, $newSequenceNumber);
	($self) = @_;
	
	@daughters = $self->daughters;
	$newSequenceNumber = 1;
	$newSequenceNumber = (pop(@daughters))[0]->get('sequenceNumber') + 1 if (@daughters);
		
	$page = WebGUI::Page->new(-properties => {
		parentId        => $self->get("pageId"),
		sequenceNumber  => $newSequenceNumber
	});
	$self->add_daughter($page);
	$page->set;	
	
	return $page;
}

#-------------------------------------------------------------------

=head2 countTemplatePositions ( templateId ) 

Returns the number of template positions in the specified page template.

=over

=item templateId

The id of the page template you wish to count.

=back

=cut

sub countTemplatePositions {
        my ($template, $i);
        $template = getTemplate($_[0]);
        $i = 1;
        while ($template =~ m/position$i\_loop/) {
                $i++;
        }
        return $i-1;
}

#-------------------------------------------------------------------
=head2 cut

Cuts the this Page object and places it on the clipboard.

=back

=cut
sub cut {
	my ($self, $clipboard, $parentId);
	$self = shift;
	$parentId = $self->get("parentId");
	
	# Place page in clipboard (pageId 2)
	$clipboard = WebGUI::Page->getPage(2);
	$self->get("pageId");

	if ($self->move($clipboard)) {
		$self->set({
			bufferUserId	=> $session{user}{userId},
			bufferDate	=> time,
			bufferPrevId	=> $parentId,
		});
	}

	return $self;
}
	
#-------------------------------------------------------------------
=head2 deCache ( [ pageId ] )

Deletes the cached version of a specified page. Note that this is something else than the 
cached page tree. This funtion should be invoked in a non-OO context;

=over

=item pageId

The id of the page to decache. Defaults to the current page id.

=back

=cut

sub deCache {
	my $cache = WebGUI::Cache->new;
	my $pageId = $_[0] || $session{page}{pageId};
	$cache->deleteByRegex("m/^page_".$pageId."_\\d+\$/");
}

#-------------------------------------------------------------------
=head2 drawTemplate ( templateId )

Returns an HTML string containing a small representation of the page template.

=over

=item templateId

The id of the page template you wish to draw.

=back

=cut

sub drawTemplate {
	my $template = getTemplate($_[0]);
	$template =~ s/\n//g;
	$template =~ s/\r//g;
	$template =~ s/\'/\\\'/g;
	$template = WebGUI::Macro::negate($template);
	$template =~ s/\<script.*?\>.*?\<\/script\>//gi;
	$template =~ s/\<table.*?\>/\<table cellspacing=0 cellpadding=3 width=100 height=80 border=1\>/ig;
	$template =~ s/\<tmpl_loop\s+position(\d+)\_loop\>.*?\<\/tmpl\_loop\>/$1/ig;
	return $template;
}


#-------------------------------------------------------------------

=head2 generate ( )

Generates the content of the page.

=cut

sub generate {
        return WebGUI::Privilege::noAccess() unless (WebGUI::Privilege::canViewPage());
	my %var;
	$var{'page.canEdit'} = WebGUI::Privilege::canEditPage();
        $var{'page.controls'} = pageIcon()
       		.deleteIcon('op=deletePage')
		.editIcon('op=editPage')
		.moveUpIcon('op=movePageUp')
		.moveDownIcon('op=movePageDown')
		.cutIcon('op=cutPage');
	my $sth = WebGUI::SQL->read("select * from wobject where pageId=".$session{page}{pageId}." order by sequenceNumber, wobjectId");
        while (my $wobject = $sth->hashRef) {
		my $wobjectToolbar = wobjectIcon()
         		.deleteIcon('func=delete&wid='.${$wobject}{wobjectId})
              		.editIcon('func=edit&wid='.${$wobject}{wobjectId})
             		.moveUpIcon('func=moveUp&wid='.${$wobject}{wobjectId})
             		.moveDownIcon('func=moveDown&wid='.${$wobject}{wobjectId})
              		.moveTopIcon('func=moveTop&wid='.${$wobject}{wobjectId})
              		.moveBottomIcon('func=moveBottom&wid='.${$wobject}{wobjectId})
            		.cutIcon('func=cut&wid='.${$wobject}{wobjectId})
            		.copyIcon('func=copy&wid='.${$wobject}{wobjectId});
             	if (${$wobject}{namespace} ne "WobjectProxy" && isIn("WobjectProxy",@{$session{config}{wobjects}})) {
             		$wobjectToolbar .= shortcutIcon('func=createShortcut&wid='.${$wobject}{wobjectId});
         	}
       		if (${$wobject}{namespace} eq "WobjectProxy") {
          		my $originalWobject = $wobject;
      			my ($wobjectProxy) = WebGUI::SQL->quickHashRef("select * from WobjectProxy where wobjectId=".${$wobject}{wobjectId});
        		$wobject = WebGUI::SQL->quickHashRef("select * from wobject where wobject.wobjectId=".$wobjectProxy->{proxiedWobjectId});
           		if (${$wobject}{namespace} eq "") {
             			$wobject = $originalWobject;
         		} else {
           			${$wobject}{startDate} = ${$originalWobject}{startDate};
          			${$wobject}{endDate} = ${$originalWobject}{endDate};
          			${$wobject}{templatePosition} = ${$originalWobject}{templatePosition};
             			${$wobject}{_WobjectProxy} = ${$originalWobject}{wobjectId};
           			if ($wobjectProxy->{overrideTitle}) {
             				${$wobject}{title} = ${$originalWobject}{title};
            			}
         			if ($wobjectProxy->{overrideDisplayTitle}) {
           				${$wobject}{displayTitle} = ${$originalWobject}{displayTitle};
           			}
        			if ($wobjectProxy->{overrideDescription}) {
         				${$wobject}{description} = ${$originalWobject}{description};
         			}
         			if ($wobjectProxy->{overrideTemplate}) {
       					${$wobject}{templateId} = $wobjectProxy->{proxiedTemplateId};
       				}
        		}
      		}
                my $cmd = "WebGUI::Wobject::".${$wobject}{namespace};
                my $w = eval{$cmd->new($wobject)};
                WebGUI::ErrorHandler::fatalError("Couldn't instanciate wobject: ${$wobject}{namespace}. Root cause: ".$@) if($@);
		push(@{$var{'position'.$wobject->{templatePosition}.'_loop'}},{
                        'wobject.canView'=>WebGUI::Privilege::canViewWobject($wobject->{wobjectId}),
        		'wobject.canEdit'=>WebGUI::Privilege::canEditWobject($wobject->{wobjectId}),
			'wobject.controls'=>$wobjectToolbar,
			'wobject.controls.drag'=>dragIcon(),
			'wobject.namespace'=>$wobject->{namespace},
			'wobject.id'=>$wobject->{wobjectId},
			'wobject.isInDateRange'=>$w->inDateRange,
			'wobject.content'=>eval{$w->www_view}
			});
		WebGUI::ErrorHandler::fatalError("Wobject runtime error: ${$wobject}{namespace}. Root cause: ".$@) if($@);
	}
	$sth->finish;
	return WebGUI::Template::process(getTemplate(),\%var);
}


#-------------------------------------------------------------------
=head2 getTemplateList

Returns a hash reference containing template ids and template titles for all the page templates available in the system. 

=cut

sub getTemplateList {
	return WebGUI::Template::getList("page");
}

#-------------------------------------------------------------------
=head2 getTemplate ( [ templateId ] )

Returns an HTML template.

=over

=item templateId

The id of the page template you wish to retrieve. Defaults to the current page's template id.

=back

=cut

sub getTemplate {
	my $templateId = $_[0] || $session{page}{templateId};
	return WebGUI::Template::get($templateId,"page");
}

#-------------------------------------------------------------------
=head2 getTemplatePositions ( templateId ) 

Returns a hash reference containing the positions available in the specified page template.

=over

=item templateId

The id of the page template you wish to retrieve the positions from.

=back

=cut

sub getTemplatePositions {
	my (%hash, $template, $i);
	tie %hash, "Tie::IxHash";
	for ($i=1; $i<=countTemplatePositions($_[0]); $i++) {
		$hash{$i} = $i;
	}
	return \%hash;
}

#-------------------------------------------------------------------
=head2 makeUnique ( pageURL, pageId )

Returns a unique page URL.

=over

=item url

The URL you're hoping for.

=item pageId

The page id of the page you're creating a URL for.

=back

=cut

sub makeUnique {
        my ($url, $test, $pageId);
        $url = $_[0];
        $pageId = $_[1] || "new";
        while (($test) = WebGUI::SQL->quickArray("select urlizedTitle from page where urlizedTitle='$url' and pageId<>'$pageId'")) {
                if ($url =~ /(.*)(\d+$)/) {
                        $url = $1.($2+1);
                } elsif ($test ne "") {
                        $url .= "2";
                }
        }
        return $url;
}

#-------------------------------------------------------------------
=head2 getPage ( [pageId] )

This method fetches a WebGUI::Page object. If no pageId is given the current page will be used.

=over

=item pageId

The id of the page requested.

=back

=cut
sub getPage {
	my ($serializer, $cache, $pageLookup, $node, $self, $class, $pageId, $tree);
	($class, $pageId) = @_;
	$pageId ||= $session{page}{pageId};

	WebGUI::ErrorHandler::fatalError("Illegal pageId: '$pageId'") unless ($pageId =~ /^-?\d+$/);
	
	# Only fetch from cache if cache is enabled in the config file
	if ($session{config}{usePageCache}) {
		# Fetch the correct pagetree from cache
		$cache = WebGUI::Cache->new('pageLookup', 'PageTree-'.$session{config}{configFile});
		$pageLookup = $cache->getDataStructure;
		$cache = WebGUI::Cache->new('root-'.$pageLookup->{$pageId},'PageTree-'.$session{config}{configFile});
		$tree = $cache->getDataStructure;
		
		unless (defined $tree) {
			#Handle cache miss. The way it's done here costs twice the amount of time that's needed to build
			#a tree. This shouldn't matter that much, though, since cache-misses should occur almost never.
			WebGUI::Page->recachePageTree;
			$tree = WebGUI::Page->getTree()->{0};
		}
	# No caching
	} else {
		# Do it the diehard way. Just build a complete tree from the database. This will most definately work, but
		# not too fast. A more elegant aproach would be overlaoding every Tree::DAG_Node method WebGUI::Page inherits
		# and dynamically load the data from the db.
		$tree = WebGUI::Page->getTree()->{0};

		# Caching the tree in the session hash might be a good idea, to reduce tree building to only once per session.
		# $session{page}{tree} = $tree;
	}

	# Select the correct node from the tree
	$tree->walk_down({
		callback => sub {
			if ($_[0]->get('pageId') == $pageId) {
				$node = $_[0];
				return 0;
			}
			return 1;
		}});
	return $node;
}

#-------------------------------------------------------------------
=head2 move( newMother )

Moves a page to another page (ie. makes the page you execute this method on a child of newMother).
Returns 1 if the move was succesfull, 0 otherwise.

=over

=item newMother

The page under which the current page should be moved. This should be an WebGUI::Page object.

=back

=cut
sub  move{
	my ($self, $clipboard, $parentId, $newSequenceNumber, @newSisters, $newMother);
	$self = shift;
	$newMother = shift;

	# Avoid cyclic pages. Not doing this will allow people to freeze your computer, by generating infinite loops.
	return 0 if (isIn($self->get("pageId"), map {$_->get("pageId")} $newMother->ancestors));

	# Make sure a page is not moved to itself.
	return 0 if ($self->get("pageId") == $newMother->get("pageId"));
	
	$parentId = $self->get("parentId");
	
	# Lower the sequence numbers of the following sisters
	foreach ($self->right_sisters) {
		$_->setWithoutRecache({
			sequenceNumber => $_->get('sequenceNumber') - 1
			});
	}

	# Derive new sequenceNumber
	@newSisters = $newMother->daughters;
	$newSequenceNumber = 1;
	$newSequenceNumber = $newSisters[scalar(@newSisters)-1]->get('sequenceNumber') +1 if (@newSisters);
	
	# Do the move
	$self->unlink_from_mother;
	$newMother->add_daughter($self);
	$self->set({
		parentId 	=> $newMother->get("pageId"), 
		sequenceNumber 	=> $newSequenceNumber,
	});

	return 1;
}

#-------------------------------------------------------------------
=head2 paste( newMother )

Pastes a page under newMother.

=over

=item newMother

The page under which the current page should be pasted. This should be an WebGUI::Page object.

=back

=cut
sub paste{
	my ($self, $newMother);
	$self = shift;
	$newMother = shift;
	return $self if ($self->get("pageId") == $newMother->get("pageId"));
	return WebGUI::ErrorHandler::fatalError("You cannot paste a page that's not on the clipboard.") unless ($self->get("parentId") == 2);
	
	# Place page in clipboard (pageId 2)
	if ($self->move($newMother)) {
		$self->set({
			bufferUserId	=> 'NULL',
			bufferDate	=> 'NULL',
			bufferPrevId	=> 'NULL'
		});
	}

	return $self;
}

#-------------------------------------------------------------------
=head2 recachePageTree

This method fetches all pageroots from the database, builds their underlying trees and caches them. Additionally
this method creates a lookup table that connects a node to a root. This is done to avoid searching through all 
page tree to find a specific node.

It should only be nescesarry to call this method when setWithoutRecache is used.

=cut
sub recachePageTree {
	my ($forrest, @pageRoots, $currentTree, $serializer, $node, $serialized, $cache, %pageLookup);
	
	# Purge the cached page trees.
	$cache = WebGUI::Cache->new("", "PageTree-".$session{config}{configFile});
	$cache->deleteByRegex(".*");

	# Fetch the complete forrest, which is actually all the pagetrees connected by a dummy root. 
	$forrest = WebGUI::Page->getTree();
	
	@pageRoots = $forrest->{0}->daughters;
	$serializer = Data::Serializer->new(serializer => 'Storable');

	foreach $currentTree (@pageRoots) {
		# Disconnect the tree from the dummy root.
		$currentTree->unlink_from_mother;
		
		# Cache forrest per tree.
		$cache = WebGUI::Cache->new('root-'.$currentTree->get('pageId'),'PageTree-'.$session{config}{configFile});
		$cache->setDataStructure($currentTree);

		# Create URL lookup table.
		$currentTree->walk_down({ 
			callback => sub {
				$_[1]->{_pageLookup}->{$_[0]->get('pageId')} = $_[1]->{_root};
				return 1;
				}, 
			_root => $currentTree->get('pageId'), 
			_pageLookup => \%pageLookup
			}); 
	}

	# Put the lookup table into cache
	$cache = WebGUI::Cache->new('pageLookup','PageTree-'.$session{config}{configFile});
	$cache->setDataStructure(\%pageLookup);
	
	return "";
}

#-------------------------------------------------------------------
=head2 set ( [ data ] )

If data is given, invoking this method will set the object to the state given in data. If called without any arguments
the state of the tree is saved to the database.

A thing to note here is that the cached version of the pagetree is always refreshed after saving to the database. Refreshing
the cache is pretty expensive, so if you have to do many sets in a row, like when recursively changing style of a (sub)tree,
it would be best to use setWithoutRecache, and call recachePageTree afterwards.

=over

=item data

The properties you want to set. This parameter is optional and should be a hashref of the form {propertyA => valueA, propertyB => valueB, etc...}

=back

=cut
sub set {
	my $self = shift;
	my $output = $self->SUPER::set(@_);

	# The very only reason we overload the set method is to make sure that the cache also gets
	# updated. So let's do just that ;). This might be overkill for some situations where only
	# one tree needs to be updated, but doing all of them, sure is a lot safer. (and easier!)
	recachePageTree();

	return $output;
}

#-------------------------------------------------------------------
=head2 setWithoutRecache ([data])

See set. The only difference with set is that the cached version of the pagetree is not updated. This means that you must
update it manually by invoking recachePageTree afterwards.

=over

=item data

The properties you want to set. This parameter is optional and should be a hashref of the form {propertyA => valueA, propertyB => valueB, etc...}

=back

=cut
sub setWithoutRecache {
	my $self = shift;
	return $self->SUPER::set(@_);
}

1;
