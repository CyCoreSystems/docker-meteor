# DOCKER-VERSION 1.8.1
# METEOR-VERSION 1.2.1
FROM debian:jessie

RUN apt-get update

# Install git, curl
RUN apt-get update && \
   apt-get install -y git curl && \
   (curl https://deb.nodesource.com/setup | sh) && \
   apt-get install -y nodejs jq && \
   apt-get clean && \
   rm -Rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Make sure we have a directory for the application
RUN mkdir -p /var/www
RUN chown -R www-data:www-data /var/www

# Install Meteor -- now done on-demand to reduce image size
# If you supply your pre-bundled app, you do not need the
# Meteor tool.
#RUN curl https://install.meteor.com/ |sh

# Install entrypoint
ADD entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

# Add known_hosts file
ADD known_hosts /root/.ssh/known_hosts

EXPOSE 80

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
CMD []
