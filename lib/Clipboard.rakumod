unit module Clipboard;

sub copy_to_clipboard ($text, Bool :$primary) is export {
    return unless $text;

    if %*ENV<XDG_SESSION_TYPE> eq 'wayland' {
        run 'wl-copy', $primary ?? '-p' !! Empty, $_ with $text;
    } else {
        my $p = run 'xclip', '-selection', $primary ?? 'primary' !! 'clipboard', :in;
        $p.in.print: $text;
        $p.in.close;
    }
}

sub read_from_clipboard (Bool :$primary --> Str) is export {
    my $p = do if %*ENV<XDG_SESSION_TYPE> eq 'wayland' {
        run 'wl-paste', '-n', '-t', 'text', $primary ?? '-p' !! Empty, :out;
    } else {
        run 'xclip', '-selection', $primary ?? 'primary' !! 'clipboard', '-o', :out;
    }

    $p.out.slurp: :close;
}
