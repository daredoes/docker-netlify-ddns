FROM ubuntu:20.04

# Order based on how to effectively cache docker image
RUN apt-get update
# tzdata has an interactive prompt that doesn't play nicely with docker when its a dependency
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata

RUN apt-get install -y curl wget
RUN apt-get install dnsutils -y
RUN apt-get install jq -y

COPY ./start.sh /
RUN chmod +x /start.sh
COPY ./netlify-ddns.sh /
RUN chmod +x /netlify-ddns.sh
STOPSIGNAL SIGINT

ENV NETLIFY_DOMAIN=example.com
ENV NETLIFY_TOKEN=xxxxx
ENV NETLIFY_SUBDOMAIN=www
ENV NETLIFY_TTL=3600


ENTRYPOINT [ "/start.sh" ]