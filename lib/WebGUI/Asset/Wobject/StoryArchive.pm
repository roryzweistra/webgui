package WebGUI::Asset::Wobject::StoryArchive;

our $VERSION = "1.0.0";

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2009 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;

use Moose;
use WebGUI::Definition::Asset;
extends 'WebGUI::Asset::Wobject';
define assetName => ['assetName', 'Asset_StoryArchive'];
define icon      => 'storyarchive.gif';
define tableName => 'StoryArchive';
property storiesPerPage => (
            tab          => 'display',  
            fieldType    => 'integer',  
            label        => ['stories per page', 'Asset_StoryArchive'],
            hoverHelp    => ['stories per page help', 'Asset_StoryArchive'],
            default      => 25,
         );
property groupToPost => (
            tab          => 'security',  
            fieldType    => 'group',  
            label        => ['group to post', 'Asset_StoryArchive'],
            hoverHelp    => ['group to post help', 'Asset_StoryArchive'],
            default      => '12',
         );
property templateId => (
            tab          => 'display',
            fieldType    => 'template',
            label        => ['template', 'Asset_StoryArchive'],
            hoverHelp    => ['template help', 'Asset_StoryArchive'],
            namespace    => 'StoryArchive',
            default      => 'yxD5ka7XHebPLD-LXBwJqw',
         );
property storyTemplateId => (
            tab          => 'display',
            fieldType    => 'template',
            label        => ['story template', 'Asset_StoryArchive'],
            hoverHelp    => ['story template help', 'Asset_StoryArchive'],
            namespace    => 'Story',
            default      => '3QpYtHrq_jmAk1FNutQM5A',
         );
property photoWidth => (
            tab          => 'display',
            fieldType    => 'integer',
            label        => ['photo width', 'Asset_StoryArchive'],
            hoverHelp    => ['photo width help', 'Asset_StoryArchive'],
            default      => '300',
         );
property editStoryTemplateId => (
            tab          => 'display',
            fieldType    => 'template',
            label        => ['edit story template', 'Asset_StoryArchive'],
            hoverHelp    => ['edit story template help', 'Asset_StoryArchive'],
            namespace    => 'Story/Edit',
            default      => 'E3tzZjzhmYoNlAyP2VW33Q',
         );
property keywordListTemplateId => (
            tab          => 'display',
            fieldType    => 'template',
            label        => ['keyword list template', 'Asset_StoryArchive'],
            hoverHelp    => ['keyword list template help', 'Asset_StoryArchive'],
            namespace    => 'StoryArchive/KeywordList',
            default      => '0EAJ9EYb9ap2XwfrcXfdLQ',
         );
property archiveAfter => (
            tab          => 'display',  
            fieldType    => 'interval',  
            label        => ['archive after', 'Asset_StoryArchive'],
            hoverHelp    => ['archive after help', 'Asset_StoryArchive'],
            default      => 31536000,
         );
property richEditorId => (
            tab          => 'display',  
            fieldType    => 'selectRichEditor',  
            label        => ['rich editor', 'Asset_StoryArchive'],
            hoverHelp    => ['rich editor help', 'Asset_StoryArchive'],
            default      => 'PBrichedit000000000002',
         );
property approvalWorkflowId => (
            tab           => 'security',
            fieldType     => 'workflow',
            default       => 'pbworkflow000000000003',
            type          => 'WebGUI::VersionTag',
            label         => ['approval workflow', 'Asset_StoryArchive'],
            hoverHelp     => ['approval workflow help', 'Asset_StoryArchive'],
         );    
with 'WebGUI::Role::Asset::RssFeed';

use WebGUI::International;
use WebGUI::Asset::Story;
use WebGUI::Asset::Wobject::Folder;
use WebGUI::Paginator;
use WebGUI::Keyword;
use WebGUI::Search;

use File::Path;

use constant DATE_FORMAT => '%c_%D_%y';

#-------------------------------------------------------------------

=head2 addChild ( )

Story Archive really only has Folders for children.  When addChild is
called, check the date to see which folder to use.  If the correct folder
does not exist, then make it.

=cut

override addChild => sub {
    my $self = shift;
    my ($properties) = @_;
    ##Allow subclassing
    if ($properties->{className} eq 'WebGUI::Asset::Wobject::Folder') {
        return super();
    }
    return undef unless $properties->{className} =~ /^WebGUI::Asset::Story/;
    my $todayFolder = $self->getFolder;
    return undef unless $todayFolder;
    my $story = $todayFolder->addChild(@_);
    return $story;
};

#-------------------------------------------------------------------

=head2 canPostStories ( )

Determines whether or not a user can post stories to this Archive.

=head3 userId

An explicit userId to check against.  If no userId is sent, then it
will use the current session user instead.

=cut

sub canPostStories {
	my ($self, $userId) = @_;
    $userId ||= $self->session->user->userId;
    my $user = WebGUI::User->new($self->session, $userId);
	return $user->isInGroup($self->groupToPost) || $self->canEdit($userId);
}

#-------------------------------------------------------------------

=head2 exportAssetCollateral (basePath, params, session)

Extended the master method in order to produce keyword files.

=cut

sub exportAssetCollateral {
    # Lots of copy/paste here from AssetExportHtml.pm, since none of the methods there were
    #   directly useful without ginormous refactoring.
    my $self = shift;
    my $basepath = shift;
    my $args = shift;
    my $reportSession = shift;
    my $session = $self->session;

    my $reporti18n = WebGUI::International->new($session, 'Asset');

    my $basename = $basepath->basename;
    my $filedir;

    # We want our keyword files to "appear" as children of the asset to avoid
    # clashing with multiple story archives.
    if ($basename eq 'index.html') {
        # Get the parent of the file index.html, which is the asset's directory.
        $filedir = $basepath->parent->absolute->stringify;
    }
    else {
        ##Create a directory that has the same base
        my $dirname = $basename;
        $dirname =~ s/\.\w+$//;
        $filedir = $basepath->parent->subdir($dirname)->absolute->stringify;
        eval { File::Path::mkpath($filedir) };
        if($@) {
            WebGUI::Error->throw(error => "could not make directory " . $filedir);
        }
    }

    if ( $reportSession && !$args->{quiet} ) {
        $reportSession->output->print('<br />');
    }

    # open another session to handle printing...
    my $printSession = $self->session->duplicate;

    my $keywordObj = WebGUI::Keyword->new($printSession);
    my $keywords = $keywordObj->findKeywords({
        asset => $self,
        limit => 50, ##This is based on the tagcloud setting
    });

    my $listTemplate = WebGUI::Asset->newById($session, $self->keywordListTemplateId);
    foreach my $keyword (@{ $keywords }) {
        ##Keywords may not be URL safe, so urlize them
        my $keyword_url = $self->getKeywordFilename($keyword);
        my $dest = Path::Class::File->new($filedir, $keyword_url);

        # tell the user which asset we're exporting.
        if ( $reportSession && !$args->{quiet} ) {
            my $message = sprintf $reporti18n->get('exporting page'), $dest->absolute->stringify;
            $reportSession->output->print(
                '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;' . $message . '<br />');
        }

        # next, get the contents, open the file, and write the contents to the file.
        my $fh = eval { $dest->open('>:utf8') };
        if($@) {
            $printSession->close;
            WebGUI::Error->throw(error => "can't open " . $dest->absolute->stringify . " for writing: $!");
        }
        $printSession->output->setHandle($fh);

        my $storyIds = $keywordObj->getMatchingAssets({
            startAsset  => $self,
            keyword     => $keyword,
            isa         => 'WebGUI::Asset::Story',
            rowsPerPage => 50,
        });
        my $listOfStories = [];
        STORYID: foreach my $storyId (@{ $storyIds }) {
            my $story = WebGUI::Asset->newById($session, $storyId);
            next STORYID unless $story;
            push @{ $listOfStories }, {
                title => $story->getTitle,
                url   => $story->getUrl,
            };
        }
        my $var = {
            asset_loop => $listOfStories,
            keyword    => $keyword,
        };
        my $output = $listTemplate->process($var);
        my $contents = $self->processStyle($output);
        $printSession->output->print($contents);

        # tell the user we did this asset collateral correctly
        if ( $reportSession && !$args->{quiet} ) {
            $reportSession->output->print($reporti18n->get('done'));
        }
        $fh->flush;
        $fh->close;
    }
    $printSession->close;
    return $self->next::method($basepath, $args, $reportSession);
}

#-------------------------------------------------------------------

=head2 getFolder ( date )

Stories are stored in Folders under the Story Archive to prevent lineage issues.
Gets the correct folder for stories.   If the Folder does not exist, then it will
be created and autocommitted.  The autocommit is COMPLETELY automatic.  This is
because it's possible to gum up the Story submitting proces with a Folder under
a different version tag.

=head3 date

There is one folder for each day that Stories are submitted.  The requested date
should be an epoch.  If no date is passed, it will use the current time instead.

=cut

sub getFolder {
	my ($self, $date) = @_;
    my $session    = $self->session;
    my $folderName = $session->datetime->epochToHuman($date, DATE_FORMAT);
    my $folderUrl  = join '/', $self->getUrl, $folderName;
    my $folder     = eval { WebGUI::Asset->newByUrl($session, $folderUrl); };
    return $folder if !Exception::Class->caught();
    ##The requested folder doesn't exist.  Make it and autocommit it.

    ##For a fully automatic commit, save the current tag, create a new one
    ##with the commit without approval workflow, commit it, then restore
    ##the original if it exists
    my ($oldVersionTag, $newVersionTag);
    $oldVersionTag = WebGUI::VersionTag->getWorking($session, 'noCreate');

    if ($self->hasBeenCommitted) {
        $newVersionTag = WebGUI::VersionTag->create($session, { workflowId => 'pbworkflow00000000003', });
        $newVersionTag->setWorking;
        $newVersionTag->set({ name => 'Adding folder '. $folderName. ' to archive '. $self->getUrl});
    }

    ##Call SUPER because my addChild calls getFolder
    $folder = $self->addChild({
        className       => 'WebGUI::Asset::Wobject::Folder',
        title           => $folderName,
        menuTitle       => $folderName,
        url             => $folderUrl,
        isHidden        => 1,
        styleTemplateId => $self->styleTemplateId,
    });
    $newVersionTag->commit() if $newVersionTag;
    ##Restore the old one, if it exists
    $oldVersionTag->setWorking() if $oldVersionTag;

    ##Get a new version of the asset from the db with the correct state
    $folder = $folder->cloneFromDb();
    return $folder;
}

#-------------------------------------------------------------------

=head2 getKeywordFilename ( $keyword )

Returns the name for the file containing stories that match this keyword.  Used
in exportAssetCollateral, and in viewTemplateVariables.

=head3 $keyword

The keyword to generate a URL for.

=cut

sub getKeywordFilename {
    my ($self,$keyword) = @_;
    return $self->session->url->urlize('keyword_'.$keyword.'.html');
}

#-------------------------------------------------------------------

=head2 getKeywordStaticURL ( $keyword )

Returns the whole URL for the file containing stories that match this keyword.  Used
in exportAssetCollateral.

The goal of this method is to create a "safe" URL where all the keyword files can
reside with no clashes.  The best place is based on the URL for the StoryArchive.

=head3 $keyword

Generates a specific URL for $keyword.

=cut

sub getKeywordStaticURL {
    my ($self,$keyword) = @_;
    my $url = $self->getUrl;
    my @parts = split /\//, $url;
    my $lastPart = pop @parts;
    if (index( $lastPart, '.' ) == -1) {
        return join '/', $self->getUrl, $self->getKeywordFilename($keyword);
    }
    else {
        $lastPart =~ s/\.[^.]*$//;
        return join '/', @parts, $lastPart, $self->getKeywordFilename($keyword);
    }
}

#-------------------------------------------------------------------

=head2 getRssFeedItems ( )

Returns an arrayref of hashrefs, containing information on stories
for generating an RSS and Atom feeds.

=cut

sub getRssFeedItems {
    my $self    = shift;
    my $storyIter = $self->getLineageIterator(['descendants'],{
        excludeClasses => ['WebGUI::Asset::Wobject::Folder'],
        orderByClause  => 'creationDate desc, lineage',
        returnObjects  => 1,
        limit          => $self->itemsPerFeed,
    });
    my $storyData = [];
    while ( 1 ) {
        my $story;
        eval { $story = $storyIter->() };
        if ( my $x = WebGUI::Error->caught('WebGUI::Error::ObjectNotFound') ) {
            $self->session->log->error($x->full_message);
            next;
        }
        last unless $story;
        push @{ $storyData }, $story->getRssData;
    }
    return $storyData;
}

#-------------------------------------------------------------------

=head2 prepareView ( )

See WebGUI::Asset::prepareView() for details.

=cut

sub prepareView {
    my $self = shift;
    $self->SUPER::prepareView();
    my $template = WebGUI::Asset::Template->newById($self->session, $self->templateId);
    if (!$template) {
        WebGUI::Error::ObjectNotFound::Template->throw(
            error      => qq{Template not found},
            templateId => $self->templateId,
            assetId    => $self->getId,
        );
    }
    $template->prepare;
    $self->{_viewTemplate} = $template;
}


#-------------------------------------------------------------------

=head2 view ( )

method called by the www_view method.  Returns a processed template
to be displayed within the page style.  

=cut

sub view {
    my $self    = shift;
    my $session = $self->session;    

    #This automatically creates template variables for all of your wobject's properties.
    my $mode = $session->form->hasParam('keyword') 
             ? 'keyword'
             : $session->form->hasParam('search')
             ? 'search'
             : 'view';

    my $var = $self->viewTemplateVariables($mode);

    return $self->processTemplate($var, undef, $self->{_viewTemplate});
}

#-------------------------------------------------------------------

=head2 viewTemplateVariables ( $mode )

Make template variables for the view template.

=head3 $mode

Whether to get assets in view mode, by time, or search mode, by keywords.

If the asset is being exported for HTML, the following changes are mode:

=over 4

=item *

The search form template variables are not generated.

=item *

The pagination variables are not generated.

=item *

The pagination size is set to 10 standard pages.

=back

=cut

sub viewTemplateVariables {
    my ($self, $mode)   = @_;
    my $session         = $self->session;    
    my $keywords        = $session->form->get('keyword');
    my $query           = $session->form->get('query'); 
    my $exporting       = $session->scratch->get('isExporting');
    my $p;
    my $i18n = WebGUI::International->new($session);
    my $var  = $self->get();
    if ($mode eq 'keyword') {
        $var->{mode} = 'keyword';
        my $wordList = WebGUI::Keyword::string2list($keywords);
        my $key      = WebGUI::Keyword->new($session);
        $p           = $key->getMatchingAssets({
            startAsset   => $self,
            keywords     => $wordList,
            isa          => 'WebGUI::Asset::Story',
            usePaginator => 1,
            rowsPerPage  => $self->storiesPerPage,
        });
        $p->setBaseUrl($self->getUrl("func=view;keyword=".$keywords));
    }
    elsif ($mode eq 'search') {
        $var->{mode} = 'search';
        my $search   = WebGUI::Search->new($session);
        $search->search({
            keywords => $query,
            lineage  => [ $self->lineage,    ],
            classes  => [ qw/WebGUI::Asset::Story/, ],
        });
        $p = $search->getPaginatorResultSet($self->getUrl, $self->get('storiesPerPage'));
    }
    else {
        $var->{mode} = 'view';
        ##Only return assetIds,  we'll build data for the things that are actually displayed.
        my $storySql = $self->getLineageSql(['descendants'],{
            excludeClasses => ['WebGUI::Asset::Wobject::Folder'],
            orderByClause  => 'creationDate desc, lineage',
        });
        my $storiesPerPage = $self->storiesPerPage;
        if ($exporting) {
            ##10 pages worth of data on 1 page in export mode
            $storiesPerPage *= 10;
        }
        $p = WebGUI::Paginator->new($session, $self->getUrl, $storiesPerPage);
        $p->setDataByQuery($storySql);
    }
    my $storyIds = $p->getPageData();
    if (! $exporting ) {
        ##Pagination variables aren't useful in export mode
        $p->appendTemplateVars($var);
    }

    $var->{date_loop} = [];
    my $lastStoryDate = '';
    my $datePointer   = undef;

    my $icon          = $session->icon;
    my $userUiLevel   = $session->user->profileField("uiLevel");
    my $uiLevels      = $session->config->get('assetToolbarUiLevel');

    ##Only build objects for the assets that we need
    STORY: foreach my $storyId (@{ $storyIds }) {
        my $story = WebGUI::Asset->newById($session, $storyId->{assetId}, $storyId->{revisionDate});
        next STORY unless $story;
        my $creationDate = $story->creationDate;
        my ($creationDay,undef) = $session->datetime->dayStartEnd($creationDate);
        my $storyDate = $session->datetime->epochToHuman($creationDay, DATE_FORMAT);
        if ($storyDate ne $lastStoryDate) {
            push @{ $var->{date_loop} }, {};
            $datePointer = $var->{date_loop}->[-1];
            $datePointer->{epochDate} = $creationDay;
            $datePointer->{story_loop} = [];
            $lastStoryDate = $storyDate;
        }
        my $storyVars = {
            url           => $story->getUrl,
            title         => $story->getTitle,
            creationDate  => $creationDate,
        };
        if ($story->canEdit && $userUiLevel >= $uiLevels->{delete} && !$exporting) {
            $storyVars->{deleteIcon} = $icon->delete('func=delete', $story->url, $i18n->get(43));
        }
        if ($story->canEdit && $userUiLevel >= $uiLevels->{edit}   && !$exporting) {
            $storyVars->{editIcon}   = $icon->edit('func=edit', $story->url);
        }
        push @{$datePointer->{story_loop}}, $storyVars;
    }

    $var->{canPostStories} = $self->canPostStories;
    $var->{addStoryUrl}    = $var->{canPostStories}
                           ? $self->getUrl('func=add;class=WebGUI::Asset::Story')
                           : '';
    $var->{rssUrl}         = $self->getRssFeedUrl;
    $var->{atomUrl}        = $self->getAtomFeedUrl;
    my $cloudOptions       = {
        startAsset  => $self,
        displayFunc => 'view',
    };
    ##In export mode, tags should link to the pages generated during the collateral export
    if($exporting) {
        $cloudOptions->{urlCallback} = 'getKeywordStaticURL';
        $cloudOptions->{displayFunc} = '';
    }
    $var->{keywordCloud}   = WebGUI::Keyword->new($session)->generateCloud($cloudOptions);
    if (! $exporting) {
        $var->{searchHeader} = WebGUI::Form::formHeader($session, { action => $self->getUrl, method => 'GET',  })
                             . WebGUI::Form::hidden($session, { name   => 'func',   value => 'view' });
        $var->{searchFooter} = WebGUI::Form::formFooter($session);
        $var->{searchButton} = WebGUI::Form::submit($session, { name => 'search',   value => $i18n->get('search','Asset')});
        $var->{searchForm}   = WebGUI::Form::text($session,   { name => 'query',    value => $query});
    }
    return $var;
}

#-------------------------------------------------------------------

=head2 www_add ( )

The only real children of StoryArchive are Folders, which then hold Stories.  So we intercept
www_add, find the right folder to use, then allow that folder to continue on.

=cut


sub www_add {
    my $self    = shift;
    my $session = $self->session;
    my $form    = $session->form;
    if ($form->get('class') ne 'WebGUI::Asset::Story') {
        $session->log->warn('Refusing to add '. $form->get('class'). ' to StoryArchive');
        return undef;
    }
    my $todayFolder = $self->getFolder;
    if (!$todayFolder) {
        $session->log->warn('Unable to get folder for today.  Not adding Story');
        return undef;
    }
    $todayFolder->www_add;
}

__PACKAGE__->meta->make_immutable;
1;
#vim:ft=perl
