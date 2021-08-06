FROM node:16 AS frontend
WORKDIR /oais-web
COPY ./oais-web .
RUN npm install && npm run build-prod

FROM python:3.7-alpine
ENV PYTHONUNBUFFERED 1
WORKDIR /oais-platform
COPY ./oais-platform .
RUN apk add --no-cache postgresql-libs && \
    apk add --no-cache --virtual .build-deps \
    gcc musl-dev libffi-dev openssl-dev cargo postgresql-dev && \
    pip install -r requirements.txt --no-cache-dir && \
    apk --purge del .build-deps && \
    rm -r /root/.cargo
COPY --from=frontend /oais-web/public /assets
CMD ["sh", "-c", "python3 manage.py migrate && python3 manage.py runserver 0.0.0.0:8000"]