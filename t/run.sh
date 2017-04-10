#!/bin/sh

#prove --state=save -j 20 t[0-9]*.sh :: --root="tmp.$(perl -e 'print join q[], grep { /[^[:alnum:]]/ and !m<[./]> } map chr, 0x01..0x7f')"
grep -B3 last_fail_time .prove |grep sh | perl -pe 's/^  (.*?):/$1/' >failed-tests

>results
for ft in $(cat failed-tests)
do
    parallel -k -j8 "
        (
            ./$ft --root=\"tmp.\$(perl -e 'print chr shift' {})\" 2>&1 >/dev/null &&
            echo $ft {} OK ||
            echo $ft {} FAIL
        ) | tee -a results
    " ::: $(perl -e 'print "$_\n" for map ord, grep { /[^[:alnum:]]/ and !m<[./]> } map chr, 0x01..0x7f')
done

grep FAIL results  | awk '{print $1 " " $2}'|perl -nE 'chomp;my ($f, $c) = split / /, $_; push @{$f{$f}} => $c; END { for my $k (sort keys %f) { say "$k = " . join ", ", map { $_ < 32 ? $_ : "$_(" . chr($_) . ")" } @{$f{$k}} } }'
