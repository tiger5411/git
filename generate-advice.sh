#!/bin/sh

HT='	'

advice_list () {
	sed -n \
		-e '/^advice.*::$/d' \
		-e "/::/ {
			s/^$HT//;
			s/::\$//;
			p;
		}" \
	    <Documentation/config/advice.txt
}

txt2label () {
	sed \
		-e 's/\([^_]\)\([[:upper:]]\)/\1_\2/g' \
		-e 's/^/ADVICE_/' |
		tr '[:lower:]' '[:upper:]'
}

advice_labels () {
	advice_list |
	txt2label
}

advice_labels_to_config () {
	advice_list |
	while read line
	do
		label=$(echo "$line" | txt2label)
		printf "[%s] = { \"%s\", 1 }\n" "$label" "$line"
	done
}

listify () {
	sed \
		-e "2,\$s/^/$HT/" \
		-e 's/$/,/'
}

case "$#" in
1) ;;
*)
	echo "usage: $0 advice-type.h >advice-type.h"
	echo "   or: $0 advice-config.h >advice-config.h"
	exit 1
esac

case "$1" in
advice-type.h)
	cat <<EOF
/* Automatically generated by generate-advice.sh */

enum advice_type {
	/* Auto-generated from Documentation/config/advice.txt */
	$(advice_labels | listify)
};
EOF
	;;
advice-config.h)
	cat <<EOF
/* Automatically generated by generate-advice.sh */
struct advice_entry {
	const char *key;
	int enabled;
};

static struct advice_entry advice_setting[] = {
	$(advice_labels_to_config | listify)
};
EOF
	;;
*)
	echo "$0: unknown target $1" >&2
	exit 1
	;;
esac
