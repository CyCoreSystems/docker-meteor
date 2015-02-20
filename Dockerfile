# DOCKER-VERSION 1.4.1
# METEOR-VERSION 1.0.3.1
FROM gliderlabs/alpine

# Install node, git (minimalist version: no phantomjs)
RUN apk-install nodejs git

# Build dependencies
RUN apk-install --virtual build-dependencies python-dev build-base curl \
   && npm install -g fibers \
   && curl https://install.meteor.com/ |sh \
   && apk del build-dependencies

# Install fibers -- this doesn't seem to do any good, for some reason
#RUN npm install -g fibers

# Install Meteor
#RUN curl https://install.meteor.com/ |sh

# Remove build dependencies
#RUN apk del build-dependencies

# Install entrypoint
ADD entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

# Add known_hosts file
ADD known_hosts /root/.ssh/known_hosts

# Make sure we have a directory for the application
RUN mkdir -p /var/www

EXPOSE 80

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
CMD []
