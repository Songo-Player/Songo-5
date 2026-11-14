# makensis, for building the Windows installer on Linux.
# build_platforms/windows/build_windows.sh builds and runs this.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends nsis \
    && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["makensis"]
