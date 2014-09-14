Features:

 * Meteor 0.9.x package/bundle support
 * Git-based repository + branch/tag via environment variables (`REPO` and `BRANCH`)
 * Bundle URL via environment variable (`BUNDLE_URL`)
 * Bind-mount, volume, Dockerfile `ADD` via environment variable (`APP_DIR`)
 * Uses docker-linked MongoDB (i.e. `MONGO_PORT`...) or explicit setting via environment variable (`MONGO_URL`)
 * Optionally specify the port on which the web server should run (`PORT`); defaults to 80
 * Deploy-key support (for Github) (set `GITHUB_DEPLOY_KEY` to the location of your keyfile)

Example run:

`docker run --rm -e ROOT_URL=http://testsite.com -e REPO=https://github.com/yourName/testsite -e BRANCH=testing -e MONGO_URL=mongodb://mymongoserver.com:27017 ulexus/meteor`

