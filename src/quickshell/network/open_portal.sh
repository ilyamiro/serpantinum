#!/bin/sh
probe="http://nmcheck.gnome.org/check_network_status.txt"
url=$(curl -s -m 5 -o /dev/null -w '%{redirect_url}' "$probe")
exec xdg-open "${url:-$probe}"