package WebGUI::Forum::Post;

use WebGUI::DateTime;
use WebGUI::Forum::Thread;
use WebGUI::Session;
use WebGUI::SQL;

sub addView {
	my ($self) = @_;
	WebGUI::SQL->write("update forumPost set views=views+1 where forumPostId=".$self->get("forumPostId"));
	$self->getThread->addView;
}

sub create {
	my ($self, $data) = @_;
	$data->{forumPostId} = "new";
	$data->{dateOfPost} = WebGUI::DateTime::time();
	my $forumPostId = WebGUI::SQL->setRow("forumPost","forumPostId",$data);
	$self = WebGUI::Forum::Post->new($forumPostId);
	if ($data->{parentId} > 0) {
		$self->getThread->addReply($forumPostId,$self->get("dateOfPost"));
	}
	return $self;
}

sub get {
	my ($self, $key) = @_;
	if ($key eq "") {
		return $self->{_properties};
	}
	return $self->{_properties}->{$key};
}

sub getThread {
	my ($self) = @_;
	unless (exists $self->{_thread}) {
		$self->{_thread} = WebGUI::Forum::Thread->new($self->get("forumThreadId"));
	}
	return $self->{_thread};
}

sub isMarkedRead {
	my ($self, $userId) = @_;
	$userId = $session{user}{userId} unless ($userId);
	my ($isRead) = WebGUI::SQL->quickArray("select count(*) from forumRead where userId=$userId and forumPostId=".$self->get("forumPostId"));
	return $isRead;
}

sub markRead {
	my ($self, $userId) = @_;
	$userId = $session{user}{userId} unless ($userId);
	unless (isMarkedRead($userId)) {
		WebGUI::SQL->write("insert into forumRead (userId, forumPostId, forumThreadId, lastRead) values ($userId,
			".$self->get("forumPostId").", ".$self->get("forumThreadId").", ".WebGUI::DateTime::time().")");
	}
}

sub new {
	my ($self, $forumPostId) = @_;
	my $properties = WebGUI::SQL->getRow("forumPost","forumPostId",$forumPostId);
	bless {_properties=>$properties}, $self;
}

sub set {
	my ($self, $data) = @_;
	$data->{forumPostId} = $self->get("forumPostId") unless ($data->{forumId});
	WebGUI::SQL->setRow("forumPost","forumPostId",$data);
	$self->{_properties} = $data;
}

sub setStatusApproved {
	my ($self) = @_;
	$self->set({status=>'approved'});
}

sub setStatusDenied {
	my ($self) = @_;
	$self->set({status=>'denied'});
}

sub setStatusPending {
	my ($self) = @_;
	$self->set({status=>'pending'});
}

sub unmarkRead {
	my ($self, $userId) = @_;
	$userId = $session{user}{userId} unless ($userId);
	WebGUI::SQL->write("delete from forumRead where userId=$userId and forumPostId=".$self->get("forumPostId"));
}

1;

