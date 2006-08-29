# --
# Kernel/System/Lock.pm - All Groups related function should be here eventually
# Copyright (C) 2001-2006 OTRS GmbH, http://otrs.org/
# --
# $Id: Lock.pm,v 1.9 2006-08-29 17:30:36 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::System::Lock;

use strict;

use vars qw(@ISA $VERSION);
$VERSION = '$Revision: 1.9 $';
$VERSION =~ s/^\$.*:\W(.*)\W.+?$/$1/;

=head1 NAME

Kernel::System::Lock - lock lib

=head1 SYNOPSIS

All lock functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a object

    use Kernel::Config;
    use Kernel::System::Time;
    use Kernel::System::Log;
    use Kernel::System::DB;
    use Kernel::System::Lock;

    my $ConfigObject = Kernel::Config->new();
    my $TimeObject    = Kernel::System::Time->new(
        ConfigObject => $ConfigObject,
    );
    my $LogObject    = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        LogObject => $LogObject,
    );
    my $LockObject = Kernel::System::Lock->new(
        ConfigObject => $ConfigObject,
        LogObject => $LogObject,
        DBObject => $DBObject,
        TimeObject => $TimeObject,
    );

=cut

sub new {
    my $Type = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless ($Self, $Type);

    # check needed objects
    foreach (qw(DBObject ConfigObject LogObject)) {
        $Self->{$_} = $Param{$_} || die "Got no $_!";
    }

    # get ViewableLocks
    $Self->{ViewableLocks} = $Self->{ConfigObject}->Get('Ticket::ViewableLocks')
        || die 'No Config entry "Ticket::ViewableLocks"!';

    return $Self;
}

=item LockViewableLock()

get list of lock types

  my @List = $LockObject->LockViewableLock(
      Type => 'Viewable',
      Result => 'Name', # ID|Name
  );

  my @List = $LockObject->LockViewableLock(
      Type => 'Viewable',
      Result => 'ID', # ID|Name
  );

=cut

sub LockViewableLock {
    my $Self = shift;
    my %Param = @_;
    my @Name = ();
    my @ID = ();
    # check needed stuff
    foreach (qw(Type)) {
        if (!$Param{$_}) {
            $Self->{LogObject}->Log(Priority => 'error', Message => "Need $_!");
            return;
        }
    }
    # db quote
    foreach (keys %Param) {
        $Param{$_} = $Self->{DBObject}->Quote($Param{$_});
    }
    # sql
    my $SQL = "SELECT id, name ".
        " FROM ".
        " ticket_lock_type ".
        " WHERE ".
        " name IN ( ${\(join ', ', @{$Self->{ViewableLocks}})} ) " .
        " AND ".
        " valid_id IN ( ${\(join ', ', $Self->{DBObject}->GetValidIDs())} )";
    if ($Self->{DBObject}->Prepare(SQL => $SQL)) {
        while (my @Data = $Self->{DBObject}->FetchrowArray()) {
            push (@Name, $Data[1]);
            push (@ID, $Data[0]);
        }
        if ($Param{Type} eq 'Name') {
            return @Name;
        }
        else {
            return @ID;
        }
    }
}

=item LockLookup()

lock lookup

  my $LockID = $LockObject->LockLookup(Type => 'lock');

  my $Lock = $LockObject->LockLookup(ID => 2);

=cut

sub LockLookup {
    my $Self = shift;
    my %Param = @_;
    my $Key = '';
    # check needed stuff
    if (!$Param{Type} && $Param{ID}) {
        $Key = 'ID';
    }
    if ($Param{Type} && !$Param{ID}) {
        $Key = 'Type';
    }
    if (!$Param{Type} && !$Param{ID}) {
        $Self->{LogObject}->Log(Priority => 'error', Message => "Need Type od ID!");
        return;
    }
    # check if we ask the same request?
    if (exists $Self->{"Lock::Lookup::$Param{$Key}"}) {
        return $Self->{"Lock::Lookup::$Param{$Key}"};
    }
    # db query
    my $SQL = '';
    if ($Param{Type}) {
        $SQL = "SELECT id FROM ticket_lock_type WHERE name = '".$Self->{DBObject}->Quote($Param{Type})."'";
    }
    else {
        $SQL = "SELECT name FROM ticket_lock_type WHERE id = ".$Self->{DBObject}->Quote($Param{ID}, 'Integer');
    }
    $Self->{DBObject}->Prepare(SQL => $SQL);
    while (my @Row = $Self->{DBObject}->FetchrowArray()) {
        # store result
        $Self->{"Lock::Lookup::$Param{$Key}"} = $Row[0];
    }
    # check if data exists
    if (!exists $Self->{"Lock::Lookup::$Param{$Key}"}) {
        $Self->{LogObject}->Log(Priority => 'error', Message => "No Type/TypeID for $Param{$Key} found!");
        return;
    }
    else {
        return $Self->{"Lock::Lookup::$Param{$Key}"};
    }
}

=item LockList()

get lock list

  my %List = $LockObject->LockList(
      UserID => 123,
  );

=cut

sub LockList {
    my $Self = shift;
    my %Param = @_;
    # check needed stuff
    if (!$Param{UserID}) {
        $Self->{LogObject}->Log(Priority => 'error', Message => "UserID!");
        return;
    }
    # check cache
    if ($Self->{LockList}) {
        return %{$Self->{LockList}};
    }
    # sql
    my %Data = ();
    if ($Self->{DBObject}->Prepare(SQL => 'SELECT id, name FROM ticket_lock_type')) {
        while (my @Row = $Self->{DBObject}->FetchrowArray()) {
            $Data{$Row[0]} = $Row[1];
        }
    }
    # cache result
    $Self->{LockList} = \%Data;
    return %Data;
}
1;

=head1 TERMS AND CONDITIONS

This Software is part of the OTRS project (http://otrs.org/).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see http://www.gnu.org/licenses/gpl.txt.

=cut

=head1 VERSION

$Revision: 1.9 $ $Date: 2006-08-29 17:30:36 $

=cut
