# puppet-victorialogs

Puppet module to install and manage [VictoriaLogs](https://victoriametrics.com/products/victorialogs/) and [vlagent](https://docs.victoriametrics.com/victorialogs/vlagent/).

## Table of Contents

1. [Description](#description)
1. [Usage](#usage)
1. [Bolt plans and tasks](#bolt-plans-and-tasks)
1. [Reference](#reference)
1. [Limitations](#limitations)

## Description

Manages the full VictoriaLogs lifecycle: system user/group, binary installation (archive or package), and systemd service management. Supports single-node deployments, multi-instance configurations for cluster roles, and the vlagent log collector.

Bolt tasks and plans provide orchestration on top of the Puppet catalog: automatic latest-version resolution, ordered cluster bootstrapping, and rolling upgrades with per-node health checks.

## Usage

### Single-node VictoriaLogs (specific version)

```puppet
class { 'victorialogs':
  version => '1.49.0',
}
```

### Via Hiera

```puppet
# site.pp
include victorialogs
```

```yaml
# hiera data
victorialogs::version: '1.49.0'
```

### Cluster insert node

```puppet
class { 'victorialogs':
  version   => '1.49.0',
  instances => {
    insert => {
      options => {
        common => {
          '-storageNode'    => 'vlstorage-01:9428,vlstorage-02:9428',
          '-select.disable' => true,
        },
      },
    },
  },
}
```

### With multiple syslog inputs

```puppet
class { 'victorialogs':
  version   => '1.49.0',
  instances => {
    single => {
      options => {
        common  => { '-storageDataPath' => '/var/lib/victorialogs/data' },
        syslog1 => {
          '-syslog.listenAddr.tcp' => ':514',
          '-syslog.tenantID.tcp'   => '0:0',
        },
        syslog2 => {
          '-syslog.listenAddr.tcp' => ':6514',
          '-syslog.tenantID.tcp'   => '1:0',
          '-syslog.tls'            => true,
          '-syslog.tlsCertFile'    => '/etc/ssl/vl.crt',
          '-syslog.tlsKeyFile'     => '/etc/ssl/vl.key',
        },
      },
    },
  },
}
```

### vlagent

```puppet
class { 'victorialogs::vlagent':
  version      => '1.49.0',
  service_args => {
    '-remoteWrite.url' => 'http://vlinsert-01:9428/insert/jsonline',
  },
}
```

## Bolt plans and tasks

### Deploy (single-node)

Resolves the latest version automatically when `version` is omitted:

```shell
# Latest version
bolt plan run victorialogs::deploy --targets vlnode-01

# Pinned version
bolt plan run victorialogs::deploy --targets vlnode-01 version=1.49.0
```

### Cluster bootstrap

```shell
bolt plan run victorialogs::cluster \
  storage_targets=vlstorage-01,vlstorage-02 \
  insert_targets=vlinsert-01 \
  select_targets=vlselect-01 \
  version=1.49.0
```

### Rolling upgrade

Upgrades one node at a time; halts if a node is unhealthy after upgrade:

```shell
bolt plan run victorialogs::upgrade --targets vlnodes version=1.50.0
```

### Individual tasks

```shell
# Latest available version
bolt task run victorialogs::latest_version --targets localhost

# Installed version on a target
bolt task run victorialogs::installed_version --targets vlnode-01

# Health check
bolt task run victorialogs::status --targets vlnode-01 service_name=victorialogs-single port=9428
```

## Reference

See [REFERENCE.md](REFERENCE.md) (generated via `rake reference`).

## Limitations

- `version: undef` with `install_method: archive` fails at catalog apply time. Use the `victorialogs::deploy` Bolt plan to resolve the latest version automatically.
- Cluster deployments require the `victorialogs::cluster` Bolt plan; Puppet-only ordering across multiple nodes is not supported.
- `install_method: package` requires a pre-configured package repository; this module does not manage yum/apt repos.

## Authors

Maintained by [Vox Pupuli](https://voxpupuli.org).
