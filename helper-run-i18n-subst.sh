#!/bin/sh

for file in $(./helper-i18n-subst-candidates.sh);
do
	./util-remove-i18n.sh <$file >$file+ &&
	mv $file+ $file
done
