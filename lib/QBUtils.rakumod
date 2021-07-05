use Clipboard;
use Rofi;

use HTMLUtils;

unit module QBUtils;

#| Select URLs of the elements with rofi
sub find (ElementTypes() :$element_type!, Bool :$with-title, Str:D :$html!, Str:D :$page_url!) is export {
    my @urls := find_urls :$element_type, :$with-title, :$html, :$page_url;

    %*ENV<QUTE_FIFO>.IO.spurt: "message-info 'No $element_type were found'" and return unless @urls;

    select @urls, |(:height<2> if $with-title);
}

sub dig (Str:D $url, Str:D $page_url = '', Bool :$domain) is export {
    if $domain {
        select dig_domain $url, $page_url;
    } else {
        select dig_url $url, $page_url;
    }
}

sub select (Str:D @urls, :$height = 1) is export {
    my @options := Array[Str:D].new(
        '-mesg',
        '<b>Enter</b>: Copy | <b>Alt+1</b>: Copy Separately | <b>Alt+2</b>: Open | <b>Alt+3</b>: Download | <b>Shift+Enter</b>: Select multiple items | <b>Ctrl+Space</b>: Set selected item as input text * Custom entry is allowed',
        '-eh', "$height"
    );

    my %result = rofi 'Select items', @urls, @options, :multi_select;

    given %result<exitcode> {
        when 0 {
            copy_to_clipboard %result<selected>.join("\n");
        }
        when 10 {
            .&copy_to_clipboard for %result<selected>.rotor($height)».join("\n");
        }
        when 11 {
            %*ENV<QUTE_FIFO>.IO.spurt: %result<selected>.map({ "open -t -- $_" }).join("\n");
        }
        when 12 {
            %*ENV<QUTE_FIFO>.IO.spurt: %result<selected>.map({ "download $_" }).join("\n");
        }
    }
}
