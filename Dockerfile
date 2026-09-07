# phpMyAdmin for Railway.
#
# Wraps the official Apache image and fixes three things that stop it working on
# Railway: a duplicate Apache MPM that comes from the platform's image handling,
# a blowfish secret that is regenerated on every container start, and the fact
# that upstream ignores $PORT unless APACHE_PORT is set.
FROM phpmyadmin/phpmyadmin:5.2.3

# Literals a template variable cannot carry: Railway drops a literal defaultValue at
# templateGenerate time and republishes it as a blank REQUIRED field, so these are baked
# into the image instead of published on the deploy form.
ENV PMA_PORT=3306 \
    UPLOAD_LIMIT=256M

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
COPY pma-bootstrap.php /usr/local/bin/pma-bootstrap.php
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["apache2-foreground"]
