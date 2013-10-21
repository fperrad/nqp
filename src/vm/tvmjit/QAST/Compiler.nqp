
class QAST::CompilerTOST {

    INIT {
        # Register as the QAST compiler.
        nqp::bindcomp('QAST', QAST::CompilerTOST);
    }

    method tp($source, *%adverbs) {
        # Ensure we have a QAST::CompUnit that in turn contains a QAST::Block.
        unless nqp::istype($source, QAST::CompUnit) {
            $source := QAST::Block.new($source) unless nqp::istype($source, QAST::Block);
            $source := QAST::CompUnit.new($source);
        }

        # Now compile $source and return the result.
#        self.as_post($source);

        my $o := TOST::Ops.new(
            TOST::Op.new( '!line', 1 ),
            TOST::Op.new( '!call', 'print', TOST::Op.quote('hello') ),
        );
        ~$o;
    }
}


