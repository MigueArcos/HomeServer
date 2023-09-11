FROM i386/debian:buster-slim

# install packages
RUN apt-get update \
  && apt-get install -y \
  curl \
  sudo \
  whois \
  usbutils \
  cups \
  cups-bsd \
  cups-filters
  # foomatic-db-compressed-ppds \
  # printer-driver-all \
  # openprinting-ppds \
  # printer-driver-cups-pdf \

# Download drivers
RUN curl https://download.brother.com/welcome/dlf100419/hl1110lpr-3.0.1-1.i386.deb --output lpr-driver-hl-1110.deb \ 
  && curl https://download.brother.com/welcome/dlf100421/hl1110cupswrapper-3.0.1-1.i386.deb --output cups-driver-hl-1110.deb \
  && curl https://download.brother.com/welcome/dlf103618/dcpt310pdrv-1.0.1-0.i386.deb --output driver-dcp-t310.deb \
  && curl https://gdlp01.c-wss.com/gds/9/0100010919/01/cnijfilter2-6.10-1-deb.tar.gz --output driver-pixma-g2060-deb.tar.gz

# Install drivers
RUN tar -xvzf driver-pixma-g2060-deb.tar.gz \
  # This doesn't seem to be necessary && chmod +x cnijfilter2-6.10-1-deb/install.sh \
  && dpkg -iG ./cnijfilter2-6.10-1-deb/packages/cnijfilter2_6.10-1_i386.deb \
  && dpkg -i --force-all lpr-driver-hl-1110.deb \
  && dpkg -i --force-all cups-driver-hl-1110.deb \
  && dpkg -i --force-all driver-dcp-t310.deb

# Clean packages
RUN apt-get remove -y --purge printer-driver-gutenprint libgutenprint9 libgutenprint-common \
  && apt-get clean \
  && apt-get autoremove \
  && rm -rf /var/lib/apt/lists/*

# Add user and disable sudo password checking
RUN useradd \
  --groups=sudo,lp,lpadmin \
  --create-home \
  --home-dir=/home/print \
  --shell=/bin/bash \
  --password=$(mkpasswd print) \
  print \
&& sed -i '/%sudo[[:space:]]/ s/ALL[[:space:]]*$/NOPASSWD:ALL/' /etc/sudoers

# Copy the default configuration file
COPY --chown=root:lp default.cupsd.conf /etc/cups/cupsd.conf

# Default shell
CMD ["/usr/sbin/cupsd", "-f"]