# --
# Kernel/Modules/AgentHistory.pm - to add notes to a ticket
# Copyright (C) 2001-2005 Martin Edenhofer <martin+code@otrs.org>
# --
# $Id: AgentHistory.pm,v 1.20 2005-02-15 11:58:12 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::Modules::AgentHistory;

use strict;

use vars qw($VERSION);
$VERSION = '$Revision: 1.20 $';
$VERSION =~ s/^\$.*:\W(.*)\W.+?$/$1/;

# --
sub new {
    my $Type = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless ($Self, $Type);

    foreach (keys %Param) {
        $Self->{$_} = $Param{$_};
    }

    # check needed Opjects
    foreach (qw(DBObject TicketObject LayoutObject LogObject UserObject ConfigObject)) {
        die "Got no $_!" if (!$Self->{$_});
    }

    return $Self;
}
# --
sub Run {
    my $Self = shift;
    my %Param = @_;
    my $Output;
    # --
    # check needed stuff
    # --
    if (!$Self->{TicketID}) {
      # error page
      return $Self->{LayoutObject}->ErrorScreen(
          Message => "Can't show history, no TicketID is given!",
          Comment => 'Please contact the admin.',
      );
    }
    # --
    # check permissions
    # --
    if (!$Self->{TicketObject}->Permission(
        Type => 'ro',
        TicketID => $Self->{TicketID},
        UserID => $Self->{UserID})) {
        # error screen, don't show ticket
        return $Self->{LayoutObject}->NoPermission(WithHeader => 'yes');
    }
    # --
    # build header
    # --
    $Output .= $Self->{LayoutObject}->Header(Area => 'Ticket', Title => 'History');
    $Output .= $Self->{LayoutObject}->NavigationBar();

    my @Lines = $Self->{TicketObject}->HistoryGet(
        TicketID => $Self->{TicketID},
        UserID => $Self->{UserID},
    );
    my $Tn = $Self->{TicketObject}->TicketNumberLookup(TicketID => $Self->{TicketID});
    # get shown user info
    my @NewLines = ();
    if ($Self->{ConfigObject}->Get('Ticket::Frontend::HistoryOrder') eq 'reverse') {
        @NewLines = reverse (@Lines);
    }
    else {
        @NewLines = @Lines;
    }
    my $Table = '';
    foreach my $DataTmp (@NewLines) {
        my %Data = %{$DataTmp};
        # replace text
        if ($Data{Name} && $Data{Name} =~ /^%%/) {
            my %Info = ();
            $Data{Name} =~ s/^%%//g;
            my @Values = split(/%%/, $Data{Name});
            $Data{Name} = '';
            foreach (@Values) {
                if ($Data{Name}) {
                    $Data{Name} .= "\", ";
                }
                $Data{Name} .= "\"$_";
            }
            if (!$Data{Name}) {
                $Data{Name} = '" ';
            }
            $Data{Name} = $Self->{LayoutObject}->{LanguageObject}->Get('History::'.$Data{HistoryType}.'", '.$Data{Name});
        }
        $Self->{LayoutObject}->Block(
            Name => "Row",
            Data => {%Data},
        );
    }
    # get output
    $Output .= $Self->{LayoutObject}->Output(
            TemplateFile => 'AgentHistoryForm',
            Data => {
                TicketNumber => $Tn,
                TicketID => $Self->{TicketID},
            },
        );
    # add footer
    $Output .= $Self->{LayoutObject}->Footer();

    return $Output;
}
# --

1;
