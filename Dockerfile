FROM ubuntu:22.04

# fortune-mod needs its data files separately: fortunes-min provides those.
# cowsay generates the ASCII art. netcat-openbsd provides "nc" with native
# support for the -N flag wisecow.sh uses (shuts down the socket after EOF
# on stdin). Note: this is NOT the same as installing "nmap" or "ncat" —
# Ncat (from nmap) doesn't have a short -N flag at all, it does that
# behavior by default. netcat-openbsd is the one that matches the script.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        fortune-mod \
        fortunes-min \
        cowsay \
        netcat-openbsd \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# cowsay and fortune both install to /usr/games on Debian/Ubuntu, which
# isn't on PATH by default for non-login shells.
ENV PATH="/usr/games:${PATH}"

WORKDIR /app
COPY wisecow.sh .
RUN chmod +x wisecow.sh

EXPOSE 4499

CMD ["./wisecow.sh"]
