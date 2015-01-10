## Features:

 * Meteor 1.x package/bundle support
 * Git-based repository + branch/tag via environment variables (`REPO` and `BRANCH`)
 * Bundle URL via environment variable (`BUNDLE_URL`)
 * Bind-mount, volume, Dockerfile `ADD` via environment variable (`APP_DIR`)
 * Uses docker-linked MongoDB (i.e. `MONGO_PORT`...) or explicit setting via environment variable (`MONGO_URL`)
 * Enables oplog tailing with `MONGO_OPLOG_URL`, which defaults to the `local` database of the docker `MONGO_PORT`... variables
 * Optionally specify the port on which the web server should run (`PORT`); defaults to 80
 * Deploy-key support (set `DEPLOY_KEY` to the location of your SSH key file)
   * old `GITHUB_DEPLOY_KEY` is also supported but deprecated
 * Non-root location of Meteor tree; the script will search for the first .meteor directory
 * PhantomJS pre-installed to support `spiderable` package

## Versions:

Regardless of the version number of the tool included in this package, your application will run
on whatever version of Meteor it is configured to run under.

## Example run:

`docker run --rm -e ROOT_URL=http://testsite.com -e REPO=https://github.com/yourName/testsite -e BRANCH=testing -e MONGO_URL=mongodb://mymongoserver.com:27017 ulexus/meteor`

There is also a sample systemd unit file in the Github repository.
