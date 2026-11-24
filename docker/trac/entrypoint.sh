#!/bin/sh
set -e

env=/var/trac/env

if [ ! -f "$env/VERSION" ]; then
    trac-admin "$env" initenv "Shirousagi verification" sqlite:db/trac.db
    trac-admin "$env" config set components 'tracrpc.*' enabled
    trac-admin "$env" upgrade
    trac-admin "$env" permission add "$TRAC_ADMIN_USER" TRAC_ADMIN
    # Without this every logged-in user may edit tickets and the wiki, and the viewer could not show a permission error.
    trac-admin "$env" permission remove authenticated "*"
    trac-admin "$env" permission add "$TRAC_VIEWER_USER" XML_RPC
    htpasswd -bc /var/trac/htpasswd "$TRAC_ADMIN_USER" "$TRAC_ADMIN_PASSWORD"
    htpasswd -b /var/trac/htpasswd "$TRAC_VIEWER_USER" "$TRAC_VIEWER_PASSWORD"
fi

# Outside the block above, so that an environment created before this user existed gains it on the next start.
htpasswd -b /var/trac/htpasswd "$TRAC_OUTSIDER_USER" "$TRAC_OUTSIDER_PASSWORD"

exec tracd --single-env --port 8000 --basic-auth="*,/var/trac/htpasswd,Trac" "$env"
