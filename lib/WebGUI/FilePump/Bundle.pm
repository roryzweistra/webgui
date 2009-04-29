package FilePump::Bundle;

use base qw/WebGUI::Crud/;
use WebGUI::International;

#-------------------------------------------------------------------

=head2 addCssFile ( $uri )

Adds a CSS file to the bundle.  Returns 1 if the add was successful.
Otherwise, returns 0 and an error message as to why it was not successful.

=head3 $uri

A URI to the new file to add.

=cut

sub addCssFile {
    my ($self, $uri) = @_;
    return 0, 'No URI' unless $uri;
    $self->setCollateral(
        'cssFiles',
        'fileId',
        'new',
        {
            uri          =>  $uri,
            lastModified => 0,
        },
    );
}

#-------------------------------------------------------------------

=head2 addJsFile ( $uri )

Adds a javascript file to the bundle.  Returns 1 if the add was successful.
Otherwise, returns 0 and an error message as to why it was not successful.

=head3 $uri

A URI to the new file to add.

=cut

sub addJsFile {
    my ($self, $uri) = @_;
    return 0, 'No URI' unless $uri;
    $self->setCollateral(
        'jsFiles',
        'fileId',
        'new',
        {
            uri          =>  $uri,
            lastModified => 0,
        },
    );
}

#-------------------------------------------------------------------

=head2 addOtherFile ( $uri )

Adds an Other file to the bundle.  Returns 1 if the add was successful.
Otherwise, returns 0 and an error message as to why it was not successful.

=head3 $uri

A URI to the new file to add.

=cut

sub addOtherFile {
    my ($self, $uri) = @_;
    return 0, 'No URI' unless $uri;
    $self->setCollateral(
        'otherFiles',
        'fileId',
        'new',
        {
            uri          =>  $uri,
            lastModified => 0,
        },
    );
}

#-------------------------------------------------------------------

=head2 crud_definition

WebGUI::Crud definition for this class.

=head3 tableName

filePumpBundle

=head3 tableKey

bundleId

=head3 sequenceKey

None.  Bundles have no sequence amongst themselves.

=head3 properties

=head4 bundleName

The name of a bundle

=head4 lastBuild

The date the bundle was last built

=head4 jsFiles, cssFiles, otherFiles

JSON blobs with files attached to the bundle. js = javascript, css = Cascading Style Sheets, other
means anything else.

=cut

sub crud_definition {
    my ($class, $session) = @_;
    my $definition = $class->SUPER::crud_definition($session);
    my $i18n = WebGUI::International->new($session, 'FilePump');
    $definition->{tableName}   = 'filePumpBundle';
    $definition->{tableKey}    = 'bundleId';
    $definition->{sequenceKey} = '';
    my $properties = $definition->{properties};
    $properties->{bucketName} = {
        fieldName    => 'text',
        defaultValue => $i18n->get('new bundle'),
    };
    $properties->{lastBuild} = {
        fieldName    => 'integer',
        defaultValue => 0,
    };
    $properties->{jsFiles} = {
        fieldName    => 'textarea',
        defaultValue => 0,
        serialize    => 1,
    };
    $properties->{cssFiles} = {
        fieldName    => 'textarea',
        defaultValue => 0,
        serialize    => 1,
    };
    $properties->{otherFiles} = {
        fieldName    => 'textarea',
        defaultValue => 0,
        serialize    => 1,
    };
}

#-------------------------------------------------------------------

=head2 deleteCollateral ( tableName, keyName, keyValue )

Deletes a row of collateral data.

=head3 tableName

The name of the table you wish to delete the data from.

=head3 keyName

The name of a key in the collateral hash.  Typically a unique identifier for a given
"row" of collateral data.

=head3 keyValue

Along with keyName, determines which "row" of collateral data to delete.

=cut

sub deleteCollateral {
    my $self      = shift;
    my $tableName = shift;
    my $keyName   = shift;
    my $keyValue  = shift;
    my $table = $self->getAllCollateral($tableName);
    my $index = $self->getCollateralDataIndex($table, $keyName, $keyValue);
    return if $index == -1;
    splice @{ $table }, $index, 1;
    $self->setAllCollateral($tableName);
}

#-------------------------------------------------------------------

=head2 getAllCollateral ( tableName )

Returns an array reference to the translated JSON data for the
requested collateral table.

=head3 tableName

The name of the table you wish to retrieve the data from.

=cut

sub getAllCollateral {
    my $self      = shift;
    my $tableName = shift;
    return $self->{_collateral}->{$tableName} if exists $self->{_collateral}->{$tableName};
    my $json = $self->get($tableName);
    my $table;
    if ($json) {
        $table = from_json($json);
    }
    else {
        $table = [];
    }
    $self->{_collateral}->{$tableName} = $table;
    return $table;
}


#-------------------------------------------------------------------

=head2 getCollateral ( tableName, keyName, keyValue )

Returns a hash reference containing one row of collateral data from a particular
table.

=head3 tableName

The name of the table you wish to retrieve the data from.

=head3 keyName

The name of a key in the collateral hash.  Typically a unique identifier for a given
"row" of collateral data.

=head3 keyValue

Along with keyName, determines which "row" of collateral data to delete.
If this is equal to "new", then an empty hashRef will be returned to avoid
strict errors in the caller.  If the requested data does not exist in the
collateral array, it also returns an empty hashRef.

=cut

sub getCollateral {
    my $self      = shift;
    my $tableName = shift;
    my $keyName   = shift;
    my $keyValue  = shift;
    if ($keyValue eq "new" || $keyValue eq "") {
        return {};
    }
    my $table = $self->getAllCollateral($tableName);
    my $index = $self->getCollateralDataIndex($table, $keyName, $keyValue);
    return {} if $index == -1;
    my %copy = %{ $table->[$index] };
    return \%copy;
}


#-------------------------------------------------------------------

=head2 getCollateralDataIndex ( table, keyName, keyValue )

Returns the index in a set of collateral where an element of the
data (keyName) has a certain value (keyValue).  If the criteria
are not found, returns -1.

=head3 table

The collateral data to search

=head3 keyName

The name of a key in the collateral hash.

=head3 keyValue

The value that keyName should have to meet the criteria.

=cut

sub getCollateralDataIndex {
    my $self     = shift;
    my $table    = shift;
    my $keyName  = shift;
    my $keyValue = shift;
    for (my $index=0; $index <= $#{ $table }; $index++) {
        return $index
            if (exists $table->[$index]->{$keyName} and $table->[$index]->{$keyName} eq $keyValue );
    }
    return -1;
}

#-------------------------------------------------------------------

=head2 moveCollateralDown ( tableName, keyName, keyValue )

Moves a collateral data item down one position.  If called on the last element of the
collateral array then it does nothing.

=head3 tableName

A string indicating the table that contains the collateral data.

=head3 keyName

The name of a key in the collateral hash.  Typically a unique identifier for a given
"row" of collateral data.

=head3 keyValue

Along with keyName, determines which "row" of collateral data to move.

=cut

sub moveCollateralDown {
    my $self      = shift;
    my $tableName = shift;
    my $keyName   = shift;
    my $keyValue  = shift;

    my $table = $self->getAllCollateral($tableName);
    my $index = $self->getCollateralDataIndex($table, $keyName, $keyValue);
    return if $index == -1;
    return unless (abs($index) < $#{$table});
    @{ $table }[$index,$index+1] = @{ $table }[$index+1,$index];
    $self->setAllCollateral($tableName);
}


#-------------------------------------------------------------------

=head2 moveCollateralUp ( tableName, keyName, keyValue )

Moves a collateral data item up one position.  If called on the first element of the
collateral array then it does nothing.

=head3 tableName

A string indicating the table that contains the collateral data.

=head3 keyName

The name of a key in the collateral hash.  Typically a unique identifier for a given
"row" of collateral data.

=head3 keyValue

Along with keyName, determines which "row" of collateral data to move.

=cut

sub moveCollateralUp {
    my $self      = shift;
    my $tableName = shift;
    my $keyName   = shift;
    my $keyValue  = shift;

    my $table = $self->getAllCollateral($tableName);
    my $index = $self->getCollateralDataIndex($table, $keyName, $keyValue);
    return if $index == -1;
    return unless $index && (abs($index) <= $#{$table});
    @{ $table }[$index-1,$index] = @{ $table }[$index,$index-1];
    $self->setAllCollateral($tableName);
}

#-------------------------------------------------------------------

=head2 reorderCollateral ( tableName,keyName [,setName,setValue] )

Resequences collateral data. Typically useful after deleting a collateral item to remove the gap created by the deletion.

=head3 tableName

The name of the table to resequence.

=head3 keyName

The key column name used to determine which data needs sorting within the table.

=head3 setName

Defaults to "assetId". This is used to define which data set to reorder.

=head3 setValue

Used to define which data set to reorder. Defaults to the value of setName (default "assetId", see above) in the wobject properties.

=cut

sub reorderCollateral {
    my $self = shift;
    my $table = shift;
    my $keyName = shift;
    my $setName = shift || "assetId";
    my $setValue = shift || $self->get($setName);
    my $i = 1;
    my $sth = $self->session->db->read("select $keyName from $table where $setName=? order by sequenceNumber", [$setValue]);
    my $sth2 = $self->session->db->prepare("update $table set sequenceNumber=? where $setName=? and $keyName=?");
    while (my ($id) = $sth->array) {
        $sth2->execute([$i, $setValue, $id]);
        $i++;
    }
    $sth2->finish;
    $sth->finish;
}


#-----------------------------------------------------------------

=head2 setAllCollateral ( tableName )

Update the db from the object cache.

=head3 tableName

The name of the table to insert the data.

=cut

sub setAllCollateral {
    my $self       = shift;
    my $tableName  = shift;
    my $json = to_json($self->{_collateral}->{$tableName});
    $self->update({ $tableName => $json });
    return;
}

#-----------------------------------------------------------------

=head2 setCollateral ( tableName, keyName, keyValue, properties )

Performs and insert/update of collateral data for any wobject's collateral data.
Returns the id of the data that was set, even if a new row was added to the
data.

=head3 tableName

The name of the table to insert the data.

=head3 keyName

The name of a key in the collateral hash.  Typically a unique identifier for a given
"row" of collateral data.

=head3 keyValue

Along with keyName, determines which "row" of collateral data to set.
The index of the collateral data to set.  If the keyValue = "new", then a
new entry will be appended to the end of the collateral array.  Otherwise,
the appropriate entry will be overwritten with the new data.

=head3 properties

A hash reference containing the name/value pairs to be inserted into the collateral, using
the criteria mentioned above.

=cut

sub setCollateral {
    my $self       = shift;
    my $tableName  = shift;
    my $keyName    = shift;
    my $keyValue   = shift;
    my $properties = shift;
    ##Note, since this returns a reference, it is actually updating
    ##the object cache directly.
    my $table = $self->getAllCollateral($tableName);
    if ($keyValue eq 'new' || $keyValue eq '') {
        if (! exists $properties->{$keyName}
           or $properties->{$keyName} eq 'new'
           or $properties->{$keyName} eq '') {
            $properties->{$keyName} = $self->session->id->generate;
        }
        push @{ $table }, $properties;
        $self->setAllCollateral($tableName);
        return $properties->{$keyName};
    }
    my $index = $self->getCollateralDataIndex($table, $keyName, $keyValue);
    return if $index == -1;
    $table->[$index] = $properties;
    $self->setAllCollateral($tableName);
    return $keyValue;
}


1;
