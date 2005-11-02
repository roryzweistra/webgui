package WebGUI::DateTime;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2005 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use DateTime;
use DateTime::Format::Strptime;
use DateTime::TimeZone;
use Exporter;
use strict;
use WebGUI::International;
use WebGUI::Session;
use WebGUI::Utility;

our @ISA = qw(Exporter);
our @EXPORT = qw(&localtime &time &addToTime &addToDate &epochToHuman &epochToSet &humanToEpoch &setToEpoch &monthStartEnd);



=head1 NAME

Package WebGUI::DateTime

=head1 DESCRIPTION

This package provides easy to use date math functions, which are normally a complete pain.

=head1 SYNOPSIS

 use WebGUI::DateTime;
 $epoch = WebGUI::DateTime::addToDate($epoch, $years, $months, $days);
 $epoch = WebGUI::DateTime::addToTime($epoch, $hours, $minutes, $seconds);
 ($startEpoch, $endEpoch) = WebGUI::DateTime::dayStartEnd($epoch);
 $dateString = WebGUI::DateTime::epochToHuman($epoch, $formatString);
 $setString = WebGUI::DateTime::epochToSet($epoch);
 $day = WebGUI::DateTime::getDayName($dayInteger);
 $integer = WebGUI::DateTime::getDaysInMonth($epoch);
 $integer = WebGUI::DateTime::getDaysInInterval($start, $end);
 $integer = WebGUI::DateTime::getFirstDayInMonthPosition($epoch);
 $month = WebGUI::DateTime::getMonthName($monthInteger);
 $seconds = WebGUI::DateTime::getSecondsFromEpoch($seconds);
 $zones = WebGUI::DateTime::getTimeZones();
 $epoch = WebGUI::DateTime::humanToEpoch($dateString);
 $seconds = WebGUI::DateTime::intervalToSeconds($interval, $units);
 @date = WebGUI::DateTime::localtime($epoch);
 ($startEpoch, $endEpoch) = WebGUI::DateTime::monthStartEnd($epoch);
 ($interval, $units) = WebGUI::DateTime::secondsToInterval($seconds);
 $timeString = WebGUI::DateTime::secondsToTime($seconds);
 $epoch = WebGUI::DateTime::setToEpoch($setString);
 $epoch = WebGUI::DateTime::time();
 $seconds = WebGUI::DateTime::timeToSeconds($timeString);

=head1 METHODS

These functions are available from this package:

=cut


#-------------------------------------------------------------------

=head2 addToDate ( epoch [ , years, months, days ] )

Returns an epoch date with the amount of time added.

=head3 epoch

The number of seconds since January 1, 1970.

=head3 years

The number of years to add to the epoch.

=head3 months

The number of months to add to the epoch.

=head3 days

The number of days to add to the epoch. 

=cut

sub addToDate {
	my $date		= DateTime->from_epoch( epoch =>shift);
	my $years 		= shift || 0;
	my $months 	= shift || 0;
	my $days	 	= shift || 0;
	my $currentTimeZone = $date->time_zone->name;
	$date->set_time_zone('UTC'); # do this to prevent date math errors due to daylight savings time shifts
	$date->add(years=>$years, months=>$months, days=>$days);
	$date->set_time_zone($currentTimeZone);
	return $date->epoch;
}

#-------------------------------------------------------------------

=head2 addToTime ( epoch [ , hours, minutes, seconds ] )

Returns an epoch date with the amount of time added.

=head3 epoch

The number of seconds since January 1, 1970.

=head3 hours

The number of hours to add to the epoch.

=head3 minutes

The number of minutes to add to the epoch.

=head3 seconds

The number of seconds to add to the epoch.

=cut

sub addToTime {
	my $date		= DateTime->from_epoch( epoch =>shift);
	my $hours 		= shift || 0;
	my $mins	 	= shift || 0;
	my $secs	 	= shift || 0;
	$date->add(hours=>$hours, minutes=>$mins, seconds=>$secs);
	return $date->epoch;
}

#-------------------------------------------------------------------

=head2 dayStartEnd ( epoch )

Returns the epoch dates for the start and end of the day.

=head3 epoch

The number of seconds since January 1, 1970.

=cut

sub dayStartEnd {
	my $dt = DateTime->from_epoch( epoch => shift);
	my $end = $dt->clone;	
	$dt->set_hour(0);
	$dt->set_minute(0);
	$dt->set_second(0);
	$end->set_hour(23);
	$end->set_minute(59);
	$end->set_second(59);
        return ($dt->epoch, $end->epoch);
}


#-------------------------------------------------------------------

=head2 epochToHuman ( [ epoch, format ] )

Returns a formated date string.

=head3 epoch

The number of seconds since January 1, 1970. Defaults to NOW!

=head3 format 

A string representing the output format for the date. Defaults to '%z %Z'. You can use the following to format your date string:

 %% = % (percent) symbol.
 %c = The calendar month name.
 %C = The calendar month name abbreviated.
 %d = A two digit day.
 %D = A variable digit day.
 %h = A two digit hour (on a 12 hour clock).
 %H = A variable digit hour (on a 12 hour clock).
 %j = A two digit hour (on a 24 hour clock).
 %J = A variable digit hour (on a 24 hour clock).
 %m = A two digit month.
 %M = A variable digit month.
 %n = A two digit minute.
 %O = Offset from GMT/UTC represented in four digit form with a sign. Example: -0600
 %p = A lower-case am/pm.
 %P = An upper-case AM/PM.
 %s = A two digit second.
 %w = Day of the week. 
 %W = Day of the week abbreviated. 
 %y = A four digit year.
 %Y = A two digit year. 
 %z = The current user's date format preference.
 %Z = The current user's time format preference.

=cut

sub epochToHuman {
	my $language = WebGUI::International::get($session{user}{language});
	my $locale = $language->{languageAbbreviation} || "en";
	$locale .= "_".$language->{locale} if ($language->{locale});
	my $dt = DateTime->from_epoch( epoch=>shift||time(), time_zone=>$session{user}{timeZone}, locale=>$locale );
	my $output = shift || "%z %Z";
	my $temp;
  #---date format preference
	$temp = $session{user}{dateFormat} || '%M/%D/%y';
	$output =~ s/\%z/$temp/g;
  #---time format preference
	$temp = $session{user}{timeFormat} || '%H:%n %p';
	$output =~ s/\%Z/$temp/g;
  #--- convert WebGUI date formats to DateTime formats
	my %conversion = (
		"c" => "B",
		"C" => "b",
		"d" => "d",
		"D" => "e",
		"h" => "I",
		"H" => "l",
		"j" => "H",
		"J" => "k",
		"m" => "m",
		"M" => "_varmonth_",
		"n" => "M",
		"O" => "z",
		"p" => "P",
		"P" => "p",
		"s" => "S",
		"w" => "A",
		"W" => "a",
		"y" => "Y",
		"Y" => "y"
		);
	$output =~ s/\%(\w)/\~$1/g;
	foreach my $key (keys %conversion) {
		my $replacement = $conversion{$key};
		$output =~ s/\~$key/\%$replacement/g;
	}
  #--- %M
	$output = $dt->strftime($output);
	$temp = int($dt->month);
	$output =~ s/\%_varmonth_/$temp/g;
  #--- return
	return $output;
}

#-------------------------------------------------------------------

=head2 epochToSet ( epoch, withTime )

Returns a set date (used by WebGUI::HTMLForm->date) in the format of YYYY-MM-DD. 

=head3 epoch

The number of seconds since January 1, 1970.

=head3 withTime

A boolean indicating that the time should be added to the output, thust turning the format into YYYY-MM-DD HH:MM:SS.

=cut

sub epochToSet {
	my $dt = DateTime->from_epoch( epoch =>shift, time_zone=>$session{user}{timeZone});
	my $withTime = shift;
	if ($withTime) {
		return $dt->strftime("%Y-%m-%d %H:%M:%S");
	}
	return $dt->strftime("%Y-%m-%d");
}

#-------------------------------------------------------------------

=head2 getDayName ( day )

Returns a string containing the weekday name in the language of the current user. 

=head3 day

An integer ranging from 1-7 representing the day of the week (Sunday is 1 and Saturday is 7). 

=cut

sub getDayName {
	my $day = $_[0];
        if ($day == 7) {
                return WebGUI::International::get('sunday','DateTime');
        } elsif ($day == 1) {
                return WebGUI::International::get('monday','DateTime');
        } elsif ($day == 2) {
                return WebGUI::International::get('tuesday','DateTime');
        } elsif ($day == 3) {
                return WebGUI::International::get('wednesday','DateTime');
        } elsif ($day == 4) {
                return WebGUI::International::get('thursday','DateTime');
        } elsif ($day == 5) {
                return WebGUI::International::get('friday','DateTime');
        } elsif ($day == 6) {
                return WebGUI::International::get('saturday','DateTime');
        }
}

#-------------------------------------------------------------------

=head2 getDaysInMonth ( epoch )

Returns the total number of days in the month.

=head3 epoch

An epoch date.

=cut

sub getDaysInMonth {
	my $dt = DateTime->from_epoch( epoch =>shift);
	my $last = DateTime->last_day_of_month(year=>$dt->year, month=>$dt->month);
	return $last->day;
}


#-------------------------------------------------------------------

=head2 getDaysInInterval ( start, end )

Returns the number of days between two epoch dates.

=head3 start

An epoch date.

=head3 end

An epoch date.

=cut

sub getDaysInInterval {
	my $start = DateTime->from_epoch( epoch =>shift);
	my $end = DateTime->from_epoch( epoch =>shift);
	my $duration = $end - $start;
	return $duration->delta_days;
}


#-------------------------------------------------------------------

=head2 getFirstDayInMonthPosition ( epoch) {

Returns the position (1 - 7) of the first day in the month. 1 is Monday.

=head3 epoch

An epoch date.

=cut

sub getFirstDayInMonthPosition {
	my $dt = DateTime->from_epoch( epoch => shift );
	$dt->set_day(1);
	return $dt->day_of_week;
}


#-------------------------------------------------------------------

=head2 getMonthName ( month )

Returns a string containing the calendar month name in the language of the current user.

=head3 month

An integer ranging from 1-12 representing the month.

=cut

sub getMonthName {
        if ($_[0] == 1) {
                return WebGUI::International::get('january','DateTime');
        } elsif ($_[0] == 2) {
                return WebGUI::International::get('february','DateTime');
        } elsif ($_[0] == 3) {
                return WebGUI::International::get('march','DateTime');
        } elsif ($_[0] == 4) {
                return WebGUI::International::get('april','DateTime');
        } elsif ($_[0] == 5) {
                return WebGUI::International::get('may','DateTime');
        } elsif ($_[0] == 6) {
                return WebGUI::International::get('june','DateTime');
        } elsif ($_[0] == 7) {
                return WebGUI::International::get('july','DateTime');
        } elsif ($_[0] == 8) {
                return WebGUI::International::get('august','DateTime');
        } elsif ($_[0] == 9) {
                return WebGUI::International::get('september','DateTime');
        } elsif ($_[0] == 10) {
                return WebGUI::International::get('october','DateTime');
        } elsif ($_[0] == 11) {
                return WebGUI::International::get('november','DateTime');
        } elsif ($_[0] == 12) {
                return WebGUI::International::get('december','DateTime');
        }
}

#-------------------------------------------------------------------

=head2 getSecondsFromEpoch ( epoch )

Calculates the number of seconds into the day of an epoch date the epoch datestamp is.

=head3 epoch

The number of seconds since January 1, 1970 00:00:00.

=cut

sub getSecondsFromEpoch {
	my $dt = DateTime->from_epoch( epoch => shift );
	my $start = $dt->clone;
	$start->set_hour(0);
        $start->set_minute(0);
        $start->set_second(0);	
	my $duration = $dt - $start;
	return $duration->delta_seconds;
}


#-------------------------------------------------------------------

=head2 getTimeZones ( ) 

Returns a hash reference containing name/value pairs both with the list of time zones.

=cut

sub getTimeZones {
	my %zones;
	foreach my $zone (@{DateTime::TimeZone::all_names()}) {
		my $zoneLabel = $zone;
		$zoneLabel =~ s/\_/ /g;
		$zones{$zone} = $zoneLabel;	
	}
	return \%zones;
}


#-------------------------------------------------------------------

=head2 humanToEpoch ( date )

Returns an epoch date derived from the human date.

=head3 date

The human date string. YYYY-MM-DD HH:MM:SS 

=cut

sub humanToEpoch {
	my ($dateString,$timeString) = split(/ /,shift);
	my @date = split(/-/,$dateString);
	my @time = split(/:/,$timeString);
	my $dt = DateTime->new(year => $date[0], month=> $date[1], day=> $date[2], hour=> $time[0], minute => $time[1], second => $time[2]);
	return $dt->epoch;
} 

#-------------------------------------------------------------------

=head2 intervalToSeconds ( interval, units )

Returns the number of seconds derived from the interval.

=head3 interval

An integer which represents the amount of time for the interval.

=head3 units

A string which represents the units of the interval. The string must be 'years', 'months', 'weeks', 'days', 'hours', 'minutes', or 'seconds'. 

=cut

sub intervalToSeconds {
	my $interval = shift;
	my $units = shift;
	if ($units eq "years") {
		return ($interval*31536000);
	} elsif ($units eq "months") {
		return ($interval*2592000);
        } elsif ($units eq "weeks") {
                return ($interval*604800);
        } elsif ($units eq "days") {
                return ($interval*86400);
        } elsif ($units eq "hours") {
                return ($interval*3600);
        } elsif ($units eq "minutes") {
                return ($interval*60);
        } else {
                return $interval;
	} 
}

#-------------------------------------------------------------------

=head2 localtime ( epoch )

Returns an array of time elements. The elements are: years, months, days, hours, minutes, seconds, day of year, day of week, daylight savings.

=head3 epoch

The number of seconds since January 1, 1970. Defaults to now.

=cut

sub localtime {
	my $dt = DateTime->from_epoch( epoch => shift || time() );
	return ( $dt->year, $dt->month, $dt->day, $dt->hour, $dt->minute, $dt->second, $dt->day_of_year, $dt->day_of_week, $dt->is_dst );
}

#-------------------------------------------------------------------
=head2 monthCount ( startEpoch, endEpoch )

Returns the number of months between the start and end dates (inclusive).

=head3 startEpoch

An epoch datestamp corresponding to the first month.

=head3 endEpoch

An epoch datestamp corresponding to the last month.

=cut

sub monthCount {
	my $start = DateTime->from_epoch( epoch => shift );
	my $end = DateTime->from_epoch( epoch => shift );
	my $duration = $end - $start;
	return $duration->delta_months;
}


#-------------------------------------------------------------------

=head2 monthStartEnd ( epoch )

Returns the epoch dates for the start and end of the month.

=head3 epoch

The number of seconds since January 1, 1970.

=cut

sub monthStartEnd {
	my $dt = DateTime->from_epoch( epoch => shift);
	my $end = DateTime->last_day_of_month(year=>$dt->year, month=>$dt->month);	
	$dt->set_hour(0);
	$dt->set_minute(0);
	$dt->set_second(0);
	$end->set_hour(23);
	$end->set_minute(59);
	$end->set_second(59);
        return ($dt->epoch, $end->epoch);
}

#-------------------------------------------------------------------

=head2 secondsToInterval ( seconds )

Returns an interval and units derived the number of seconds.

=head3 seconds

The number of seconds in the interval. 

=cut

sub secondsToInterval {
	my $seconds = shift;
	my ($interval, $units);
	if ($seconds >= 31536000) {
		$interval = round($seconds/31536000);
		$units = "years";
	} elsif ($seconds >= 2592000) {
                $interval = round($seconds/2592000);
                $units = "months";
	} elsif ($seconds >= 604800) {
                $interval = round($seconds/604800);
                $units = "weeks";
	} elsif ($seconds >= 86400) {
                $interval = round($seconds/86400);
                $units = "days";
        } elsif ($seconds >= 3600) {
                $interval = round($seconds/3600);
                $units = "hours";
        } elsif ($seconds >= 60) {
                $interval = round($seconds/60);
                $units = "minutes";
        } else {
                $interval = $seconds;
                $units = "seconds";
	}
	return ($interval, $units);
}

#-------------------------------------------------------------------

=head2 secondsToTime ( seconds )

Returns a time string of the format HH::MM::SS on a 24 hour clock. See also timeToSeconds().

=head3 seconds

A number of seconds. 

=cut

sub secondsToTime {
	my $seconds = shift;
	my $timeString = sprintf("%02d",int($seconds / 3600)).":";
	$seconds = $seconds % 3600;	
	$timeString .= sprintf("%02d",int($seconds / 60)).":";
	$seconds = $seconds % 60;
	$timeString .= sprintf("%02d",$seconds);
	return $timeString;
}


#-------------------------------------------------------------------

=head2 setToEpoch ( set )

Returns an epoch date.

=head3 set

A string in the format of YYYY-MM-DD or YYYY-MM-DD HH:MM:SS.

=cut

sub setToEpoch {
        my $set = shift;
	my $parser = DateTime::Format::Strptime->new( pattern => '%Y-%m-%d %H:%M:%S' );
	my $dt = $parser->parse_datetime($set);
	# in epochToSet we apply the user's time zone, so now we have to remove it.
	$dt->set_time_zone($session{user}{timeZone}); # assign the user's timezone
	my $u = WebGUI::User->new(1);
	$dt->set_time_zone($u->profileField("timeZone")); # convert to the visitor's or default time zone
	return $dt->epoch;
}

#-------------------------------------------------------------------

=head2 time ( )

Returns an epoch date for now.

=cut

sub time {
	return time();
}

#-------------------------------------------------------------------

=head2 timeToSeconds ( timeString )

Returns the seconds since 00:00:00 on a 24 hour clock.

=head3 timeString

A string that looks similar to this: 15:05:32

=cut

sub timeToSeconds {
	my ($hour,$min,$sec) = split(/:/,$_[0]);
	return ($hour*60*60+$min*60+$sec);
}


1;
