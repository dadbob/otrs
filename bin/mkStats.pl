#! /usr/bin/perl
# --
# mkStats.pl - generate stats pics
# Copyright (C) 2002 Martin Edenhofer <martin+code@otrs.org>
# --
# $Id: mkStats.pl,v 1.18 2003-01-23 22:50:08 martin Exp $
# --
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# --

# use ../ as lib location
use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin)."/Kernel/cpan-lib";

umask 022;

use strict;

use Getopt::Std;
use File::Path;
use File::Basename;
use GD;
use GD::Graph;
use GD::Graph::lines;
use Date::Pcalc qw(Today_and_Now Days_in_Month Day_of_Week Day_of_Week_Abbreviation);
use Kernel::System::DB;
use Kernel::Config;
use Kernel::System::Log;

use vars qw($VERSION %Opts);
$VERSION = '$Revision: 1.18 $';
$VERSION =~ s/^.*:\s(\d+\.\d+)\s.*$/$1/;

# --
# get opts
# --
getopt('hxyjmdf',  \%Opts);
# --
# print head
# --
print "mkStats.pl <Revision $VERSION> - generate png pics\n";
print "Copyright (c) 2002 Martin Edenhofer <martin\@otrs.org>\n";
print "usage: mkStats.pl -j <year> -m <month> -x <width> (default 550) -y <height> (default 350)\n";
print "        -f <force> (default 0)\n";
# --
# common objects
# --
my %CommonObject = ();
$CommonObject{ConfigObject} = Kernel::Config->new();
$CommonObject{LogObject} = Kernel::System::Log->new(
    LogPrefix => 'OTRS-mkStats',
    %CommonObject,
);
$CommonObject{DBObject} = Kernel::System::DB->new(%CommonObject);

my $PicDataDir = $CommonObject{ConfigObject}->Get('StatsPicDir') 
  || die 'No StatsPicDir in Kenrel::Config.pm!';

# --
# get date infos
# --
my ($Year, $Month) = Today_and_Now();
if ($Opts{'j'}) {
    $Year = $Opts{'j'};
}
if ($Opts{'m'}) {
    $Month = $Opts{'m'};
}
if ($Month <= 9) {
    $Month = '0'.$Month;
}
my $Day = Days_in_Month($Year,$Month);
# --
# check min values
# --
if ($Opts{'x'} && $Opts{'x'} < 350 && !$Opts{'f'}) {
    print "ERROR: -x min. 350!\n";
    exit 1;
}
if ($Opts{'y'} && $Opts{'y'} < 350 && !$Opts{'f'}) {
    print "ERROR: -y min. 350!\n";
    exit 1;
}

print "->> creating stats for $Year/$Month <<-\n";

my $graph = GD::Graph::lines->new($Opts{'x'} || 550, $Opts{'y'} || 350);

my $XLable = "Days";
my $YLable = 'Actions';
my $Title  = "OTRS stats for $Month/$Year";

my %States = GetHistoryTypes();
my @PossibleStates;
foreach (keys %States) {
    push (@PossibleStates, $States{$_});
}
# --
# set graph
# --
$graph->set(
    x_label           => $XLable,
    y_label           => $YLable,
    title             => $Title,
#		y_max_value       => 20,
#            y_tick_number     => 16,
#		y_label_skip      => 4,
#            x_tick_number     => 8,
    t_margin => 10, b_margin => 10, l_margin => 10, r_margin => 20,
    bgclr => 'white',
    transparent => 0,
    interlaced => 1,
    fgclr => 'black',
    boxclr => 'white',
    accentclr => 'black',
    shadowclr => 'black',
    legendclr => 'black',
    textclr => 'black',
    dclrs => [ qw(red green blue yellow black purple orange pink marine cyan lgray lblue lyellow lgreen lred lpurple lorange lbrown) ],
    x_tick_offset => 0,
    x_label_position => 1/2, y_label_position => 1/2,
    x_labels_vertical => 31,
    
    line_width => 1,
    
    legend_placement => 'BC', legend_spacing => 4,
    legend_marker_width => 12, legend_marker_height => 8,
);
# --
# set legend
# --
$graph->set_legend(@PossibleStates);
# --
# build x_lable
# --
my $DayCounter = 1; 
my @Days;
while ($Day >= $DayCounter) {
    my $Dow = Day_of_Week($Year, $Month, $DayCounter);
    $Dow = Day_of_Week_Abbreviation($Dow);
    my $Text = $DayCounter;
    $Text = "$Dow $DayCounter";
    push (@Days,$Text);
    # --
    # debug
    # --
    if ($Opts{'d'}) {
        print "build x_lable: $Year, $Month, $DayCounter -=> $Dow\n";
    }
    $DayCounter++;
}
# --
# get data ...
# --
my @Data = (\@Days); 
my %AHash;
foreach (keys %States) {
    my @TmpData = GetDBDataPerMonth($Day, $_);
    push (@Data, \@TmpData);
}

# --
# plot graph
# --
my $ext = '';
if (!$graph->can('png')) { 
    $ext = 'png';    
}
else {
    $ext = $graph->export_format;
    print "Can't write png! Write: $ext";
}
# --
# check path
# --
if (! -d $PicDataDir) {
    File::Path::mkpath([$PicDataDir], 0, 0775) || die $!;
}
print STDOUT " writing $PicDataDir/$Year-$Month.$ext\n";
open (OUT, "> $PicDataDir/$Year-$Month.$ext") || die $!;
binmode OUT;
print OUT $graph->plot(\@Data)->$ext();
close();
# --
# GetDBDataPerMonth
# --
sub GetDBDataPerMonth {
    my $Days = shift;
    my $State = shift;
    my @Data;
    my $Counter=1;
    while ($Days >= $Counter) {
        my $DayData = 0;
        my $StartDate = $Counter;
        my $EndDate = $StartDate+1;
        my $SQL = "SELECT count(*) FROM ticket_history " .
        " WHERE " .
        " history_type_id = $State " .
        " AND " .
        " create_time >= '$Year-$Month-$StartDate 00:00:01'".
        " AND " .
        " create_time <= '$Year-$Month-$StartDate 23:59:59'";
        $CommonObject{DBObject}->Prepare(SQL => $SQL);
        while (my @RowTmp = $CommonObject{DBObject}->FetchrowArray()) {
            $DayData= $RowTmp[0];
        }
        # --
        # debug
        # --
        if ($Opts{'d'}) {
            print $State . " ($Year-$Month-$StartDate) " . $DayData . "\n";
        }
        push (@Data, $DayData);
        $Counter++;
    }
    return @Data;
}
# --
# GetHistoryTypes
# --
sub GetHistoryTypes {
    my %Stats;
    my $SQL = "SELECT id, name FROM ticket_history_type " .
    " WHERE " .
    " valid_id = 1";
    $CommonObject{DBObject}->Prepare(SQL => $SQL);
    while (my @RowTmp = $CommonObject{DBObject}->FetchrowArray()) {
        $Stats{$RowTmp[0]} = $RowTmp[1];
    }
    return %Stats;
}
# --
# the end
# --
exit (0);
