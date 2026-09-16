# Changelog

## v0.6.0

* Added the `:silently_accept_hosts` and `:save_accepted_host` options to the `Dicon.SecureShell` executor
* Dropped support for Elixir versions before 1.12

## v0.5.0

### Breaking changes

* Moved configuration of hosts under each host in the `:dicon` configuration; the `:hosts` configuration option is now a list of host names (as atoms)
* Dropped support for Elixir versions before 1.3

### Improvements and bug fixes

* Added support for host-specific OS environment when executing commands on the remote host in `dicon.control`
* Fixed Elixir 1.4 warnings
* Made `--only`/`--skip` fail when any of the listed hosts don't exist in the configuration
* Print feedback when connecting to hosts and print commands executed by the executor
* Added the `:connect_timeout`, `:exec_timeout`, and `:write_timeout` options to the `Dicon.SecureShell` executor
* Changed progress bar to spinner in `mix dicon.deploy`
* Merge custom application environment with the contents of `sys.config`
* Improved transferring speed by not using SFTP
