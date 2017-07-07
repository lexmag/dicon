# Changelog

## v0.5.0

### Breaking changes

* Move configuration of hosts under each host in the `:dicon` configuration, and make the `:hosts` configuration option be a list of host names (as atoms).
* Require Elixir `~> 1.3`.

### Improvements and bug fixes

* Add support for host-specific OS environment when executing commands on the remote host in `dicon.control`.
* Fix Elixir 1.4 warnings.
* Make `--only`/`--skip` fail when any of the listed hosts don't exist in the configuration.
* Print feedback when connecting to hosts and print commands executed by the executor.
* Add the `:connect_timeout`, `:exec_timeout`, and `:write_timeout` options to the `Dicon.SecureShell` executor.
* Change progress bar to spinner in `mix dicon.deploy`.
* Merge custom application environment with the contents of `sys.config`.
* Improve transferring speed by not using SFTP.
