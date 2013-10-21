
class TOST::Op {
        has @!array;
        has %!hash;

        method new(*@aval, *%hval) {
                my $obj := self.CREATE;
                nqp::bindattr($obj, TOST::Op, '@!array', @aval);
                nqp::bindattr($obj, TOST::Op, '%!hash', %hval);
                return $obj;
        }

        method quote ($str) {
                return '"' ~ $str ~ '"';
        }

        method push ($value) {
                nqp::push(@!array, $value);
                return self;
        }

        method addkv ($key, $value) {
                %!hash{$key} := $value;
                return self;
        }

        method Str () {
                my @l;
                for @!array {
                        nqp::push(@l, ~$_);
                }
                for %!hash {
                        nqp::push(@l, Op.quote($_.key) ~ ':');
                        nqp::push(@l, ~$_.value);
                }
                my $newline := (@!array[0] eq '!line' || @!array[0] eq '!do') ?? "\n" !! '';
                return $newline ~ '(' ~ nqp::join(' ', @l) ~ ')';
        }
}

class TOST::Ops {
        has @!array;

        method new(*@val) {
                my $obj := self.CREATE;
                nqp::bindattr($obj, TOST::Ops, '@!array', @val);
                return $obj;
        }

        method push ($value) {
                nqp::push(@!array, $value);
                return self;
        }

        method Str () {
                my @l;
                for @!array {
                        nqp::push(@l, ~$_);
                }
                return nqp::join('', @l);
        }
}
