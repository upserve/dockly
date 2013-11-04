Slugger
=======

`Slugger` is a gem made to ease the pain of packaging an application. For this gem to be useful, quite a few assumptions can be made about your stack:

- You use AWS
- You're deploying to a Debian-based system
- You want to use [Docker](http://docker.io) for process isolation

Although only a specific type of repository may be used, these assumptions allow us to define a simple DSL to describe your repository.

The DSL
-------

The DSL is broken down into multiple objects, all of which conform to a specific format. Each object starts with the name of the section,
followed by a name for the object you're creating, and a block for configuration.

```ruby
docker :test_docker do
  # code here
end
```

Each object has an enumeration of valid attributes. The following code sets the `repo` attribute in a `docker` called `test_docker`:

```ruby
docker :test_docker do
  repo 'an-awesome-repo'
end
```

Finally, each object has zero or more valid references to other DSL objects. The following code sets `deb` that references a `docker`:

```ruby
docker :my_docker do
  repo 'my-repo'
end

deb :my_deb do
  docker :my_docker
end
```

Below is an alternative syntax that accomplishes the same thing:

```ruby
deb :my_deb do
  docker do
    repo 'my-repo'
  end
end
```

`docker`
--------

The `docker` DSL is used to define Docker containers. It has the following attributes:

- `import`
    - required: `true`
    - default: `nil`
    - description: the location (url or S3 path) of the base image to start building from
- `git_archive`:
    - required: `false`
    - default: `nil`
    - description: the relative file path of git repo that should be added to the container
- `build`
    - required: `true`
    - default: `nil`
    - description: aditional Dockerfile commands that you'd like to pass to `docker build`
- `repo`
    - required: `true`
    - default: `'slugger'`
    - description: the repository of the created image
- `tag`
    - required: `true`
    - default: `nil`
    - description: the tag of the created image
- `build_dir`
    - required: `true`
    - default: `./build/docker`
    - description: the directory of the temporary build files
- `package_dir`
    - required: `true`
    - default: `/opt/docker`
    - description: the location of the created image in the Debian package
- `timeout`
    - required: `true`
    - default: `60`
    - description: the excon timeout for read and write when talking to docker through docker-api
- `build_caches`
    - required: `false`
    - default: `[]`
    - description: a listing of references to build caches to run

`foreman`
---------
    
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
    - description: the location of the startup scripts in the Debian package
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
    - default: `nil`
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

In addition to the above attributes, `deb` has the following references:

- `docker`
    - required: `false`
    - default: `nil`
    - class: `Slugger::Docker`
    - description: configuration for an image packaged with the deb
- `foreman`
    - required: `false`
    - default: `nil`
    - class: `Slugger::Foreman`
    - description: any Foreman scripts used in the deb


Demo
===

```ruby
deb :slugger_package do
  package_name 'slugger_package'
  version '1.0'
  release '1'

  docker do
    name :slugger_docker
    tag 'slugger_docker'
    import 's3://slugger-bucket-name/base-image.tar.gz'
    git_archive '/app'
    timeout 120

    build_cache do
      s3_bucket "slugger-bucket-name"
      s3_object_prefix "bundle_cache/"
      hash_command "cd /app && ./script/bundle_hash"
      build_command "cd /app && ./script/bundle_package"
      output_dir "/app/vendor/bundle"
      use_latest true
    end

    build <<-EOF
      run cd /app && echo "1.0-1" > VERSION && echo "#{Slugger.git_sha}" >> VERSION
    EOF
    # git_sha is available from Slugger
  end

  foreman do
    name 'slugger'
    procfile 'Procfile'
    prefix 'source /etc/slugger_env '
    log_dir '/data/logs'
    user 'ubuntu'
  end

  post_install <<-EOF
    zcat /opt/docker/#{build_path} | docker import - swipely latest
  EOF

  s3_bucket 'slugger-bucket-name'
  # ends up in s3://#{s3_bucket}/#{package_name}/#{git_hash}/#{package_name}_#{version}.#{release}_#{arch}.deb
end
```

Copyright (c) 2013 Swipely, Inc. See LICENSE.txt for further details.
