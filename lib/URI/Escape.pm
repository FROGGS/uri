use v6;

package URI::Escape {

    use IETF::RFC_Grammar::URI;

    our %escapes;

    for 0 .. 255 -> $c {  # map broken in module / package ?
        %escapes{ chr($c) } = sprintf "%%%02X", $c
    }

    # in moving from RFC 2396 to RFC 3986 this selection of characters
    # may be due for an update ...

    # commented line below used to work ...
#    token artifact_unreserved {<[!*'()] +IETF::RFC_Grammar::URI::unreserved>};

    sub uri_escape($s is copy) is export {
        my $rc;
        while $s {
            # regexes kludged for many broken things in rakudo
            if my $not_escape = $s ~~ /^<[!*'()\-._~A..Za..z0..9]>+/ {
               $rc ~= $not_escape;
               $s.=substr($not_escape.chars);
            }
            if my $escape = $s ~~ /^<- [!*'()\-._~A..Za..z0..9]>+/ {
                $rc ~= ($escape.comb().map: {
                    %escapes{ $_ } ||
                    die 'Can\'t escape \\' ~ sprintf(
						'x{%04X}, try uri_escape_utf8() some day instead', 
						ord($_))
               }).join;                
               $s.=substr($escape.chars);
            }
        }
        
        return $rc;
    }

    # todo - automatic invalid UTF-8 detection
	# see http://www.w3.org/International/questions/qa-forms-utf-8
	# 	find first sequence of %[89ABCDEF]<.xdigit>
	# 		use algorithm from url to determine if it's valid UTF-8
    sub uri_unescape(Str *@to_unesc, Bool :$no_utf8 = False) is export {
        my @rc;
        for @to_unesc -> $s is copy {
            my $rc = '';
            my $last_pos = 0;

            while $s ~~ m:c/[ '%' (<.xdigit><.xdigit>)]+/ {
                $rc ~=  $s.substr($last_pos, $/.from - $last_pos);
                
                # should be a better way with list context
                my @encoded_octets = map { :16( .value ) }, $/.caps;
                # common case optimization
                while @encoded_octets and ($no_utf8 or  @encoded_octets[0] < 0x80) {
                    $rc ~= chr(shift @encoded_octets);
                }
                # if any utf8 ...
                while @encoded_octets {
                    my ($code_point, $utf8_len) = utf8_octets_2_codepoint(
                        @encoded_octets
                    );
                    @encoded_octets.splice(0, $utf8_len);
                    $rc ~= chr($code_point);
                }
                $last_pos = $/.to;
            }
            $rc ~= $s.substr($last_pos);
            $rc ~~ s:g/\+/ /;
            @rc.push($rc);
        }
        return @rc;
    }
    
    sub uri_unescape_utf8 () {
    }

}

# Stole parts from Masak November::CGI and parts from Parrot's UTF-8 decode
sub utf8_octets_2_codepoint(@octets) {
    if @octets[ 0 ] < 0x80 { # completeness
        return @octets[0], 1
    }

    my $len = 2;    

    while 0x80 +> $len +& @octets[0] and ++$len <= 6 {}
	
    my $max_shift = 6 * ($len -1);
    my $code_point = reduce { 
        $^a + @octets[ $^b ] +& 0x3F +< ($max_shift - 6 * $^b)
    }, 0x7F +> $len +& @octets[0] +< $max_shift, 1 ..^ $len;

    return $code_point, $len;
}

=begin pod

=head NAME

URI::Escape - Escape and unescape unsafe characters

=head SYNOPSYS

    use URI::Escape;
    
    my $escaped = uri_escape("10% is enough\n");
    my $un_escaped = uri_unescape('10%25%20is%20enough%0A');

=end pod

# vim:ft=perl6
