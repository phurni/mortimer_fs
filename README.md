# mortimer_fs

This is a developer playground for experiments with file system implementation.
It is meant as a _real_ file system using a block device for persistance, thus
having a binary layout on the underlying device.

To ease those experiments I chose the ruby language so that it's [fun](https://maori.geek.nz/what-is-ruby-it-is-fun-and-makes-you-happy-337b6f10fa40)
and quick for features to be done.

Running the FS is done through [FUSE](https://github.com/libfuse/libfuse). Its installation is left to you.

It is licensed under the [MIT License](http://opensource.org/licenses/MIT), so feel free
to fork it and run your own experiments.

## Installation

The package is layed out as a ruby gem. Currently only available through the code repository.

Using a `Gemfile`:

```ruby
gem 'mortimer_fs', git: 'https://github.com/phurni/mortimer_fs'
```

## Documentation

You'll find exploration and implementation details in the `doc` directory.

## Extend the FS

Extensibility is baked in from the beginning.

You may add new way of handling _inodes_, _directory layouts_ or _allocation schemes_.

In order to do that, create a ruby project and add this gem in your Gemfile, then
provide code for your own implemenation.

For example, you made a new directory layout available in `my_dir_layout.rb`.

Run the FS:

    fuse_mortimer_fs --ext=./my_dir_layout.rb

Format a volume:

    mkmortimerfs --ext=./my_dir_layout.rb
