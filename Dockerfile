# DOCKER-VERSION 1.5.0
# METEOR-VERSION 1.1.0.1
FROM stackbrew/ubuntu:trusty

RUN apt-get update

### For latest Node
RUN apt-get install -y software-properties-common
RUN add-apt-repository -y ppa:chris-lea/node.js
RUN apt-get update
RUN apt-get install -y build-essential nodejs
###

### For standard Ubuntu Node
#RUN apt-get install -y build-essential nodejs npm
#RUN ln -s /usr/bin/nodejs /usr/bin/node
###

# Install git, curl, python, and phantomjs
RUN apt-get install -y git curl python phantomjs

# Make sure we have a directory for the application
RUN mkdir -p /var/www
RUN chown -R www-data:www-data /var/www

# Install fibers -- this doesn't seem to do any good, for some reason
RUN npm install -g fibers

# Install Meteor
RUN curl https://install.meteor.com/ |sh

# Install entrypoint
ADD entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

# Add known_hosts file
ADD known_hosts /root/.ssh/known_hosts

EXPOSE 80

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
CMD []
