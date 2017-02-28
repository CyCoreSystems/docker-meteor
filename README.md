## Meteor 1.4

The `latest` Docker tag and the `master` git branch are for Meteor 1.4+.  For
prior versions of Meteor, please use the `legacy` tag and branch.

In order to keep the size of the image down, the `current` tag does _not_
include `build-essential` tools.  If you are using modules which do not supply
binary versions for your platform, please use the `build` tag, which does
include `build-essential`.

## Features:

 * Meteor 1.4+ package/bundle support (for previous Meteor versions, use the
   `legacy` branch/tag)
 * Bundle-based execution
   * directory referenced as `APP_DIR` (meteor build --directory); defaults to `/home/meteor/www`
   * downloaded with `curl` from `BUNDLE_URL` (if supplied)
   * set `CURL_OPTS` if you need to pass additional parameters
 * Source-based build/execution
   * Downloads latest Meteor tool at runtime (always the latest tool version unless a `RELEASE` is specified, but apps run with their own versions)
   * Supply source at `SRC_DIR` (defaults to `/home/meteor/src`)
   * Supply source from `REPO` (git clone URL)
      * Optionally specify a `DEPLOY_KEY` file for SSH authentication to private repositories
      * Optionally specify a `BRANCH` is not the default `master` (can also be a tag name)
 * References your external MongoDB database
   * Uses Docker links (i.e. `MONGO_PORT`...)
   * Explicit Mongo URLs by at `MONGO_URL`
   * NOTE: This does NOT set `MONGO_OPLOG_URL`.  There were too many potention complications.  As a result, unless you explicitly set `MONGO_OPLOG_URL`, Meteor will fall back to a polling-based approach to database synchronization.  Note that oplog tailing requires a working replica set on your MongoDB server as well as access to the `local` database.
 * Optionally specify the port on which the web server should run (`PORT`); defaults to 80
 * Non-root location of Meteor tree; the script will search for the first .meteor directory
 * _NOTE_: PhantomJS is no longer pre-installed.  This package was swelling the size of the image by 50%, and it is not maintainable with the standard Docker Node images.  Instead, please use one of the docker-friendly (read port-based) spiderable packages on Meteor, such as [ongoworks:spiderable](https://atmospherejs.com/ongoworks/spiderable);  if there is demand, please create an issue on Github, and I'll see about managing a separate branch for it.

## Versions

The Meteor tool (if required; see Modes of Operation below) is downloaded at
runtime, so it is no longer packaged and the version of this docker image does
not matter for the version of meteor.

You can specify which version of Meteor you want to be installed by setting the
`RELEASE` as required.  However, this release of `ulexus/meteor` does require a
minimum version of 1.4 for your Meteor application.

## Modes of operation

There are two basic modes of operation for this image: source and pre-bundled.
The source method allows the greatest flexibility, since it builds and bundles
Meteor on the deployment system inside the same container.  However, it also
takes much longer and requires a much larger disk footprint.

### Source mode

To utilize source mode, define one of `SRC_DIR` or `REPO`:

  - `SRC_DIR`
      If you put your application source in the directory pointed to by `SRC_DIR` (`/home/meteor/src`, by default), this container will download the Meteor tool,
      build your application, bundle it, then execute it.  It is usually sufficient to simply pass `docker run` an argument like `-v /srv/myApp:/src/app`.

  - `REPO`
      If you populate the `REPO` environment variable, it is presumed that this is where your application source resides.  This container will
      `git pull` your `REPO`, change to `master` or the supplied `BRANCH` (which can also be a tag).  The source tree will be placed in
      `APP_DIR`, and the script will pick up processing `APP_DIR` (above) from there.

When the container is run, the appropriate version of the Meteor tool will be
downloaded and installed, your application will be built/bundled, and then it
will be run.  This process can take several *minutes* to complete.

#### Running without root

As of Meteor 1.4.2, running Meteor as root has been strongly dissuaded.  As a
result, we now drop root privileges after starting the container.  This means
that if you are bind-mounting your source or bundle directories, the files must
be **readable** and **writable** by the container's unprivileged user (**UID 1000**).

### Pre-bundled mode

To utilize the pre-bundled mode, **DO NOT** define `SRC_DIR` or `REPO`.  Instead
define one of `APP_DIR` or `BUNDLE_DIR`:

  - `APP_DIR`
      If you put your bundled application in the directory pointed to by `APP_DIR` (`/home/meteor/www`, by default), this container will attempt to find a Meteor bundle
      in this directory and then start Node to run that bundle.  The Meteor tool will not be installed (as a bundled Meteor app needs only Node).
      The default `APP_DIR` is `/home/meteor/www`, so you may attach that as a volume, for greatest simplicity.  Something like: `-v /srv/myApp:/home/meteor/www`.
  - `BUNDLE_URL`
      If you populate `BUNDLE_URL`, the container expects to find a bundled tarball, as generated by `meteor build ./` at this URL.  The tarball is
      downloaded (with curl... so you may set `CURL_OPTS` as required) and extracted to the bundle directory, and the process continues from `BUNDLE_DIR` (above).

When the container is run, the Meteor tool will NOT be downloaded.  Instead,
`npm install` will be run to resolve any dependencies for the server, and your
application will be run directly with NodeJS.

## Examples:

### git repo with non-default (master) branch
```sh
docker run --rm \
  -e ROOT_URL=http://testsite.com \
  -e REPO=https://github.com/yourName/testsite \
  -e BRANCH=testing \
  -e MONGO_URL=mongodb://mymongoserver.com:27017/mydatabase \
  -e MONGO_OPLOG_URL=mongodb://mymongoserver.com:27017/local \
  ulexus/meteor
```

### app source from a local directory on host (/home/user/myapp)
```sh
docker run --rm \
  -e ROOT_URL=http://testsite.com \
  -v /home/user/myapp:/home/meteor/src \
  -e MONGO_URL=mongodb://mymongoserver.com:27017/appdb \
  -e MONGO_OPLOG_URL=mongodb://mymongoserver.com:27017/local \
  ulexus/meteor
```

### pre-bundled app from a local directory on host (/home/user/myapp)
```sh
docker run --rm \
  -e ROOT_URL=http://testsite.com \
  -v /home/user/myapp:/home/meteor/www \
  -e MONGO_URL=mongodb://mymongoserver.com:27017/appdb \
  -e MONGO_OPLOG_URL=mongodb://mymongoserver.com:27017/local \
  ulexus/meteor
```

### local app source directory on host (/home/user/myapp) with specific Meteor release (1.4.2.1)
```sh
docker run --rm \
  -e ROOT_URL=http://testsite.com \
  -v /home/user/myapp:/home/meteor/src \
  -e MONGO_URL=mongodb://mymongoserver.com:27017/appdb \
  -e MONGO_OPLOG_URL=mongodb://mymongoserver.com:27017/local \
  -e RELEASE=1.4.2.1 \
  ulexus/meteor
```

### Unit file

There is also a sample systemd [unit file](meteor.myapp@.service) in the Github repository.

### Build with bundled app

Pre-bundling your Meteor application will make it start *much* faster and will
allow the container to maintain a smaller storage footprint.  However, it does
require that you build for the same architecture on which you will be deploying.

```bash
cd $app_source
meteor build --directory /tmp/export-meteor/build
cat >/tmp/export-meteor/Dockerfile <<ENDHERE
FROM ulexus/meteor
COPY build /home/meteor/www
RUN chown -R meteor:meteor /home/meteor/
ENDHERE
cd /tmp/export-meteor
docker build -t myapp .
docker push myapp
```

### Kubernetes

There is a complete example with build script of building and running a
versioned container in kubernetes in the
[examples](https://github.com/CyCoreSystems/docker-meteor/tree/v1.4/examples)
directory.

