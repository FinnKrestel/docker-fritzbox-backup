FROM docker:dind

RUN apk add --no-cache bash openssl gnupg

VOLUME [ "/backups" ]

ADD fritzbox-config-downloader.sh /fritzbox-config-downloader.sh
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /fritzbox-config-downloader.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT /entrypoint.sh