#!/bin/sh

for file in $(git grep -l -C10 '(eval_gettext|gettext)' -- *.sh | grep -v -e util-remove-i18n.sh -e git-sh-i18n.sh);
do
	./util-remove-i18n.sh <$file >file+ &&
	mv $file+ $file
done
