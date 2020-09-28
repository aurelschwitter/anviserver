FROM python:3.6-slim-buster

# switch to user root, as the base image uses USER 1000
# we will switch later to the user "anvio"
USER root

# use /app as workdir
WORKDIR /app

# git configs
ENV ANVIO_BRANCH=v5
ENV ANVISERVER_DATA_DIR=/app/data

# create dir structure
RUN mkdir -p ${ANVISERVER_DATA_DIR}

# install dependencies
RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y git gcc
RUN pip install --no-cache-dir cython gunicorn virtualenv numpy

# clone git repos
RUN git clone --recurse-submodules --jobs 4 --branch ${ANVIO_BRANCH} https://github.com/merenlab/anvio 
# copy files from repository (we are already in a cloned repo - no need to clone again)
COPY . /app/anviserver


# install pip requirements
RUN pip install --no-cache-dir -r anvio/requirements.txt
RUN pip install --no-cache-dir -r anviserver/requirements.txt


ENV PYTHONPATH="/app/anvio:/app/anviserver:${PYTHONPATH}"

# replace strings in config file with environment variables
RUN sed -e "s/DEBUG = .*/DEBUG = (os.environ.get('ANVISERVER_DEBUG', 'false')).lower() == 'true'/g" \
    -e "s/LANGUAGE_CODE = .*/LANGUAGE_CODE  = os.environ.get('ANVISERVER_LANGUAGE_CODE', 'en-us')/g" \
    -e "s/TIME_ZONE = .*/TIME_ZONE = os.environ.get('ANVISERVER_TIME_ZONE', 'UTC')/g" \
    -e "s/USE_TZ = .*/USE_TZ = (os.environ.get('ANVISERVER_USE_TZ', 'true')).lower() == 'true'/g" \
    -e "s/USE_I18N = .*/USE_I18N = (os.environ.get('ANVISERVER_USE_I18N', 'true')).lower() == 'true'/g" \
    -e "s/USE_L10N = .*/USE_L10N = (os.environ.get('ANVISERVER_USE_L10N', 'true')).lower() == 'true'/g"\
    -e "s/ACCOUNT_ACTIVATION_DAYS = .*/ACCOUNT_ACTIVATION_DAYS = int(os.environ.get('ANVISERVER_ACCOUNT_ACTIVATION_DAYS', 30))/g" \
    -e "s/EMAIL_USE_TLS = .*/EMAIL_USE_TLS = os.environ.get('ANVISERVER_EMAIL_USE_TLS', 'true').lower() == 'true'/g" \
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

# invalidate browser cache - every new docker image has new assets
# currently fails, so commented out
# RUN python reset_cache.py

# create and switch to user anviserver
RUN ["useradd", "-m", "anviserver"]
RUN chown -R anviserver:anviserver /app/data /app/anviserver
USER anviserver:anviserver

EXPOSE 8000

# expose static folder as volume (will be consumed by nginx)
VOLUME [ "/app/anviserver/static" ]

ENTRYPOINT [ "bash" ]
CMD [ "docker_entrypoint.sh" ]

