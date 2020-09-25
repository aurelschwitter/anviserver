FROM python:3.6-slim-buster

# switch to user root, as the base image uses USER 1000
# we will switch later to the user "anvio"
USER root

# use /app as workdir
WORKDIR /app

# git configs
ENV ANVIO_BRANCH=v5
ENV ANVISERVER_BRANCH=master

# settings from anviserver/anviserver/settings.py
# override in docker with --env / -e (docker run -e ANVISERVER_TIME_ZONE=UTC+1)
# ENV ANVISERVER_DEBUG=False
# ENV ANVISERVER_LANGUAGE_CODE=en-us
# ENV ANVISERVER_TIME_ZONE=UTC
# ENV ANVISERVER_USE_I18N=True
# ENV ANVISERVER_USE_L10N=True
# ENV ANVISERVER_USE_TZ=True
# ENV ANVISERVER_ACCOUNT_ACTIVATION_DAYS=30
# ENV ANVISERVER_REGISTRATION_AUTO_LOGIN=True
# ENV ANVISERVER_EMAIL_USE_TLS=True
# ENV ANVISERVER_EMAIL_HOST=smtp.gmail.com
# ENV ANVISERVER_EMAIL_HOST_USER=anvi.server@gmail.com
# ENV ANVISERVER_EMAIL_PORT=587
# ENV ANVISERVER_FROM_EMAIL=${ANVISERVER_EMAIL_HOST_USER}
ENV ANVISERVER_DATA_DIR=/app/data


# secrets from settings_secret.py
# ENV ANVISERVER_SECRET_KEY=fixme
# ENV ANVISERVER_EMAIL_HOST_PASSWORD=fixme
# ENV ANVISERVER_ANALYTICS_SCRIPT_BLOCK=''
# ENV ANVISERVER_RAVEN_DSN=''

# gunicorn config
# ENV PORT=8000
# ENV GUNICORN_WORKERS=4
# ENV GUNICORN_BIND=0.0.0.0:${PORT}

# create dir structure
RUN mkdir -p ${ANVISERVER_DATA_DIR}

# install dependencies
RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y git gcc
RUN pip install --no-cache-dir cython gunicorn virtualenv numpy

# clone git repos
RUN git clone --recurse-submodules --jobs 4 --branch ${ANVIO_BRANCH} https://github.com/merenlab/anvio 
# copy 
COPY . /app/anviserver
# or clone
#RUN git clone --branch ${ANVIO_BRANCH} https://github.com/merenlab/anviserver

# install pip requirements
RUN pip install --no-cache-dir -r anvio/requirements.txt
RUN pip install --no-cache-dir -r anviserver/requirements.txt


ENV PYTHONPATH="/app/anvio:/app/anviserver:${PYTHONPATH}"

# replace strings in config file with environment variables
RUN sed -e "s/DEBUG = .*/DEBUG = bool(os.environ.get('ANVISERVER_DEBUG', False))/g" \
    -e "s/LANGUAGE_CODE = .*/LANGUAGE_CODE  = os.environ.get('ANVISERVER_LANGUAGE_CODE', 'en-us')/g" \
    -e "s/TIME_ZONE = .*/TIME_ZONE = os.environ.get('ANVISERVER_TIME_ZONE', 'UTC')/g" \
    -e "s/USE_TZ = .*/USE_TZ = bool(os.environ.get('ANVISERVER_USE_TZ', True))/g" \
    -e "s/USE_I18N = .*/USE_I18N = bool(os.environ.get('ANVISERVER_USE_I18N', True))/g" \
    -e "s/USE_L10N = .*/USE_L10N = bool(os.environ.get('ANVISERVER_USE_L10N', True))/g"\
    -e "s/ACCOUNT_ACTIVATION_DAYS = .*/ACCOUNT_ACTIVATION_DAYS = int(os.environ.get('ANVISERVER_ACCOUNT_ACTIVATION_DAYS', 30))/g" \
    -e "s/EMAIL_USE_TLS = .*/EMAIL_USE_TLS = bool(os.environ.get('ANVISERVER_EMAIL_USE_TLS', True))/g" \
    -e "s/EMAIL_HOST = .*/EMAIL_HOST = os.environ.get('ANVISERVER_EMAIL_HOST', 'smtp.gmail.com')/g" \
    -e "s/EMAIL_HOST_USER = .*/EMAIL_HOST_USER = os.environ.get('ANVISERVER_EMAIL_HOST_USER', 'anvi.server@gmail.com')/g" \
    -e "s/EMAIL_PORT = .*/EMAIL_PORT = int(os.environ.get('ANVISERVER_EMAIL_PORT', 587))/g" \
    -e "s/DEFAULT_FROM_EMAIL = .*/DEFAULT_FROM_EMAIL = os.environ.get('ANVISERVER_FROM_EMAIL', 'anvi.server@gmail.com')/g" \
    -e "s/USER_DATA_DIR = .*/USER_DATA_DIR = os.path.join(os.environ.get('ANVISERVER_DATA_DIR'), 'userdata')/g" \
    -e "s/os.path.join(BASE_DIR, 'db.sqlite3')/os.path.join(os.environ.get('ANVISERVER_DATA_DIR'), 'db.sqlite3')/g" \
    -i "anviserver/anviserver/settings.py"

# rename settings secret to production name
RUN mv anviserver/anviserver/settings_secrets.docker.py anviserver/anviserver/settings_secrets.py 

# delete interactive symlink
RUN rm -f anviserver/main/static/interactive
RUN ln -s /app/anvio/anvio/data/interactive/ /app/anviserver/main/static/interactive


# change to anviserver workdir
WORKDIR /app/anviserver

# RUN python manage.py migrate
RUN yes "yes" | python manage.py collectstatic
#RUN python manage.py createsuperuser
# RUN python reset_cache.py


RUN ["useradd", "-m", "anviserver"]
RUN chown -R anviserver:anviserver /app

USER anviserver:anviserver

EXPOSE ${PORT}

ENTRYPOINT [ "bash" ]
CMD [ "docker_entrypoint.sh" ]

