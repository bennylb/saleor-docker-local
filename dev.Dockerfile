### Build and install packages
FROM python:3.6 as build-python
ARG STATIC_URL
ARG HOST_UID
ARG HOST_GID

RUN apt-get -y update && \
    apt-get install -y gettext && \
    # Cleanup apt cache
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install pipenv
ADD Pipfile /app/
ADD Pipfile.lock /app/
WORKDIR /app
RUN pipenv install --system --deploy --dev


### Final image
FROM python:3.6-slim
ARG STATIC_URL
ARG HOST_UID
ARG HOST_GID
ENV STATIC_URL ${STATIC_URL:-/static/}
ENV HOST_UID ${HOST_UID:-1000}
ENV HOST_GID ${HOST_GID:-HOST_UID}
ENV PORT 8000
ENV PYTHONUNBUFFERED 1
ENV PROCESSES 4

RUN apt-get update && \
    apt-get install -y libxml2 libssl1.1 libcairo2 libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf2.0-0 shared-mime-info mime-support gosu && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build-python /usr/local/lib/python3.6/site-packages/ /usr/local/lib/python3.6/site-packages/
COPY --from=build-python /usr/local/bin/ /usr/local/bin/
COPY --from=node:10 /usr/local/lib/ /usr/local/lib/
COPY --from=node:10 /usr/local/bin/ /usr/local/bin/

COPY docker-entrypoint.sh /usr/local/bin/

RUN useradd --non-unique --uid $HOST_UID --gid $HOST_GID --create-home saleor && \
    install -d -o $HOST_UID -g $HOST_GID /app/node_modules && \
    install -d -o $HOST_UID -g $HOST_GID /app/media && \
    install -d -o $HOST_UID -g $HOST_GID /app/static

WORKDIR /app

EXPOSE 8000
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["uwsgi", "/app/saleor/wsgi/uwsgi.ini"]
