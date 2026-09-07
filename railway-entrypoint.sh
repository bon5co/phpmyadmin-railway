#!/bin/bash
# Railway entrypoint for phpMyAdmin. Runs before the upstream entrypoint and
# hands over to it, so every upstream PMA_* variable keeps working.
set -euo pipefail

log() { echo "[railway] $*"; }

# 1. Remove any Apache MPM other than the one the image selected.
#
# The official image disables mpm_event and enables mpm_prefork at build time.
# On Railway the deleted symlinks are present again inside the running
# container, so Apache aborts at startup with
#   AH00534: apache2: Configuration error: More than one MPM loaded.
# and the service crash-loops. Repairing it in a build layer would not help,
# because that is another deletion; it has to happen at runtime.
for mpm in mpm_event mpm_worker; do
    if [ -e "/etc/apache2/mods-enabled/${mpm}.load" ]; then
        rm -f "/etc/apache2/mods-enabled/${mpm}.load" "/etc/apache2/mods-enabled/${mpm}.conf"
        log "removed stray ${mpm} (duplicate MPM would abort Apache)"
    fi
done
log "MPM in use: $(ls /etc/apache2/mods-enabled | grep -o 'mpm_[a-z]*' | sort -u | tr '\n' ' ')"

# 2. Serve on the port Railway injected. Railway's healthcheck dials the
#    injected port, so the app must honour it rather than pin one.
export APACHE_PORT="${PORT:-80}"

# 3. Persist the cookie-encryption secret across deploys.
#
# Upstream generates a random blowfish secret into config.secret.inc.php at
# every container start, so a redeploy silently signs every visitor out and
# invalidates saved settings. Take it from the environment instead.
if [ -z "${PMA_BLOWFISH_SECRET:-}" ]; then
    log "FATAL: PMA_BLOWFISH_SECRET is empty. Set it to a 32-character random string."
    exit 1
fi
if [ "${#PMA_BLOWFISH_SECRET}" -lt 32 ]; then
    log "FATAL: PMA_BLOWFISH_SECRET must be at least 32 characters (got ${#PMA_BLOWFISH_SECRET})."
    exit 1
fi
printf '<?php\n$cfg["blowfish_secret"] = %s;\n' "'${PMA_BLOWFISH_SECRET//\'/}'" \
    > /etc/phpmyadmin/config.secret.inc.php
chgrp www-data /etc/phpmyadmin/config.secret.inc.php
log "blowfish secret pinned from the environment (login cookies stay valid across deploys)"

# 4. Keep PHP sessions on the volume, and make it writable.
#
# PHP writes its session files to /sessions, which is on the disposable layer in
# the stock image, so every deploy signs every user out mid-task. Railway mounts
# a volume owned by uid 0 while Apache's children run as www-data, so the mount
# has to be repaired before anything writes to it.
if [ -d /sessions ]; then
    chown www-data:www-data /sessions
    chmod 1777 /sessions
    log "session store ready ($(ls -1 /sessions | wc -l) session(s) carried over)"
fi

# 5. Create the phpMyAdmin configuration storage and its control user.
#
# Without it phpMyAdmin shows a permanent "not completely configured" banner and
# bookmarks, column comments, query history, favourites and designer layouts are
# all unavailable.
if [ -n "${PMA_CONTROLPASS:-}" ] && [ -n "${MYSQL_ROOT_PASSWORD:-}" ]; then
    export PMA_CONTROLUSER="${PMA_CONTROLUSER:-pma}"
    export PMA_PMADB="${PMA_PMADB:-phpmyadmin}"
    if php /usr/local/bin/pma-bootstrap.php; then
        log "configuration storage ready (${PMA_PMADB}, control user ${PMA_CONTROLUSER})"
    else
        log "WARNING: configuration storage bootstrap failed; phpMyAdmin still works without it"
        unset PMA_CONTROLUSER PMA_CONTROLPASS PMA_PMADB
    fi
fi

exec /docker-entrypoint.sh "$@"
