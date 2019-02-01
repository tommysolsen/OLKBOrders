FROM elixir:1.7
LABEL "maintainer"="tommysolsen@gmail.com"
LABEL "traefik.enable"="false"

WORKDIR /app

ADD . .

RUN ["mix", "local.hex", "--force"]
RUN ["mix", "deps.get", "-y"]

CMD ["mix", "run"]
