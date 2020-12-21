find /var/www/localhost/htdocs/cameras -type f -ctime +1 -print | while read; do rm -f ; done
