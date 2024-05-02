FROM alpine:edge

RUN apk add --no-cache lxc lxcfs
ADD entrypoint.sh /entrypoint

 ENTRYPOINT ["/entrypoint"]
