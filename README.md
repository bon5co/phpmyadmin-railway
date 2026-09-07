# phpmyadmin-railway

Wrapper image for running the official [phpMyAdmin](https://hub.docker.com/r/phpmyadmin/phpmyadmin)
Apache image on [Railway](https://railway.com). Published as
`ghcr.io/bon5co/phpmyadmin-railway:5.2.3`.

It changes four things and leaves everything else — including every upstream
`PMA_*` variable — alone:

1. **Removes the duplicate Apache MPM.** The upstream image disables `mpm_event`
   at build time, but inside a Railway container both `mpm_event` and
   `mpm_prefork` are enabled, so Apache aborts with
   `AH00534: apache2: Configuration error: More than one MPM loaded.` and the
   service crash-loops. The repair has to happen at runtime.
2. **Pins the blowfish secret** from `PMA_BLOWFISH_SECRET` instead of
   regenerating it at every container start, so a redeploy no longer signs every
   visitor out. The container refuses to boot on an empty or short value.
3. **Honours `$PORT`** by exporting it as upstream's `APACHE_PORT`.
4. **Creates the phpMyAdmin configuration storage** (`pma__*` tables) and a
   dedicated control user, so bookmarks, query history, column comments,
   favourites and designer layouts work instead of showing the permanent
   "not completely configured" banner.

## Variables

| Variable | Purpose |
|---|---|
| `PMA_BLOWFISH_SECRET` | Required. At least 32 characters; encrypts the session cookie. |
| `PMA_CONTROLPASS` | Password for the control user that owns the configuration storage. |
| `MYSQL_ROOT_PASSWORD` | Used once per boot to create the storage database and control user. |
| `PMA_HOST`, `PMA_PORT` | The MySQL server phpMyAdmin connects to. |

Plus everything upstream supports.
