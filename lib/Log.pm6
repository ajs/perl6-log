use v6;

use DateTime::Utils;

# Typical use:
#
#   our $logger = Log.get_logger(:level(Log.levels<debug>), :facility('myprog'))
#   $logger.debug("OK, I set up a logger");
#   $logger.critical("But now I give up");
#
# Repeated calls to Log.get_logger for a given facility will return
# the same logger object.

class Log {
    our %.levels = enum <<debug(1) info warning error critical>>;
    our %!loggers = ();

    has $.level is rw = Log.levels<warning>;
    has $.facility is ro = 'perl';
    has $.format is rw = '%Y-%m-%d %H:%M:%S: %f: %_: %L';
    has IO $.output is ro = $*STDERR;

    # Meant to be used as a class method or on a Log object interchangably
    method get_logger(:$level, :$facility, :$output) {
	return %!loggers{$facility}.exists ?? %!loggers{$facility} !!
	    (%!loggers{$facility} = self.new($:level, :$facility, :$output));
    }

    method log(Str $msg, $:level = Log.levels<info>) {
	$level = Log.levels($level) if $level ~~ Str;
	return if $level < self.level;
	self.output.say(self.format_log($.format, $msg));
    }
    method debug(Str $msg) { log($msg, :level<debug>) }
    method info(Str $msg) { log($msg, :level<info>) }
    method warning(Str $msg) { log($msg, :level<warning>) }
    method error(Str $msg) { log($msg, :level<error>) }
    method critical(Str $msg) { log($msg, :level<critical>) }

    # TODO: Consider long-form versions of all printf-style escapes.
    #       for example, %{log-message} perhaps with some modifiers
    #       like %{log-level :uc}

    # Formatting tokens are the same as DateTime::Utils::strftime,
    # except for the addition of:
    #  %L - log message
    #  %f - logging facility
    #  %U - user name
    #  %c - calling process name (the program that's logging)
    #  %_ - log level
    method format_log(Str $format is copy, Str $msg, :$level=None) {
	my %mapping = (
	    'L' => { $msg },
	    '_' => { $level // self.level },
	    'f' => { self.facility },
	    'U' => { %*ENV<USER> },
	    'c' => { $*PROGRAM_NAME },
	    # We need to claim the %% escapes so that "%%%Y" expands correctly
	    '%' => { '%' } );
	my $now = DateTime.now();
	return $format.split(
	    /'%'(<[_LfUc%]>){make %mapping{$0}()}/, :all).map:{
		$^e ~~ Match ?? ~$^e.ast !! strftime($^e, $now) }.join("");

    }
}
