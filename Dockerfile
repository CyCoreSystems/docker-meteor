FROM debian:stretch

# Create user meteor who will run all entrypoint instructions
RUN useradd meteor -G staff -m -s /bin/bash
WORKDIR /home/meteor

# Install git, curl
RUN apt-get update && \
   apt-get install -y git curl bzip2 gnupg libcap2-bin && \
   (curl https://deb.nodesource.com/setup_4.x | bash) && \
   apt-get install -y nodejs jq && \
   apt-get clean && \
   rm -Rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN npm install -g semver

# Install entrypoint
COPY entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

# Add known_hosts file
COPY known_hosts .ssh/known_hosts

RUN chown -R meteor:meteor .ssh /usr/bin/entrypoint.sh

EXPOSE 3000

# Execute entrypoint as user meteor
ENTRYPOINT ["su", "-c", "/usr/bin/entrypoint.sh", "meteor"]
CMD []
