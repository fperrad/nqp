my module sprintf {
    grammar Syntax {
        token TOP {
            :my $*ARGS_USED := 0;
            ^ <statement>* $
        }
        
        method panic($msg) { nqp::die($msg) }
        
        token statement {
            [
            | <?[%]> [ [ <directive> | <escape> ]
                || <.panic("'" ~ nqp::substr(self.orig,1) ~ "' is not valid in sprintf format sequence '" ~ self.orig ~ "'")> ]
            | <![%]> <literal>
            ]
        }

        proto token directive { <...> }
        token directive:sym<b> { '%' <flags>* <size>? [ '.' <precision=.size> ]? $<sym>=<[bB]> }
        token directive:sym<c> { '%' <flags>* <size>? <sym> }
        token directive:sym<d> { '%' <flags>* <size>? $<sym>=<[di]> }
        token directive:sym<e> { '%' <flags>* <size>? [ '.' <precision=.size> ]? $<sym>=<[eE]> }
        token directive:sym<f> { '%' <flags>* <size>? [ '.' <precision=.size> ]? $<sym>=<[fF]> }
        token directive:sym<g> { '%' <flags>* <size>? [ '.' <precision=.size> ]? $<sym>=<[gG]> }
        token directive:sym<o> { '%' <flags>* <size>? [ '.' <precision=.size> ]? <sym> }
        token directive:sym<s> { '%' <flags>* <size>? <sym> }
        token directive:sym<u> { '%' <flags>* <size>? <sym> }
        token directive:sym<x> { '%' <flags>* <size>? [ '.' <precision=.size> ]? $<sym>=<[xX]> }

        proto token escape { <...> }
        token escape:sym<%> { '%' <flags>* <size>? <sym> }
        
        token literal { <-[%]>+ }
        
        token flags {
            | $<space> = ' '
            | $<plus>  = '+'
            | $<minus> = '-'
            | $<zero>  = '0'
            | $<hash>  = '#'
        }
        
        token size {
            \d* | $<star>='*'
        }
    }

    class Actions {
        method TOP($/) {
            my @statements;
            @statements.push( $_.ast ) for $<statement>;

            if $*ARGS_USED < +@*ARGS_HAVE {
                nqp::die("Too few directives: found $*ARGS_USED,"
                ~ " fewer than the " ~ +@*ARGS_HAVE ~ " arguments after the format string")
            }
            if $*ARGS_USED > +@*ARGS_HAVE {
                nqp::die("Too many directives: found $*ARGS_USED, but "
                ~ (+@*ARGS_HAVE > 0 ?? "only " ~ +@*ARGS_HAVE !! "no")
                ~ " arguments after the format string")
            }
            make nqp::join('', @statements);
        }

        sub infix_x($s, $n) {
            my @strings;
            my $i := 0;
            @strings.push($s) while $i++ < $n;
            nqp::join('', @strings);
        }

        sub next_argument() {
            @*ARGS_HAVE[$*ARGS_USED++]
        }

        sub intify($number_representation) {
            my $result;
            if $number_representation > 0 {
                $result := nqp::floor_n($number_representation);
            }
            else {
                $result := nqp::ceil_n($number_representation);
            }
            $result;
        }

        sub padding_char($st) {
            my $padding_char := ' ';
            if (!$st<precision> && !has_flag($st, 'minus'))
            || $st<sym> ~~ /<[eEfFgG]>/ {
                $padding_char := '0' if $_<zero> for $st<flags>;
            }
            make $padding_char
        }

        sub has_flag($st, $key) {
            my $ok := 0;
            if $st<flags> {
                $ok := 1 if $_{$key} for $st<flags>
            }
            $ok
        }

        method statement($/){
            my $st;
            if $<directive> { $st := $<directive> }
            elsif $<escape> { $st := $<escape> }
            else { $st := $<literal> }
            my @pieces;
            @pieces.push: infix_x(padding_char($st), $st<size>.ast - nqp::chars($st.ast)) if $st<size>;
            has_flag($st, 'minus')
                ?? @pieces.unshift: $st.ast
                !! @pieces.push:    $st.ast;
            make join('', @pieces)
        }

        method directive:sym<b>($/) {
            my $int := intify(next_argument());
            my $knowhow := nqp::knowhow().new_type(:repr("P6bigint"));
            $int := nqp::base_I(nqp::box_i($int, $knowhow), 2);
            my $pre := ($<sym> eq 'b' ?? '0b' !! '0B') if $int && has_flag($/, 'hash');
            if nqp::chars($<precision>) {
                $int := '' if $<precision>.ast == 0 && $int == 0;
                $int := $pre ~ infix_x('0', intify($<precision>.ast) - nqp::chars($int)) ~ $int;
            }
            else {
                $int := $pre ~ $int
            }
            make $int;
        }
        method directive:sym<c>($/) {
            make nqp::chr(next_argument())
        }

        method directive:sym<d>($/) {
            my $int := intify(next_argument());
            my $pad := padding_char($/);
            my $sign := $int < 0 ?? '-'
                !! has_flag($/, 'plus')
                    ?? '+' !! '';
            if $pad ne ' ' && $<size> {
                $int := nqp::abs_i($int);
                $int := $sign ~ infix_x($pad, $<size>.ast - nqp::chars($int) - 1) ~ $int
            }
            else {
                $int := $sign ~ nqp::abs_i($int)
            }
            make $int
        }

        sub pad-with-sign($num, $size, $pad, $suffix) {
            if $pad ne ' ' && $size {
                my $sign := $num < 0 ?? '-' !! '';
                $num := nqp::abs_n($num);
                $num := $num ~ $suffix;
                $num := $sign ~ infix_x($pad, $size - nqp::chars($num) - 1) ~ $num;
            } else {
                $num := $num ~ $suffix;
            }
            $num;
        }
        sub round-to-precision($float, $precision) {
            $float := $float * $precision;
            $float := $float - nqp::floor_n($float) >= 0.5 ?? nqp::ceil_n($float) !! nqp::floor_n($float);
            $float := $float / $precision;
        }
        sub fixed-point($float, $precision, $size, $pad) {
            $float := round-to-precision($float, $precision);
            pad-with-sign($float, $size, $pad, '');
        }
        sub scientific($float, $e, $precision, $size, $pad) {
            my $exp := nqp::floor_n(nqp::log_n(nqp::abs_n($float)) / nqp::log_n(10));
            $float := $float / nqp::pow_n(10, $exp);
            my $suffix := $e ~ '+' ~ $exp; 
            $float := round-to-precision($float, $precision);
            pad-with-sign($float, $size, $pad, $suffix);
        }
        sub shortest($float, $e, $precision, $size, $pad) {
            my $fixed := round-to-precision($float, $precision);

            my $exp := nqp::floor_n(nqp::log_n(nqp::abs_n($float)) / nqp::log_n(10));
            $float := $float / nqp::pow_n(10, $exp);
            my $suffix := $e ~ '+' ~ $exp; 
            my $sci := round-to-precision($float, $precision);

            if nqp::chars($sci) < nqp::chars($fixed) {
                pad-with-sign($sci, $size, $pad, $suffix);
            } else {
                pad-with-sign($fixed, $size, $pad, '');
            }
        }

        method directive:sym<e>($/) {
            my $float := next_argument();
            my $precision := nqp::pow_n(10, $<precision> ?? $<precision>.ast !! 6);
            my $pad := padding_char($/);
            my $size := $<size> ?? $<size>.ast !! 0;
            make scientific($float, $<sym>, $precision, $size, $pad);
        }
        method directive:sym<f>($/) {
            my $int := next_argument();
            my $sign := $int < 0 ?? '-' !! '';
            my $precision := $<precision> ?? $<precision>.ast !! 6;
            $int := nqp::abs_n($int) + 1;
            $int := $int * nqp::pow_n(10, $precision);
            $int := ~nqp::floor_n($int + 0.5);
            $int := $int - nqp::pow_n(10, $precision);
            my $lhs := nqp::chars($int) > $precision ?? nqp::substr($int, 0, nqp::chars($int) - $precision) !! '0';
            my $rhs := infix_x('0', $precision - nqp::chars($int)) ~ $int;
            $rhs := nqp::substr($rhs, nqp::chars($rhs) - $precision);
            $int := $lhs ~ '.' ~ $rhs;
            my $pad := padding_char($/);
            make $pad ne ' ' && $<size>
                ?? $sign ~ infix_x($pad, $<size>.ast - nqp::chars($int) - 1) ~ $int
                !! $sign ~ $int
        }
        method directive:sym<g>($/) {
            my $float := next_argument();
            my $precision := nqp::pow_n(10, $<precision> ?? $<precision>.ast !! 6);
            my $pad := padding_char($/);
            my $size := $<size> ?? $<size>.ast !! 0;
            make shortest($float, 'e', $precision, $size, $pad);
        }
        method directive:sym<o>($/) {
            my $int := intify(next_argument());
            my $knowhow := nqp::knowhow().new_type(:repr("P6bigint"));
            $int := nqp::base_I(nqp::box_i($int, $knowhow), 8);
            my $pre := '0' if $int && has_flag($/, 'hash');
            if nqp::chars($<precision>) {
                $int := '' if $<precision>.ast == 0 && $int == 0;
                $int := $pre ~ infix_x('0', intify($<precision>.ast) - nqp::chars($int)) ~ $int;
            }
            else {
                $int := $pre ~ $int
            }
            make $int
        }

        method directive:sym<s>($/) {
            make next_argument()
        }
        # XXX: Should we emulate an upper limit, like 2**64?
        # XXX: Should we emulate p5 behaviour for negative values passed to %u ?
        method directive:sym<u>($/) {
            my $int := intify(next_argument());
            my $knowhow := nqp::knowhow().new_type(:repr("P6bigint"));
            if $int < 0 {
                    my $err := nqp::getstderr();
                    nqp::printfh($err, "negative value '" 
                                    ~ $int
                                    ~ "' for %u in sprintf");
                    $int := 0;
            }

            my $chars := nqp::chars($int);

            # Go throught tostr_I to avoid scientific notation.
            $int := nqp::box_i($int, $knowhow);
            make nqp::tostr_I($int)
        }
        method directive:sym<x>($/) {
            my $int := intify(next_argument());
            my $knowhow := nqp::knowhow().new_type(:repr("P6bigint"));
            $int := nqp::base_I(nqp::box_i($int, $knowhow), 16);
            my $pre := '0X' if $int && has_flag($/, 'hash');
            if nqp::chars($<precision>) {
                $int := '' if $<precision>.ast == 0 && $int == 0;
                $int := $pre ~ infix_x('0', intify($<precision>.ast) - nqp::chars($int)) ~ $int;
            }
            else {
                $int := $pre ~ $int
            }
            make $<sym> eq 'x' ?? nqp::lc($int) !! $int
        }

        method escape:sym<%>($/) {
            make '%'
        }

        method literal($/) {
            make ~$/
        }

        method size($/) {
            make $<star> ?? next_argument() !! ~$/
        }
    }

    my $actions := Actions.new();

    sub sprintf($format, @arguments) {
        my @*ARGS_HAVE := @arguments;
        return Syntax.parse( $format, :actions($actions) ).ast;
    }

    nqp::bindcurhllsym('sprintf', &sprintf);
}