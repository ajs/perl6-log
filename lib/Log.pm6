use v6;

use DateTime::Utils;

# Typical use:
#
# our $logger = Log.get_logger(:level(%Log::levels<debug>), :facility('myprog'));
# $logger.debug("OK, I set up a logger");
# $logger.critical("But now I give up");
#
# Repeated calls to Log.get_logger for a given facility will return
# the same logger object.

#our enum Log::levels <<debug(1) info warning error critical>>;
our %Log::levels = hash(:debug(1), :info(2), :warning(3), :error(4), :critical(5));

class Log is export {
    # my == our? Rakudo choks on "our", here...
    my %.loggers = ();

    has $.level is rw = %Log::levels<warning>;
    has $.facility is readonly = 'perl';
    has $.format is rw = '%Y-%m-%d %H:%M:%S: %f: %_: %L';
    has IO $.output is readonly = $*ERR;

    # Meant to be used as a class method or on a Log object interchangably
    method get_logger(:$facility, |$rest) {
        return $facility ~~ Log.loggers ?? Log.loggers{$facility} !!
            (Log.loggers{$facility} = self.new(:$facility, |$rest));
    }

    method log(Str $msg, :$level = %Log::levels<info>) {
        return if $level < self.level;
        self.output.say(self.format_log($.format, $msg));
    }
    method debug(Str $msg) { self.log($msg, :level(%Log::levels<debug>)) }
    method info(Str $msg) { self.log($msg, :level(%Log::levels<info>)) }
    method warning(Str $msg) { self.log($msg, :level(%Log::levels<warning>)) }
    method error(Str $msg) { self.log($msg, :level(%Log::levels<error>)) }
    method critical(Str $msg) { self.log($msg, :level(%Log::levels<critical>)) }

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
    method format_log(Str $format is copy, Str $msg, :$level=Any) {
        my %mapping = (
            'L' => { $msg },
            '_' => { $level // self.level },
            'f' => { self.facility },
            'U' => { %*ENV<USER> },
            'c' => { $*PROGRAM_NAME },
            # We need to claim the %% escapes so that "%%%Y" expands correctly
            '%' => { '%' } );
        my $now = DateTime.now();
        return ($format.split(
            /'%'(<[_LfUc%]>):{make %mapping{$0}()}/, :all).map:{
                $^e ~~ Match ?? ~$^e.ast !! strftime($^e, $now) }).join("");
        CATCH { die "Cannot parse log format string: $_" }

    }
}
