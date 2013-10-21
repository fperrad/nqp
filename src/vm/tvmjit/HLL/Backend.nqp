# Backend class for the TvmJIT.
class HLL::Backend::TvmJIT {
    method apply_transcodings($s, $transcode) {
        $s
    }

    method config() {
        nqp::hash()
    }

    method force_gc() {
        nqp::die("Cannot force GC on TvmJIT backend yet");
    }

    method name() {
        'tvmjit'
    }

    method nqpevent($spec?) {
        # Doesn't do anything just yet
    }

    method run_profiled($what) {
        nqp::printfh(nqp::getstderr(),
            "Attach a profiler (e.g. JVisualVM) and press enter");
        nqp::readlinefh(nqp::getstdin());
        $what();
    }

    method run_traced($level, $what) {
        nqp::die("No tracing support");
    }

    method version_string() {
        "TVMJIT"
    }

    method stages() {
        'tp display'
    }

    method is_precomp_stage($stage) {
        $stage eq 'tp'
    }

    method is_textual_stage($stage) {
        $stage eq 'tp'
    }

    method prelude() {
        "; prelude\n"
    }

    method tp($source, *%adverbs) {
        my $comp := nqp::getcomp('QAST');
        self.prelude() ~ $comp.tp($source) ~ "\n"
    }

    method display($source, *%adverbs) {
        say($source);
    }

    method is_compunit($cuish) {
        nqp::iscompunit($cuish)
    }

    method compunit_mainline($cu) {
        nqp::compunitmainline($cu)
    }

    method compunit_coderefs($cu) {
        nqp::compunitcodes($cu)
    }
}

# Role specifying the default backend for this build.
#role HLL::Backend::Default {
#    method default_backend() { HLL::Backend::TvmJIT }
#}
