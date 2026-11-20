FROM python:3.11-slim-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends apache2-utils subversion ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Trac 1.6 imports pkg_resources, which newer setuptools no longer ship.
# TracXMLRPC has no Python 3 release on PyPI, so it comes from trac-hacks.org.
RUN pip install --no-cache-dir "setuptools<70" wheel \
 && pip install --no-cache-dir "Trac==1.6" "Jinja2>=2.9.3" "Babel>=2.2,<2.10" \
 && pip install --no-cache-dir --no-build-isolation \
      "svn+https://trac-hacks.org/svn/xmlrpcplugin/trunk@18657"

COPY entrypoint.sh /entrypoint.sh

EXPOSE 8000
ENTRYPOINT ["/entrypoint.sh"]
