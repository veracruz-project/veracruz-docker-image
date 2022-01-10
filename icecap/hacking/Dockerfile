# AUTHORS
#
# The Veracruz Development Team.
#
# COPYRIGHT
#
# See the `LICENSE_MIT.markdown` file in the Veracruz root directory for licensing
# and copyright information.

FROM veracruz/base:latest

ENV PATH="/nix/env/bin:${PATH}"
ENV MANPATH="/nix/env/share/man:${MANPATH}"
ENV NIX_SSL_CERT_FILE=/nix/env/etc/ssl/certs/ca-bundle.crt
ENV NIX_BUILD_SHELL bash

# HACK for persistent git cache.
ENV XDG_CACHE_HOME=/nix/cache

RUN mkdir -p /work

COPY icecap/install-nix.sh /work
COPY icecap/hacking/setup.sh /work
COPY icecap/hacking/nix.conf /etc/nix/

WORKDIR /work
