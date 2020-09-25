#!/bin/sh

# only migrate database automatically if it does not exist yet
if [ ! -e $ANVISERVER_DATA_DIR/db.sqlite3 ]; then python manage.py migrate; fi

# start gunicorn with the specified parameters by environment variables (and using defaults)
gunicorn -b ${GUNICORN_BIND:-0.0.0.0:8000} -w ${GUNICORN_WORKERS:-4} anviserver.wsgi:application

