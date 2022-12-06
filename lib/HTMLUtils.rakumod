use Cro::Uri::HTTP;
use Cro::Uri :decode-percents, :encode-percents;

unit module HTMLUtils;

#| Given a URI path, returns an array of URI strings of its segments
sub dig_url (Str:D $path, Str:D $page_url = '' --> Array[Str:D]) is export {
    my Str $domain := domain $page_url || $path;

    my @segments = |$path.&make_url($page_url).path-segments.grep(&so);

    Array[Str:D].new: ($domain, |(^@segments).hyper.map({
        $domain ~ '/' ~ @segments[0..$_].join('/');
    })).grep(&so);
}

#| Given a URI path, returns an array of subdomains
sub dig_domain (Str:D $path, Str:D $page_url = '' --> Array[Str:D]) is export {
    my Str ($scheme, $hostname) := domain 'scheme and hostname', $page_url || $path;

    my @segments = .split('.') with $hostname;

    Array[Str:D].new: |(^(@segments-1)).hyper.map({
        [~] $scheme, @segments[$_], '.', @segments[$_ ^..^ *].join('.');
    }).grep(&so);
}

#| Creates a URI string
sub make_string_url (Str:D $path, Str $page_url? --> Str) is export {
    if $path ~~ /^^ \w+ ':'/ and $path !~~ /^^ \w+ '://'/ {
        return $path;
    }

    my Str $url;

    with make_url $path, $page_url {
        $url ~= "$_:" with .scheme;
        $url ~= "//$_" with .authority;
        $url ~= '/' ~ .hyper.map(&decode-percents).join('/') with .path-segments.grep(&so);

        if .query-hash -> %query is copy {
            for %query.keys -> $key {
                %query{$key}:delete and next if $key.starts-with: any <_ga _utm utm>;

                with %query{$key}.Str {
                    %query{$key} = .&decode-percents;
                    %query{$key}.=trans: ["\n", '#'] => ('%' X~ <0A 23>);
                }
            }

            $url ~= '?' ~ %query.hyper.map({.key ~ '=' ~ .value}).join('&') if %query;
        }

        $url ~= "#$_.&decode-percents()" with .fragment;
    }

    $url;
}

#| Creates a URI object
sub make_url (Str:D $path is copy, Str $base_url? is copy --> Cro::Uri::HTTP:D) is export {
    my Cro::Uri::HTTP $uri .= new;

    if $path ~~ /^^ \w+ ':'/ || not defined $base_url {
        return $uri.add: $path;
    } else {
        # Strip fragment and queries from base URL
        $base_url ~~ s:g/<[#?]> .*//;

        return $uri.add($base_url).add: $path;
    }

    CATCH {
        when X::Cro::Uri::ParseError {
            note .^name ~ ': ' ~ .message and return Nil;
        }
    }
}

#| Returns a string of scheme and hostname
multi domain (Str:D $url --> Str) is export {
    ~$url.match(/^^ <-[:@]>+ '://' <-[/]>+ /);
}

#| Returns a Seq of scheme and hostname
multi domain ('scheme and hostname', Str:D $url --> Seq) is export {
    $url.match(/^^ (<-[:@]>+ '://') (<-[/]>+) /).map: *.Str;
}

enum ElementTypes is export «:Links<Links> :Images<Images> :Feeds<Feeds> :MetaLinks<MetaLinks>»;

#| Given an element type and HTML source returns the URLs found inside the elements
sub find_urls (ElementTypes:D :$element_type!, Bool :$with-title, Str:D :$html!, Str:D :$page_url! is copy --> Array[Str:D]) is export {
    use DOM::Tiny;

    my $dom = DOM::Tiny.parse: $html;

    my @elements = do given $element_type {
        when Links {
            |.find('a[href]').hyper.map(
                {
                    %(
                        title => .<title> // .<aria-label> // .all-text.trim || .children('[alt]').hyper.map(*<alt>).grep(&so).join(' '),
                        url => .<href>
                     )
                }
            ).grep(*<url>) with $dom;
        }
        when Images {
            |.find('img[src]').hyper.map(
                {
                    %(
                        title => .<title> // .<aria-label> // .<alt>,
                        url => .<src>
                    )
                }
            ).grep(*<url>) with $dom;
        }
        when Feeds {
            |.find('head link[type="application/rss+xml"], head link[type="application/atom+xml"]').hyper.map(
                {
                    %(
                        title => .<title> // .<type>,
                        url => .<href>
                    )
                }
            ).grep(*<url>) with $dom;
        }
        when MetaLinks {
            |.find('head link, script').hyper.map(
                {
                    %(
                        title => .<type> // .<rel>,
                        url => .<href> // .<src>
                    )
                }
            ).grep(*<url>) with $dom;
        }
    }

    return Array[Str:D] unless @elements;

    Array[Str:D].new: @elements.unique(:as(*<url>)).hyper.map: {
        my Str $url = .<url>.&make_string_url($page_url);

        next unless $url;

        if $with-title {
            join "\n", (.<title> // '').trim.subst(/\s+/, ' ', :g), $url;
        } else {
            $url
        }
    }
}
