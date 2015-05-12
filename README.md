[![Gem Version](https://badge.fury.io/rb/dockly.png)](http://badge.fury.io/rb/dockly)
[![Build Status](https://travis-ci.org/swipely/dockly.png?branch=refactor_setup)](https://travis-ci.org/swipely/dockly)
[![Dependency Status](https://gemnasium.com/swipely/dockly.png)](https://gemnasium.com/swipely/dockly)

![Dockly](https://raw.github.com/swipely/dockly/master/img/dockly.png)
======================================================================

`dockly` is a gem made to ease the pain of packaging an application. For this gem to be useful, you will want to use [Docker](http://docker.io) for process isolation.

Although only a specific type of repository may be used, these assumptions allow us to define a simple DSL to describe your repository.

Tool Requirements
-----------------

To use the generated startup scripts, you'll need to use AWS CLI v1.5.0+

Usage
-----

Once a package block has been defined by the DSL below, dockly is invoked by either (for a deb) `bundle exec dockly build #{deb block name}` or `bundle exec rake dockly:deb:#{deb block name}`.
If looking to just build a `docker` block, run either `bundle exec dockly docker #{docker block name}` or `bundle exec rake dockly:docker:#{docker block name}`.
To build without exporting, run add either `--no-export` or `:noexport` to the CLI program or Rake task

The DSL
-------

The DSL is broken down into multiple objects, all of which conform to a specific format. Each object starts with the name of the section,
followed by a name for the object you're creating, and a block for configuration.

```ruby
docker :test_docker do
  # code here
end
```

Each object has an enumeration of valid attributes. The following code sets the `repository` attribute in a `docker` called `test_docker`:

```ruby
docker :test_docker do
  repository 'an-awesome-name'
end
```

Finally, each object has zero or more valid references to other DSL objects. The following code sets `deb` that references a `docker`:

```ruby
docker :my_docker do
  repository 'my-name'
end

deb :my_deb do
  docker :my_docker
end
```

Below is an alternative syntax that accomplishes the same thing:

```ruby
deb :my_deb do
  docker do
    repository 'my-name'
  end
end
```

`build_cache`
-------------

Optional

The `build_cache` DSL is used to prevent rebuilding assets every build and used cached assets.

- `s3_bucket`
    - required: `true`
    - description: the bucket name to download and upload build caches to
- `s3_object_prefix`
    - required: `true`
    - description: the name prepended to the package; allows for namespacing your caches
- `hash_command`
    - required: `true`
    - description: command run to determine if the build cache is up to date (eg. `md5sum ... | awk '{ print $1 }'`)
- `parameter_command`
    - required: `false`
    - allows multiple
    - description: command run to build specific versions of build caches -- useful for multiple operating systems (not required)
- `build_command`
    - required: `true`
    - description: command run when the build cache is out of date
- `output_dir`
    - required: `true`
    - description: where the cache is located in the Docker image filesystem
- `tmp_dir`
    - required: `true`
    - default: `/tmp`
    - description: where the build cache files are stored locally; this should be able to be removed easily since they all exist in S3 as well
- `use_latest`
    - required: `false`
    - default: `false`
    - description: when using S3, will insert the S3 object tagged as latest in your "s3://s3_bucket/s3_object_prefix" before running the build command to quicken build times
- `keep_old_files`
    - required: `false`
    - default: `false`
    - description: if this option is false when using docker, it will overwrite files that already exist in `output_dir`

`docker`
--------

The `docker` DSL is used to define Docker containers. It has the following attributes:

- `registry_import`
    - required: `false` -- only required when `import` is not supplied
    - description: the location  of the base image to start building from
    - examples: `paintedfox/ruby`, `registry.example.com/my-custom-image`
- `build_env`
    - required: `false`
    - description: Hash whose values are environment variables and keys are their values. These variables are only used during build commands, exported images will not contain them.
- `import`
    - required: `false` -- only required when `registry_import` is not supplied
    - description: the location (url or S3 path) of the base image to start building from
- `git_archive`:
    - required: `false`
    - default: `nil`
    - description: the relative file path of git repo that should be added to the container
- `build`
    - required: `true`
    - description: aditional Dockerfile commands that you'd like to pass to `docker build`
- `repository`
    - required: `true`
    - default: `'dockly'`
    - description: the repository of the created image
- `name`
    - alias for: `repository`
- `tag`
    - required: `true`
    - description: the tag of the created image
- `build_dir`
    - required: `true`
    - default: `./build/docker`
    - description: the directory of the temporary build files
- `package_dir`
    - required: `true`
    - default: `/opt/docker`
    - description: the location of the created image in the package
- `timeout`
    - required: `true`
    - default: `60`
    - description: the excon timeout for read and write when talking to docker through docker-api
- `build_caches`
    - required: `false`
    - default: `[]`
    - description: a listing of references to build caches to run
- `s3_bucket`
    - required: `false`
    - default: `nil`
    - description: S3 bucket for where the docker image is exported
- `s3_object_prefix`
    - required: `false`
    - default: `nil`
    - description: prefix to be added to S3 exported docker images
- `tar_diff`
    - required: `false`
    - default: `false`
    - description: after docker export, performs a diff between the base image and the new image

In addition to the above attributes, `docker` has the following references:

- `build_cache`
    - required: `false`
    - allows multiple
    - class: `Dockly::BuildCache`
    - description: a caching system to stop rebuilding/compiling the same files every time
- `registry`
    - required: `false`
    - allows one
    - class: `Dockly::Docker::Registry`
    - description: a registry to push to in lieu of exporting as a tar -- the registry will be automatically pulled upon installing the package

Need finer control of Docker packages? We also wrote [docker-api](https://github.com/swipely/docker-api).

`registry`
--------

The `registry` DSL is used to define Docker Registries. It has the following attributes:

- `authentication_required`
    - required: `false`
    - default: `true`
    - description: a boolean that determines whether or not authentication is required on the registry.
- `username`
    - required: `true` unless `authentication_required` is `false`
    - description: the username to authenticate
- `email`:
    - required: `true` unless `authentication_required` is `false`
    - description: the email to authenticate
- `password`:
    - required: `false`
    - description: the user's password; unless supplied, `ENV['DOCKER_REGISTRY_PASSWORD']` will be checked. not that `ENV['DOCKER_REGISTRY_PASSWORD']` is required to be set on the host on to which the package will be deployed
- `server_address`:
    - required: `true`
    - default: `https://index.docker.io/v1`
    - description: the server where the registry lives

`foreman`
---------

Optional

The `foreman` DSL is used to define the foreman export scripts. It has the following attributes:

- `env`
    - description: accepts same arguments as `foreman start --env`
- `procfile`
    - required: `true`
    - default: `'Procfile'`
    - description: the Procfile to use
- `type`
    - required: `true`
    - default: `'upstart'`
    - description: the type of foreman script being defined
- `user`
    - required: `true`
    - default: `'nobody'`
    - description: the user the scripts will run as
- `root_dir`
    - required: `false`
    - default: `'/tmp'`
    - description: set the root directory
- `init_dir`
    - required: `false`
    - default: `'/etc/init'`
    - description: the location of the startup scripts in the rpm -qplian package
- `prefix`
    - required: `false`
    - default: `nil`
    - description: a prefix given to each command from foreman.
    must be using https://github.com/adamjt/foreman for this to work

`deb`
-----

The `deb` DSL is used to define Debian packages. It has the following attributes:

- `package_name`
    - required: `true`
    - description: the name of the created package
- `version`
    - required: `true`
    - default: `0.0`
    - description: the version of the created package
- `release`
    - required: `true`
    - default: `0`
    - description: the realese version of the created package
- `arch`
    - required: `true`
    - default: `x86_64`
    - description: the intended architecture of the created package
- `vendor`
    - required: `false`
    - default:  `Dockly`
    - description: Vendor name for this package
- `build_dir`
    - required: `true`
    - default: `build/deb`
    - description: the location of the temporary files on the local file system
- `pre_install`, `post_install`, `pre_uninstall`, `post_uninstall`
    - required: `false`
    - default: `nil`
    - description: script hooks for package events
- `s3_bucket`
    - required: `false`
    - default: `nil`
    - description: the s3 bucket the package is uploaded to
- `file SOURCE DEST`
    - required: `false`
    - description: places SOURCE at DEST in the Debian package (can have multiple of these)

In addition to the above attributes, `deb` has the following references:

- `docker`
    - required: `false`
    - default: `nil`
    - class: `Dockly::Docker`
    - description: configuration for an image packaged with the deb
- `foreman`
    - required: `false`
    - default: `nil`
    - class: `Dockly::Foreman`
    - description: any Foreman scripts used in the deb.

`rpm`
-----

Same as `deb` above, but with the following additions:

- `vendor`
    - required: `true`
    - default:  `Dockly`
    - description: Vendor name for this package
- `os`
    - required: `true`
    - default: `linux`
    - description: The operating system to target this rpm for

Demo
===

```ruby
deb :dockly_package do
  package_name 'dockly_package'

  docker do
    name :dockly_docker
    import 's3://.../base-image.tar.gz'
    git_archive '/app'
    timeout 120

    build_cache do
      s3_bucket "dockly-bucket-name"
      s3_object_prefix "bundle_cache/"
      hash_command "cd /app && ./script/bundle_hash"
      build_command "cd /app && ./script/bundle_package"
      output_dir "/app/vendor/bundle"
      use_latest true
    end

    build <<-EOF
      run cd /app && ./configure && make
    EOF
  end

  foreman do
    name 'dockly'
    procfile 'Procfile'
    log_dir '/data/logs'
  end

  s3_bucket 'dockly-bucket-name'
  # ends up in s3://#{s3_bucket}/#{package_name}/#{git_hash}/#{package_name}_#{version}.#{release}_#{arch}.deb
end
```

Copyright (c) 2013 Swipely, Inc. See LICENSE.txt for further details.
