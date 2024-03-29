FROM node:18-alpine AS frontend
WORKDIR /oais-web
COPY ./oais-web .
RUN npm i npm --global && npm install --force && npm run build

FROM python:3.11-alpine
ENV PYTHONUNBUFFERED 1
RUN apk add --update \
  build-base \
  cairo \
  cairo-dev \
  cargo \
  freetype-dev \
  gcc \
  gdk-pixbuf-dev \
  gettext \
  jpeg-dev \
  lcms2-dev \
  libffi-dev \
  musl-dev \
  openjpeg-dev \
  openssl-dev \
  pango-dev \
  poppler-utils \
  postgresql-client \
  postgresql-dev \
  py-cffi \
  python3-dev \
  rust \
  tcl-dev \
  tiff-dev \
  tk-dev \
  zlib-dev \
  # to allow pip install dependencies from git repositories
  git \
  swig

WORKDIR /oais-platform
COPY ./oais-platform/requirements.txt ./
RUN apk add --no-cache postgresql-libs && \
    apk add --no-cache --virtual .build-deps \
    gcc libc-dev linux-headers postgresql-dev musl-dev zlib zlib-dev \
    # gssapi header to compile pykerberos
    krb5-dev && \
    pip install -r requirements.txt --no-cache-dir && \
    apk --purge del .build-deps
COPY ./oais-platform .
COPY --from=frontend /oais-web/build /assets
CMD ["sh", "-c", "python3 manage.py migrate && python3 manage.py runserver"]
