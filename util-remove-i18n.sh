#!/bin/sh

sed -re 's/"\$\(gettext "([^"]+)"\)"/"\1"/'
