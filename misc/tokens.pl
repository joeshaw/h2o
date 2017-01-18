#! /usr/bin/perl

# Copyright (c) 2014 DeNA Co., Ltd.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

use strict;
use warnings;
use List::Util qw(max);
use List::MoreUtils qw(uniq);
use Text::MicroTemplate qw(render_mt);

use constant LICENSE => << 'EOT';
/*
 * Copyright (c) 2014 DeNA Co., Ltd.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */
EOT

my %tokens;
my @hpack;

while (my $line = <DATA>) {
    chomp $line;
    my ($hpack_index, $proxy_should_drop, $is_init_header_special, $http2_should_reject, $copy_for_push_request, $name, $value) =
        split /\s+/, $line, 7;
    next unless $name ne '';
    $tokens{$name} = [ $hpack_index, $proxy_should_drop, $is_init_header_special, $http2_should_reject, $copy_for_push_request ]
        unless defined $tokens{$name};
    if ($hpack_index != 0) {
        $hpack[$hpack_index - 1] = [ $name, $value ];
    }
}

my @tokens = map { [ $_, @{$tokens{$_}} ] } uniq sort keys %tokens;

# generate token.h
open my $fh, '>', 'include/h2o/token.h'
    or die "failed to open include/h2o/token.h:$!";
print $fh render_mt(<< 'EOT', \@tokens, LICENSE)->as_string;
? my ($tokens, $license) = @_;
<?= $license ?>
/* DO NOT EDIT! generated by tokens.pl */
#ifndef h2o__token_h
#define h2o__token_h

? for my $i (0..$#$tokens) {
#define <?= normalize_name($tokens->[$i][0]) ?> (h2o__tokens + <?= $i ?>)
? }

#endif
EOT
close $fh;

# generate token_table.h
open $fh, '>', 'lib/core/token_table.h'
    or die "failed to open lib/core/token_table.h:$!";
print $fh render_mt(<< 'EOT', \@tokens, LICENSE)->as_string;
? my ($tokens, $license) = @_;
<?= $license ?>
/* DO NOT EDIT! generated by tokens.pl */
h2o_token_t h2o__tokens[] = {
? for my $i (0..$#$tokens) {
    { { H2O_STRLIT("<?= $tokens->[$i][0] ?>") }, <?= join(", ", map { $tokens->[$i][$_] } (1..$#{$tokens->[$i]})) ?> }<?= $i == $#$tokens ? '' : ',' ?>
? }
};
size_t h2o__num_tokens = <?= scalar @$tokens ?>;

const h2o_token_t *h2o_lookup_token(const char *name, size_t len)
{
    switch (len) {
? for my $len (uniq sort { $a <=> $b } map { length $_->[0] } @$tokens) {
    case <?= $len ?>:
        switch (name[<?= $len - 1 ?>]) {
?  my @tokens_of_len = grep { length($_->[0]) == $len } @$tokens;
?  for my $end (uniq sort map { substr($_->[0], length($_->[0]) - 1) } @tokens_of_len) {
        case '<?= $end ?>':
?   my @tokens_of_end = grep { substr($_->[0], length($_->[0]) - 1) eq $end } @tokens_of_len;
?   for my $token (@tokens_of_end) {
            if (memcmp(name, "<?= substr($token->[0], 0, length($token->[0]) - 1) ?>", <?= length($token->[0]) - 1 ?>) == 0)
                return <?= normalize_name($token->[0]) ?>;
?   }
            break;
?  }
        }
        break;
? }
    }

    return NULL;
}
EOT
close $fh;

# generate hpack_static_table.h
open $fh, '>', 'lib/http2/hpack_static_table.h'
    or die "failed to open lib/hpack_static_table.h:$!";
print $fh render_mt(<< 'EOT', \@hpack, LICENSE)->as_string;
? my ($entries, $license) = @_;
<?= $license ?>
/* automatically generated by tokens.pl */

static const struct st_h2o_hpack_static_table_entry_t h2o_hpack_static_table[<?= scalar @$entries ?>] = {
? for my $i (0..$#$entries) {
    { <?= normalize_name($entries->[$i][0]) ?>, { H2O_STRLIT("<?= $entries->[$i][1] || "" ?>") } }<?= $i == $#$entries ? "" : "," ?>
? }
};
EOT
close $fh;

sub normalize_name {
    my $n = shift;
    $n =~ s/^://;
    $n =~ s/-/_/g;
    $n =~ tr/a-z/A-Z/;
    "H2O_TOKEN_$n";
}

__DATA__
1 0 0 0 0 :authority
2 0 0 0 0 :method GET
3 0 0 0 0 :method POST
4 0 0 0 0 :path /
5 0 0 0 0 :path /index.html
6 0 0 0 0 :scheme http
7 0 0 0 0 :scheme https
8 0 0 0 0 :status 200
9 0 0 0 0 :status 204
10 0 0 0 0 :status 206
11 0 0 0 0 :status 304
12 0 0 0 0 :status 400
13 0 0 0 0 :status 404
14 0 0 0 0 :status 500
15 0 0 0 1 accept-charset
16 0 0 0 1 accept-encoding gzip, deflate
17 0 0 0 1 accept-language
18 0 0 0 0 accept-ranges
19 0 0 0 1 accept
20 0 0 0 0 access-control-allow-origin
21 0 0 0 0 age
22 0 0 0 0 allow
23 0 0 0 0 authorization
24 0 0 0 0 cache-control
25 0 0 0 0 content-disposition
26 0 0 0 0 content-encoding
27 0 0 0 0 content-language
28 0 1 0 0 content-length
29 0 0 0 0 content-location
30 0 0 0 0 content-range
31 0 0 0 0 content-type
32 0 0 0 0 cookie
33 1 0 0 0 date
34 0 0 0 0 etag
35 0 1 0 0 expect
36 0 0 0 0 expires
37 0 0 0 0 from
38 0 1 1 0 host
39 0 0 0 0 if-match
40 0 0 0 0 if-modified-since
41 0 0 0 0 if-none-match
42 0 0 0 0 if-range
43 0 0 0 0 if-unmodified-since
44 0 0 0 0 last-modified
45 0 0 0 0 link
46 0 0 0 0 location
47 0 0 0 0 max-forwards
48 1 0 0 0 proxy-authenticate
49 1 0 0 0 proxy-authorization
50 0 0 0 0 range
51 0 0 0 0 referer
52 0 0 0 0 refresh
53 0 0 0 0 retry-after
54 1 0 0 0 server
55 0 0 0 0 set-cookie
56 0 0 0 0 strict-transport-security
57 1 1 1 0 transfer-encoding
58 0 0 0 1 user-agent
59 0 0 0 0 vary
60 0 0 0 0 via
61 0 0 0 0 www-authenticate
0 1 0 1 0 connection
0 0 0 0 0 x-reproxy-url
0 1 1 1 0 upgrade
0 1 0 1 0 http2-settings
0 1 0 1 0 te
0 1 0 0 0 keep-alive
0 0 0 0 0 x-forwarded-for
0 0 0 0 0 x-traffic
0 0 0 0 0 cache-digest
0 0 0 0 0 x-compress-hint
