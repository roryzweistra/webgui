package WebGUI::Asset::Post;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2006 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;
use Tie::CPHash;
use WebGUI::Asset;
use WebGUI::Asset::Template;
use WebGUI::Asset::Post::Thread;
use WebGUI::Cache;
use WebGUI::HTML;
use WebGUI::HTMLForm;
use WebGUI::International;
use WebGUI::MessageLog;
use WebGUI::Operation;
use WebGUI::Paginator;
use WebGUI::SQL;
use WebGUI::Storage::Image;
use WebGUI::User;
use WebGUI::Utility;

our @ISA = qw(WebGUI::Asset);



#-------------------------------------------------------------------
                
=head2 addRevision
        
Override the default method in order to deal with attachments.

=cut

sub addRevision {
        my $self = shift;
        my $newSelf = $self->SUPER::addRevision(@_);
        if ($self->get("storageId")) {
                my $newStorage = WebGUI::Storage->get($self->session,$self->get("storageId"))->copy;
                $newSelf->update({storageId=>$newStorage->getId});
        }       
        return $newSelf;
}  

#-------------------------------------------------------------------
sub canAdd {
	my $class = shift;
	my $session = shift;
	$class->SUPER::canAdd($session, undef, '7');
}

#-------------------------------------------------------------------
sub canEdit {
	my $self = shift;
	return (($self->session->form->process("func") eq "add" || ($self->session->form->process("assetId") eq "new" && $self->session->form->process("func") eq "editSave" && $self->session->form->process("class") eq "WebGUI::Asset::Post")) && $self->getThread->getParent->canPost) || # account for new posts

		($self->isPoster && $self->getThread->getParent->get("editTimeout") > ($self->session->datetime->time() - $self->get("dateUpdated"))) ||
		$self->getThread->getParent->canModerate;

}

#-------------------------------------------------------------------

=head2 canView ( )

Returns a boolean indicating whether the user can view the current post.

=cut

sub canView {
        my $self = shift;
        if (($self->get("status") eq "approved" || $self->get("status") eq "archived") && $self->getThread->getParent->canView) {
                return 1;
        } elsif ($self->get("status") eq "denied" && $self->canEdit) {
                return 1;
        } else {
                $self->getThread->getParent->canEdit;
        }
}


#-------------------------------------------------------------------

=head2 chopTitle ( )

Cuts a title string off at 30 characters.

=cut

sub chopTitle {
	my $self = shift;
        return substr($self->get("title"),0,30);
}

#-------------------------------------------------------------------
sub definition {
	my $class = shift;
	my $session = shift;
        my $definition = shift;
	my $i18n = WebGUI::International->new($session,"Asset_Post");
        push(@{$definition}, {
		assetName=>$i18n->get('assetName'),
		icon=>'post.gif',
                tableName=>'Post',
                className=>'WebGUI::Asset::Post',
                properties=>{
			storageId => {
				noFormPost=>1,
				fieldType=>"hidden",
				defaultValue=>undef
				},
			threadId => {
				noFormPost=>1,
				fieldType=>"hidden",
				defaultValue=>undef
				},
			dateSubmitted => {
				noFormPost=>1,
				fieldType=>"hidden",
				defaultValue=$self->session->datetime->time()
				},
			dateUpdated => {
				fieldType=>"hidden",
				defaultValue=$self->session->datetime->time()
				},
			username => {
				fieldType=>"hidden",
				defaultValue=>$self->session->form->process("visitorUsername") || $self->session->user->profileField("alias") || $self->session->user->profileField("username")
				},
			rating => {
				noFormPost=>1,
				fieldType=>"hidden",
				defaultValue=>undef
				},
			views => {
				noFormPost=>1,
				fieldType=>"hidden",
				defaultValue=>undef
				},
			contentType => {
				fieldType=>"contentType",
				defaultValue=>"mixed"
				},
			userDefined1 => {
				fieldType=>"HTMLArea",
				defaultValue=>undef
				},
			userDefined2 => {
				fieldType=>"HTMLArea",
				defaultValue=>undef
				},
			userDefined3 => {
				fieldType=>"HTMLArea",
				defaultValue=>undef
				},
			userDefined4 => {
				fieldType=>"HTMLArea",
				defaultValue=>undef
				},
			userDefined5 => {
				fieldType=>"HTMLArea",
				defaultValue=>undef
				},
			content => {
				fieldType=>"HTMLArea",
				defaultValue=>undef
				}
			},
		});
        return $class->SUPER::definition($session,$definition);
}


#-------------------------------------------------------------------
sub DESTROY {
	my $self = shift;
	$self->{_thread}->DESTROY if (exists $self->{_thread} && ref $self->{_thread} =~ /Thread/);
	$self->SUPER::DESTROY;
}


#-------------------------------------------------------------------

=head2 formatContent ( [ content, contentType ])

Formats post content for display.

=head3 content

The content to format. Defaults to the content in this post.

=head3 contentType

The content type to use for formatting. Defaults to the content type specified in this post.

=cut

sub formatContent {
	my $self = shift;
	my $content = shift || $self->get("content");
	my $contentType = shift || $self->get("contentType");	
        my $msg = WebGUI::HTML::filter($content,$self->getThread->getParent->get("filterCode"));
        $msg = WebGUI::HTML::format($msg, $contentType);
        if ($self->getThread->getParent->get("useContentFilter")) {
                $msg = WebGUI::HTML::processReplacements($self->session,$msg);
        }
        return $msg;
}

#-------------------------------------------------------------------

=head2 getApproveUrl (  )

Formats the URL to approve a post.

=cut

sub getApproveUrl {
	my $self = shift;
	return $self->getUrl("revision=".$self->get("revisionDate").";func=approve;mlog=".$self->session->form->process("mlog"));
}

#-------------------------------------------------------------------

=head2 getAvatarUrl (  )

Returns a URL to the owner's avatar.

=cut

sub getAvatarUrl {
	my $self = shift;
	my $avatarUrl;
	return $avatarUrl unless
		$self->getThread->getParent->getValue("avatarsEnabled");
	my $user = WebGUI::User->new($self->get('ownerUserId'));
	#Get avatar field, storage Id.
	my $storageId = $user->profileField("avatar");
	my $avatar = WebGUI::Storage::Image->get($self->session,$storageId);
	if ($avatar) {
		#Get url from storage object.
		foreach my $imageName (@{$avatar->getFiles}) {
			if ($avatar->isImage($imageName)) {
				$avatarUrl = $avatar->getUrl($imageName);
				last;
			}
		}
	}
	return $avatarUrl;
}

#-------------------------------------------------------------------

=head2 getDeleteUrl (  )

Formats the url to delete a post.

=cut

sub getDeleteUrl {
	my $self = shift;
	return $self->getUrl("func=delete;revision=".$self->get("revisionDate"));
}

#-------------------------------------------------------------------

=head2 getDenyUrl (  )

Formats the url to deny a post.

=cut

sub getDenyUrl {
	my $self = shift;
	return $self->getUrl("revision=".$self->get("revisionDate").";func=deny;mlog=".$self->session->form->process("mlog"));
}

#-------------------------------------------------------------------

=head2 getEditUrl ( )

Formats the url to edit a post.

=cut

sub getEditUrl {
	my $self = shift;
	return $self->getUrl("func=edit;revision=".$self->get("revisionDate"));
}


#-------------------------------------------------------------------
sub getImageUrl {
	my $self = shift;
	return undef if ($self->get("storageId") eq "");
	my $storage = $self->getStorageLocation;
	my $url;
	foreach my $filename (@{$storage->getFiles}) {
		if ($storage->isImage($filename)) {
			$url = $storage->getUrl($filename);
			last;
		}
	}
	return $url;
}


#-------------------------------------------------------------------

=head2 getPosterProfileUrl (  )

Formats the url to view a users profile.

=cut

sub getPosterProfileUrl {
	my $self = shift;
	return $self->getUrl("op=viewProfile;uid=".$self->get("ownerUserId"));
}

#-------------------------------------------------------------------

=head2 getRateUrl ( rating )

Formats the url to rate a post.

=head3 rating

An integer between 1 and 5 (5 = best).

=cut

sub getRateUrl {
	my $self = shift;
	my $rating = shift;
	return $self->getUrl("func=rate;rating=".$rating."#id".$self->getId);
}

#-------------------------------------------------------------------

=head2 getReplyUrl ( [ withQuote ] )

Formats the url to reply to a post.

=head3 withQuote

If specified the reply with automatically quote the parent post.

=cut

sub getReplyUrl {
	my $self = shift;
	my $withQuote = shift || 0;
	return $self->getUrl("func=add;class=WebGUI::Asset::Post;withQuote=".$withQuote);
}

#-------------------------------------------------------------------
sub getStatus {
	my $self = shift;
	my $status = $self->get("status");
	my $i18n = WebGUI::International->new($self->session,"Asset_Post");
        if ($status eq "approved") {
                return $i18n->get('approved');
        } elsif ($status eq "denied") {
                return $i18n->get('denied');
        } elsif ($status eq "pending") {
                return $i18n->get('pending');
        } elsif ($status eq "archived") {
                return $i18n->get('archived');
        }
}

#-------------------------------------------------------------------
sub getStorageLocation {
	my $self = shift;
	unless (exists $self->{_storageLocation}) {
		if ($self->get("storageId") eq "") {
			$self->{_storageLocation} = WebGUI::Storage::Image->create;
			$self->update({storageId=>$self->{_storageLocation}->getId});
		} else {
			$self->{_storageLocation} = WebGUI::Storage::Image->get($self->session,$self->get("storageId"));
		}
	}
	return $self->{_storageLocation};
}

#-------------------------------------------------------------------
sub getSynopsisAndContentFromFormPost {
	my $self = shift;
	my $synopsis = $self->session->form->process("synopsis");
	my $body = $self->session->form->process("content");
	unless ($synopsis) {
        	$body =~ s/\n/\^\-\;/ unless ($body =~ m/\^\-\;/);
       	 	my @content = split(/\^\-\;/,$body);
		$synopsis = WebGUI::HTML::filter($content[0],"all");
	}
	$body =~ s/\^\-\;/\n/;
	return ($synopsis,$body);
}

#-------------------------------------------------------------------
sub getTemplateVars {
	my $self = shift;
	my %var = %{$self->get};
	$var{"userId"} = $self->get("ownerUserId");
	$var{"user.isPoster"} = $self->isPoster;
	$var{"avatar.url"} = $self->getAvatarUrl;
	$var{"userProfile.url"} = $self->getUrl("op=viewProfile;uid=".$self->get("ownerUserId"));
	$var{"dateSubmitted.human"} =$self->session->datetime->epochToHuman($self->get("dateSubmitted"));
	$var{"dateUpdated.human"} =$self->session->datetime->epochToHuman($self->get("dateUpdated"));
	$var{'title.short'} = $self->chopTitle;
	$var{content} = $self->formatContent if ($self->getThread);
	$var{'user.canEdit'} = $self->canEdit if ($self->getThread);
	$var{"delete.url"} = $self->getDeleteUrl;
	$var{"edit.url"} = $self->getEditUrl;
	$var{"status"} = $self->getStatus;
	$var{"approve.url"} = $self->getApproveUrl;
	$var{"deny.url"} = $self->getDenyUrl;
	$var{"reply.url"} = $self->getReplyUrl;
	$var{'reply.withquote.url'} = $self->getReplyUrl(1);
	$var{'url'} = $self->getUrl.'#id'.$self->getId;
	$var{'rating.value'} = $self->get("rating")+0;
	$var{'rate.url.1'} = $self->getRateUrl(1);
	$var{'rate.url.2'} = $self->getRateUrl(2);
	$var{'rate.url.3'} = $self->getRateUrl(3);
	$var{'rate.url.4'} = $self->getRateUrl(4);
	$var{'rate.url.5'} = $self->getRateUrl(5);
	$var{'hasRated'} = $self->hasRated;
	$var{'isMarkedRead'} = $self->isMarkedRead;
	my $gotImage;
	my $gotAttachment;
	@{$var{'attachment_loop'}} = ();
	unless ($self->get("storageId") eq "") {
		my $storage = $self->getStorageLocation;
		foreach my $filename (@{$storage->getFiles}) {
			if (!$gotImage && $storage->isImage($filename)) {
				$var{"image.url"} = $storage->getUrl($filename);
				$var{"image.thumbnail"} = $storage->getThumbnailUrl($filename);
				$gotImage = 1;
			}
			if (!$gotAttachment && !$storage->isImage($filename)) {
				$var{"attachment.url"} = $storage->getUrl($filename);
				$var{"attachment.icon"} = $storage->getFileIconUrl($filename);
				$var{"attachment.name"} = $filename;
				$gotAttachment = 1;
       			}	
			push(@{$var{"attachment_loop"}}, {
				url=>$storage->getUrl($filename),
				icon=>$storage->getFileIconUrl($filename),
				filename=>$filename,
				thumbnail=>$storage->getThumbnailUrl($filename),
				isImage=>$storage->isImage($filename)
				});
		}
	}
	return \%var;
}

#-------------------------------------------------------------------
sub getThread {
	my $self = shift;
	unless (exists $self->{_thread}) {
		$self->{_thread} = WebGUI::Asset::Post::Thread->new($self->get("threadId"));
	}
	return $self->{_thread};	
}

#-------------------------------------------------------------------
sub getThumbnailUrl {
	my $self = shift;
	return undef if ($self->get("storageId") eq "");
	my $storage = $self->getStorageLocation;
	my $url;
	foreach my $filename (@{$storage->getFiles}) {
		if ($storage->isImage($filename)) {
			$url = $storage->getThumbnailUrl($filename);
			last;
		}
	}
	return $url;
}


#-------------------------------------------------------------------
sub getUploadControl {
	my $self = shift;
	my $maxAttachments = $self->getThread->getParent->getValue("attachmentsPerPost");
	my $uploadControl;
	return undef unless ($maxAttachments);
	my $i18n = WebGUI::International->new($self->session);
	if ($self->get("storageId")) {
		my $i;
		foreach my $filename (@{$self->getStorageLocation->getFiles}) {
			$uploadControl .= $self->session->icon->delete("func=deleteFile;filename=".$filename,$self->get("url"),$i18n->get("delete file warning","Asset_Collaboration"))	
				.' <a href="'.$self->getStorageLocation->getUrl($filename).'">'.$filename.'</a>'
				.'<br />';
			$i++;
		}
		return $uploadControl unless ($i < $maxAttachments);
	}
	$uploadControl .= WebGUI::Form::file($self->session,
		maxAttachments=>$maxAttachments
		);
	return $uploadControl;
}


#-------------------------------------------------------------------

=head2 hasRated (  )

Returns a boolean indicating whether this user has already rated this post.

=cut

sub hasRated {	
	my $self = shift;
        return 1 if $self->isPoster;
        my ($flag) = $self->session->db->quickArray("select count(*) from Post_rating where assetId="
                .$self->session->db->quote($self->getId)." and ((userId=".$self->session->db->quote($self->session->user->profileField("userId"))." and userId<>'1') or (userId='1' and
                ipAddress=".$self->session->db->quote($self->session->env->get("REMOTE_ADDR"))."))");
        return $flag;
}

#-------------------------------------------------------------------

=head2 incrementViews ( )

Increments the views counter for this post.

=cut

sub incrementViews {
	my ($self) = @_;
        $self->update({views=>$self->get("views")+1});
}

#-------------------------------------------------------------------

=head2 isMarkedRead ( )

Returns a boolean indicating whether this post is marked read for the user.

=cut

sub isMarkedRead {
        my $self = shift;
	return 1 if $self->isPoster;
        my ($isRead) = $self->session->db->quickArray("select count(*) from Post_read where userId=".$self->session->db->quote($self->session->user->profileField("userId"))." and postId=".$self->session->db->quote($self->getId));
        return $isRead;
}

#-------------------------------------------------------------------

=head2 isPoster ( )

Returns a boolean that is true if the current user created this post and is not a visitor.

=cut

sub isPoster {
	my $self = shift;
	return ($self->session->user->profileField("userId") ne "1" && $self->session->user->profileField("userId") eq $self->get("ownerUserId"));
}


#-------------------------------------------------------------------

=head2 isReply ( )

Returns a boolean indicating whether this post is a reply. 

=cut

sub isReply {
	my $self = shift;
	return $self->getId ne $self->get("threadId");
}


#-------------------------------------------------------------------

=head2 markRead ( )

Marks this post read for this user.

=cut

sub markRead {
	my $self = shift;
        unless ($self->isMarkedRead) {
                $self->session->db->write("insert into Post_read (userId, postId, threadId, readDate) values (".$self->session->db->quote($self->session->user->profileField("userId")).",
                        ".$self->session->db->quote($self->getId).", ".$self->session->db->quote($self->get("threadId")).", ".$self->session->datetime->time().")");
        }
}

#-------------------------------------------------------------------

=head2 notifySubscribers ( )

Send notifications to the thread and forum subscribers that a new post has been made.

=cut

sub notifySubscribers {
	my $self = shift;
        my %subscribers;
	foreach my $userId (@{$group->getUsers($self->getThread->get("subscriptionGroupId"),undef,1)}) {
		$subscribers{$userId} = $userId unless ($userId eq $self->get("ownerUserId"));
	}
	foreach my $userId (@{$group->getUsers($self->getThread->getParent->get("subscriptionGroupId"),undef,1)}) {
		$subscribers{$userId} = $userId unless ($userId eq $self->get("ownerUserId"));
	}
        my %lang;
	my $i18n = WebGUI::International->new($self->session);
        foreach my $userId (keys %subscribers) {
                my $u = WebGUI::User->new($userId);
                if ($lang{$u->profileField("language")}{message} eq "") {
                        $lang{$u->profileField("language")}{var} = $self->getTemplateVars();
			$self->getThread->getParent->appendTemplateLabels($lang{$u->profileField("language")}{var});
			$lang{$u->profileField("language")}{var}{url} = $self->session->url->getSiteURL().$self->getUrl;
                        $lang{$u->profileField("language")}{var}{'notify.subscription.message'} =
                                         $i18n->get(875,"Asset_Post",$u->profileField("language"));
                        $lang{$u->profileField("language")}{subject} = $i18n->get(523,"Asset_Post",$u->profileField("language"));
                        $lang{$u->profileField("language")}{message} = $self->processTemplate($lang{$u->profileField("language")}{var}, $self->getThread->getParent->get("notificationTemplateId"));
                }
                WebGUI::MessageLog::addEntry($userId,"",$lang{$u->profileField("language")}{subject},$lang{$u->profileField("language")}{message});
        }
}


#-------------------------------------------------------------------
sub processPropertiesFromFormPost {
	my $self = shift;
	$self->SUPER::processPropertiesFromFormPost;	
	my $i18n = WebGUI::International->new($self->session);
	my %data;
	if ($self->session->form->process("assetId") eq "new") {
		if ($self->getParent->get("className") eq "WebGUI::Asset::Wobject::Collaboration") {
			$self->update({threadId=>$self->getId});
		} else {
			$self->update({threadId=>$self->getParent->get("threadId")});
		}
		if ($self->session->setting->get("enableKarma") && $self->getThread->getParent->get("karmaPerPost")) {
			my $u = WebGUI::User->new($self->session->user->profileField("userId"));
			$u->addKarma($self->getThread->getParent->get("karmaPerPost"), $self->getId, "Collaboration post");
		}
		%data = (
			ownerUserId => $self->session->user->profileField("userId"),
			username => $self->session->form->process("visitorName") || $self->session->user->profileField("alias") || $self->session->user->profileField("username"),
			isHidden => 1,
			);
		$data{url} = $self->fixUrl($self->getThread->get("url")."/1") if ($self->isReply);
		if ($self->getThread->getParent->canModerate) {
			$self->getThread->lock if ($self->session->form->process('lock'));
			$self->getThread->stick if ($self->session->form->process("stick"));
		}
	}
	$data{groupIdView} =$self->getThread->getParent->get("groupIdView");
	$data{groupIdEdit} = $self->getThread->getParent->get("groupIdEdit");
	$data{startDate} = $self->getThread->getParent->get("startDate") unless ($self->session->form->process("startDate"));
	$data{endDate} = $self->getThread->getParent->get("endDate") unless ($self->session->form->process("endDate"));
	($data{synopsis}, $data{content}) = $self->getSynopsisAndContentFromFormPost;
	if ($self->getThread->getParent->get("addEditStampToPosts")) {
		$data{content} .= "\n\n --- (".$i18n->get('Edited_on','Asset_Post')." ".$self->session->datetime->epochToHuman(undef,"%z %Z [GMT%O]").$i18n->get('By','Asset_Post').$self->session->user->profileField("alias").") --- \n";
		if ($self->getValue("contentType") eq "mixed" || $self->getValue("contentType") eq "html") {
			$data{content} = '<p>'.$data{content}.'</p>';
		}
	}
	$self->update(\%data);
        $self->getThread->subscribe if ($self->session->form->process("subscribe"));
        if ($self->getThread->getParent->get("moderatePosts")) {
                $self->setStatusPending;
        } else {
                $self->setStatusApproved;
        }
  delete $self->{_storageLocation};
	my $storage = $self->getStorageLocation;
	my $filename;
	my $attachmentLimit = $self->getThread->getParent->get("attachmentsPerPost");
	$filename = $storage->addFileFromFormPost("file", $attachmentLimit) if $attachmentLimit;
	if (defined $filename) {
		$self->setSize($storage->getFileSize($filename));
		foreach my $file (@{$storage->getFiles}) {
			if ($storage->isImage($file)) {
				$storage->generateThumbnail($file,$self->session->setting->get("maxImageSize"));
				$storage->deleteFile($file);
				$storage->renameFile('thumb-'.$file,$file);
				$storage->generateThumbnail($file);
			}
		}
	}
	$self->session->form->process("proceed") = "redirectToParent";
	# clear some cache
	WebGUI::Cache->new($self->session,"wobject_".$self->getThread->getParent->getId."_".$self->session->user->profileField("userId"))->delete;
	WebGUI::Cache->new($self->session,"cspost_".($self->getParent->getId)."_".$self->session->user->profileField("userId")."_".$self->session->scratch->get("discussionLayout")."_1")->delete;
}


#-------------------------------------------------------------------

sub purge {
        my $self = shift;
        my $sth = $self->session->db->read("select storageId from Post where assetId=".$self->session->db->quote($self->getId));
        while (my ($storageId) = $sth->array) {
                WebGUI::Storage->get($self->session,$storageId)->delete;
        }
        $sth->finish;
	$self->session->db->write("delete from Post_rating where assetId=".$self->session->db->quote($self->getId));
	$self->session->db->write("delete from Post_read where postId=".$self->session->db->quote($self->getId));
        return $self->SUPER::purge;
}

#-------------------------------------------------------------------

sub purgeRevision {
        my $self = shift;
        $self->getStorageLocation->delete;
        return $self->SUPER::purgeRevision;
}



#-------------------------------------------------------------------

=head2 rate ( rating )

Stores a rating against this post.

=head3 rating

An integer between 1 and 5 (5 being best) to rate this post with.

=cut

sub rate {
	my $self = shift;
	my $rating = shift || 3;
	unless ($self->hasRated) {
        	$self->session->db->write("insert into Post_rating (assetId,userId,ipAddress,dateOfRating,rating) values ("
                	.$self->session->db->quote($self->getId).", ".$self->session->db->quote($self->session->user->profileField("userId")).", ".$self->session->db->quote($self->session->env->get("REMOTE_ADDR")).", 
			".$self->session->datetime->time().", ".$self->session->db->quote($rating).")");
        	my ($count) = $self->session->db->quickArray("select count(*) from Post_rating where assetId=".$self->session->db->quote($self->getId));
        	$count = $count || 1;
        	my ($sum) = $self->session->db->quickArray("select sum(rating) from Post_rating where assetId=".$self->session->db->quote($self->getId));
        	my $average = WebGUI::Utility::round($sum/$count);
        	$self->update({rating=>$average});
		$self->getThread->rate($rating);
	}
}


#-------------------------------------------------------------------

=head2 setParent ( newParent ) 

We're overloading the setParent in Asset because we don't want posts to be able to be posted to anything other than other posts or threads.

=head3 newParent

An asset object to make the parent of this asset.

=cut

sub setParent {
        my $self = shift;
        my $newParent = shift;
        return 0 unless ($newParent->get("className") eq "WebGUI::Asset::Post" || $newParent->get("className") eq "WebGUI::Asset::Post::Thread");
        return $self->SUPER::setParent($newParent);
}

#-------------------------------------------------------------------

=head2 setStatusApproved ( )

Sets the post to approved and sends any necessary notifications.

=cut

sub setStatusApproved {
	my $self = shift;
        $self->commit;
        $self->getThread->incrementReplies($self->get("dateUpdated"),$self->getId) if $self->isReply;
        unless ($self->isPoster) {
                WebGUI::MessageLog::addInternationalizedEntry($self->get("ownerUserId"),'',$self->session->url->getSiteURL().'/'.$self->getUrl,579);
        }
        $self->notifySubscribers unless ($self->session->form->process("func") eq 'add');
}



#-------------------------------------------------------------------

=head2 setStatusArchived ( )

Sets the status of this post to archived.

=cut


sub setStatusArchived {
        my ($self) = @_;
        $self->update({status=>'archived'});
}


#-------------------------------------------------------------------

=head2 setStatusDenied ( )

Sets the status of this post to denied.

=cut

sub setStatusDenied {
        my ($self) = @_;
        $self->update({status=>'denied'});
        WebGUI::MessageLog::addInternationalizedEntry($self->get("ownerUserId"),'',$self->session->url->getSiteURL().'/'.$self->getUrl,580);
}

#-------------------------------------------------------------------

=head2 setStatusPending ( )

Sets the status of this post to pending.

=cut

sub setStatusPending {
        my ($self) = @_;
	if ($self->session->user->isInGroup($self->getThread->getParent->get("moderateGroupId"))) {
		$self->setStatusApproved;
	} else {
        	$self->update({status=>'pending'});
        	WebGUI::MessageLog::addInternationalizedEntry('',$self->getThread->getParent->get("moderateGroupId"),
                	$self->session->url->getSiteURL().'/'.$self->getUrl("revision=".$self->get("revisionDate")),578,'WebGUI','pending');
	}
}


#-------------------------------------------------------------------

=head2 trash

Moves post to the trash and decrements reply counter on thread.

=cut

sub trash {
        my $self = shift;
        $self->SUPER::trash;
        $self->getThread->decrementReplies if ($self->isReply);
        if ($self->getThread->get("lastPostId") eq $self->getId) {
                my $threadLineage = $self->getThread->get("lineage");
                my ($id, $date) = $self->session->db->quickArray("select Post.assetId, Post.dateSubmitted from Post, asset where asset.lineage like ".$self->session->db->quote($threadLineage.'%')." and Post.assetId<>".$self->session->db->quote($self->getId)." and asset.assetId=Post.assetId and asset.state='published' order by Post.dateSubmitted desc");
                $self->getThread->update({lastPostId=>$id, lastPostDate=>$date});
        }
        if ($self->getThread->getParent->get("lastPostId") eq $self->getId) {
                my $forumLineage = $self->getThread->getParent->get("lineage");
                my ($id, $date) = $self->session->db->quickArray("select Post.assetId, Post.dateSubmitted from Post, asset where asset.lineage like ".$self->session->db->quote($forumLineage.'%')." and Post.assetId<>".$self->session->db->quote($self->getId)." and asset.assetId=Post.assetId and asset.state='published' order by Post.dateSubmitted desc");
                $self->getThread->getParent->update({lastPostId=>$id, lastPostDate=>$date});
        }
}

#-------------------------------------------------------------------

=head2 unmarkRead ( )

Negates the markRead method.

=cut

sub unmarkRead {
	my $self = shift;
        $self->session->db->write("delete from forumRead where userId=".$self->session->db->quote($self->session->user->profileField("userId"))." and postId=".$self->session->db->quote($self->getId));
}

#-------------------------------------------------------------------

=head2 update

We overload the update method from WebGUI::Asset in order to handle file system privileges.

=cut

sub update {
        my $self = shift;
        my %before = (
                owner => $self->get("ownerUserId"),
                view => $self->get("groupIdView"),
                edit => $self->get("groupIdEdit")
                );
        $self->SUPER::update(@_);
        if ($self->get("ownerUserId") ne $before{owner} || $self->get("groupIdEdit") ne $before{edit} || $self->get("groupIdView") ne $before{view}) {
                $self->getStorageLocation->setPrivileges($self->get("ownerUserId"),$self->get("groupIdView"),$self->get("groupIdEdit"));
        }
}

#-------------------------------------------------------------------
sub view {
	my $self = shift;
	$self->markRead;
	$self->incrementViews;
	return $self->getThread->view;
}



#-------------------------------------------------------------------

=head2 www_approve ( )

The web method to approve a post.

=cut

sub www_approve {
	my $self = shift;
	$self->setStatusApproved if $self->getThread->getParent->canModerate;
	return $self->www_view;
}

#-------------------------------------------------------------------
sub www_deleteFile {
	my $self = shift;
	$self->getStorageLocation->deleteFile($self->session->form->process("filename")) if $self->canEdit;
	return $self->www_edit;
}


#-------------------------------------------------------------------

=head2 www_deny ( )

The web method to deny a post.

=cut

sub www_deny {
	my $self = shift;
	$self->setStatusDenied if $self->getThread->getParent->canModerate;
	return $self->www_view;
}

#-------------------------------------------------------------------
sub www_edit {
	my $self = shift;
	my %var;
	my $content;
	my $title;
	my $i18n = WebGUI::International->new($self->session);
	if ($self->session->form->process("func") eq "add") { # new post
        	$var{'form.header'} = WebGUI::Form::formHeader($self->session,{action=>$self->getParent->getUrl})
			.WebGUI::Form::hidden({
                		name=>"func",
				value=>"add"
				})
			.WebGUI::Form::hidden({
				name=>"assetId",
				value=>"new"
				})
			.WebGUI::Form::hidden({
				name=>"class",
				value=>$self->session->form->process("class")
				});
        	$var{'isNewPost'} = 1;
		$content = $self->session->form->process("content");
		$title = $self->session->form->process("title");
		if ($self->session->form->process("class") eq "WebGUI::Asset::Post") { # new reply
			$self->{_thread} = $self->getParent->getThread;
			return $self->session->privilege->insufficient() unless ($self->getThread->canReply);
			$var{isReply} = 1;
			$var{'reply.title'} = $self->getParent->get("title");
			$var{'reply.synopsis'} = $self->getParent->get("synopsis");
			$var{'reply.content'} = $self->getParent->formatContent;
			for my $i (1..5) {	
				$var{'reply.userDefined'.$i} = WebGUI::HTML::filter($self->getParent->get('userDefined'.$i),"macros");
			}
			unless ($self->session->form->process("content") || $self->session->form->process("title")) {
                		$content = "[quote]".$self->getParent->get("content")."[/quote]" if ($self->session->form->process("withQuote"));
                		$title = $self->getParent->get("title");
                		$title = "Re: ".$title unless ($title =~ /^Re:/);
			}
			$var{'subscribe.form'} = WebGUI::Form::yesNo({
				name=>"subscribe",
				value=>$self->session->form->process("subscribe")
				});
		} elsif ($self->session->form->process("class") eq "WebGUI::Asset::Post::Thread") { # new thread
			return $self->session->privilege->insufficient() unless ($self->getThread->getParent->canPost);
			$var{isNewThread} = 1;
                	if ($self->getThread->getParent->canModerate) {
                        	$var{'sticky.form'} = WebGUI::Form::yesNo({
                                	name=>'stick',
                                	value=>$self->session->form->process("stick")
                                	});
                        	$var{'lock.form'} = WebGUI::Form::yesNo({
                       	         	name=>'lock',
                                	value=>$self->session->form->process('lock')
                                	});
			}
			$var{'subscribe.form'} = WebGUI::Form::yesNo({
				name=>"subscribe",
				value=>$self->session->form->process("subscribe") || 1
				});
		}
                $content .= "\n\n".$self->session->user->profileField("signature") if ($self->session->user->profileField("signature") && !$self->session->form->process("content"));
	} else { # edit
		return $self->session->privilege->insufficient() unless ($self->canEdit);
        	$var{'form.header'} = WebGUI::Form::formHeader($self->session,{action=>$self->getUrl})
			.WebGUI::Form::hidden({
                		name=>"func",
				value=>"edit"
				})
			.WebGUI::Form::hidden({
				name=>"ownerUserId",
				value=>$self->getValue("ownerUserId")
				})
			.WebGUI::Form::hidden({
				name=>"username",
				value=>$self->getValue("username")
				});
		$var{isEdit} = 1;
		$content = $self->getValue("content");
		$title = $self->getValue("title");
	}
	if ($self->session->form->process("title") || $self->session->form->process("content") || $self->session->form->process("synopsis")) {
		$var{'preview.title'} = WebGUI::HTML::filter($self->session->form->process("title"),"all");
		($var{'preview.synopsis'}, $var{'preview.content'}) = $self->getSynopsisAndContentFromFormPost;
		$var{'preview.content'} = $self->formatContent($var{'preview.content'},$self->session->form->process("contentType"));
		for my $i (1..5) {	
			$var{'preview.userDefined'.$i} = WebGUI::HTML::filter($self->session->form->process('userDefined'.$i),"macros");
		}
	}
	$var{'form.footer'} = WebGUI::Form::formFooter($self->session,);
	$var{usePreview} = $self->getThread->getParent->get("usePreview");
	$var{'user.isModerator'} = $self->getThread->getParent->canModerate;
	$var{'user.isVisitor'} = ($self->session->user->profileField("userId") eq '1');
	$var{'visitorName.form'} = WebGUI::Form::text({
		name=>"visitorName",
		value=>$self->getValue("visitorName")
		});
	for my $x (1..5) {
		$var{'userDefined'.$x.'.form'} = WebGUI::Form::text({
			name=>"userDefined".$x,
			value=>$self->getValue("userDefined".$x)
			});
		$var{'userDefined'.$x.'.form.yesNo'} = WebGUI::Form::yesNo({
			name=>"userDefined".$x,
			value=>$self->getValue("userDefined".$x)
			});
		$var{'userDefined'.$x.'.form.textarea'} = WebGUI::Form::textarea({
			name=>"userDefined".$x,
			value=>$self->getValue("userDefined".$x)
			});
		$var{'userDefined'.$x.'.form.htmlarea'} = WebGUI::Form::HTMLArea({
			name=>"userDefined".$x,
			value=>$self->getValue("userDefined".$x)
			});
	}
	$title = WebGUI::HTML::filter($title,"all");
	$content = WebGUI::HTML::filter($content,"macros");
	$var{'title.form'} = WebGUI::Form::text({
		name=>"title",
		value=>$title
		});
	$var{'synopsis.form'} = WebGUI::Form::textarea({
		name=>"synopsis",
		value=>WebGUI::HTML::filter($self->getValue("synopsis"),"all")
		});
	$var{'title.form.textarea'} = WebGUI::Form::textarea({
		name=>"title",
		value=>$title
		});
	$var{'content.form'} = WebGUI::Form::HTMLArea({
		name=>"content",
		value=>$content,
		richEditId=>$self->getThread->getParent->get("richEditor")
		});
	$var{'form.submit'} = WebGUI::Form::submit({
		extras=>"onclick=\"this.value='".$i18n->get(452)."'; this.form.func.value='editSave'; this.form.submit();return false;\""
		});
	$var{'form.preview'} = WebGUI::Form::submit({
		value=>$i18n->get("preview","Asset_Collaboration")
		});
	$var{'attachment.form'} = $self->getUploadControl;
        $var{'contentType.form'} = WebGUI::Form::contentType({
                name=>'contentType',
                value=>$self->getValue("contentType") || "mixed"
                });
	my $startDate = $self->get("startDate");
	$startDate = $self->session->datetime->setToEpoch($self->session->form->process("startDate")) if ($self->session->form->process("startDate"));
	$var{'startDate.form'} = WebGUI::Form::dateTime({
		name  => 'startDate',
		value => $startDate
		});
	my $endDate = $self->get("endDate");
	$endDate = $self->session->datetime->setToEpoch($self->session->form->process("endDate")) if ($self->session->form->process("endDate"));
	$var{'endDate.form'} = WebGUI::Form::dateTime({
		name  => 'endDate',
		value => $endDate
		});
	$self->getThread->getParent->appendTemplateLabels(\%var);
	return $self->getThread->getParent->processStyle($self->processTemplate(\%var,$self->getThread->getParent->get("postFormTemplateId")));
}


#-------------------------------------------------------------------

=head2 www_ratePost ( )

The web method to rate a post.

=cut

sub www_rate {	
	my $self = shift;
	$self->WebGUI::Asset::Post::rate($self->session->form->process("rating")) if ($self->canView && !$self->hasRated);
	$self->www_view;
}


#-------------------------------------------------------------------

=head2 www_redirectToParent ( )

This is here to stop people from duplicating posts by hitting refresh in their browser.

=cut 

sub www_redirectToParent {
	my $self = shift;
	WebGUI::HTTP::setRedirect($self->getParent->getUrl);
}



#-------------------------------------------------------------------
sub www_view {
	my $self = shift;
	$self->markRead;
	$self->incrementViews;
	return $self->getThread->www_view($self->getId);
}


1;

