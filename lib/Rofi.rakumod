unit module Rofi;

sub rofi (Str:D $prompt, Str:D @items, Str:D @options?, Bool :$multi_select --> Hash) is export {
    my @cmd = flat «rofi -monitor -2 -location 6 -width 100 -format s -p "$prompt" -dmenu -i -sep "\x0f"», @options;
    @cmd.append: '-multi-select' if $multi_select;

    my $proc = Proc::Async.new: :w, |@cmd;
    my %result;

    react {
        whenever $proc.stdout.lines {
            %result<selected>.push: $_;
        }
        whenever $proc.start {
            %result<exitcode> = .exitcode;
            done;
        }
        whenever $proc.print: @items.join("\x0f") {
            $proc.close-stdin;
        }
    }

    %result;
}
