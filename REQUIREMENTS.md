# puppet-victorialogs Requirements

Implementation reference: [VictoriaMetrics ansible-playbooks](https://github.com/VictoriaMetrics/ansible-playbooks)
Style guide: [Puppet BGTM](https://www.puppet.com/docs/puppet/7/bgtm.html)

---

## Module scope

Covers the VictoriaLogs stack only:

- **vlsingle** — single-node (and cluster-node) VictoriaLogs installation and service management
- **vlagent** — log collector/forwarder agent
- **Bolt tasks** — operational primitives: version resolution, health check
- **Bolt plans** — orchestration: single-node deploy, cluster bootstrap, rolling upgrade

Out of scope: vmsingle, vmcluster, vmagent, vmauth, VictoriaTraces.

---

## BGTM compliance requirements

- The main class `victorialogs` in `init.pp` is the **only parameterised class**
- All subordinate classes are private (`assert_private()`) with no parameters of their own; they read from the parent class scope
- The main class uses `contain` for all subordinate classes and declares explicit ordering with `->` and `~>`
- Resources (user, group, home directory) are delegated to sub-classes, not declared in `init.pp`
- File naming matches class/define names exactly
- `REFERENCE.md` is generated via `puppet strings generate --format markdown` and committed

---

## Module structure

```
manifests/
  init.pp              # class victorialogs          — main class, parameters only, contains sub-classes
  user.pp              # class victorialogs::user     — user, group, homedir resources (private)
  install.pp           # class victorialogs::install  — binary installation (private)
  instance.pp          # define victorialogs::instance — systemd unit per instance

  vlagent/
    init.pp            # class victorialogs::vlagent        — vlagent main class
    user.pp            # class victorialogs::vlagent::user  — vlagent user/group (private)
    install.pp         # class victorialogs::vlagent::install — vlagent binary (private)
    service.pp         # class victorialogs::vlagent::service — vlagent systemd unit (private)

types/
  options.pp           # Victorialogs::Options
  instancetype.pp      # Victorialogs::InstanceType

functions/
  github_download_url.pp  # Victorialogs::github_download_url

templates/
  instance.service.epp    # systemd unit for victorialogs::instance
  vlagent.service.epp     # systemd unit for victorialogs::vlagent

plans/
  deploy.pp            # single-node deploy (resolve latest → apply → smoke test)
  cluster.pp           # ordered multi-node cluster bootstrap
  upgrade.pp           # rolling upgrade with per-node health check

tasks/
  latest_version.sh    # query GitHub API for latest release tag
  latest_version.json  # task metadata
  installed_version.sh # run binary --version on target
  installed_version.json
  status.sh            # systemctl status + HTTP /-/ready check
  status.json
```

---

## `victorialogs` main class parameters

| Parameter | Type | Default | Notes |
|-----------|------|---------|-------|
| `ensure` | `Enum['present','absent']` | `'present'` | |
| `edition` | `Enum['oss','enterprise']` | `'oss'` | |
| `install_method` | `Enum['archive','package','none']` | `'archive'` | |
| `version` | `Optional[String[1]]` | `undef` | Required for `archive`; `undef` = resolve latest in a Bolt plan |
| `download_url` | `Stdlib::HTTPUrl` | computed | Defaults to `github_download_url(...)` |
| `checksum_url` | `Stdlib::HTTPUrl` | computed | Defaults to `github_download_url(...)` checksum variant |
| `package_name` | `String[1]` | `'victorialogs'` | |
| `manage_user` | `Boolean` | `true` | |
| `user` | `String[1]` | `'victorialogs'` | |
| `group` | `String[1]` | `'victorialogs'` | |
| `shell` | `String[1]` | `'/usr/sbin/nologin'` | |
| `manage_group` | `Boolean` | `true` | |
| `manage_homedir` | `Boolean` | `true` | |
| `homedir` | `Stdlib::Absolutepath` | `'/var/lib/victorialogs'` | |
| `homedir_mode` | `Stdlib::Filemode` | `'0750'` | |
| `homedir_owner` | `String[1]` | `$user` | |
| `homedir_group` | `String[1]` | `$group` | |
| `install_dir` | `Stdlib::Absolutepath` | `"/opt/victorialogs-${version}-${edition}"` | archive only |
| `archive_binary` | `Stdlib::Absolutepath` | `'/usr/local/bin/victoria-logs-prod'` | symlink target for archive install |
| `package_binary` | `Stdlib::Absolutepath` | `'/usr/bin/victoria-logs-prod'` | package install binary path |
| `tmp_dir` | `Stdlib::Absolutepath` | `'/tmp'` | staging dir for archive download |
| `enterprise_license_key` | `Optional[String[1]]` | `undef` | passed as `-license` flag |
| `enterprise_license_key_file` | `Optional[Stdlib::Absolutepath]` | `undef` | passed as `-licenseFile` flag |
| `instances` | `Hash[String[1], Victorialogs::InstanceType]` | see below | |

Default `instances` value:
```puppet
{
  single => {
    options => {
      common => {
        '-storageDataPath' => '/var/lib/victorialogs/victoria-logs-data',
      },
    },
  },
}
```

### Class ordering in `init.pp`

```puppet
contain victorialogs::user
contain victorialogs::install

Class['victorialogs::user'] -> Class['victorialogs::install']

$instances.each |$name, $attrs| {
  victorialogs::instance { $name:
    require => Class['victorialogs::install'],
    * => $attrs,
  }
}
```

---

## `victorialogs::instance` defined type parameters

| Parameter | Type | Default | Notes |
|-----------|------|---------|-------|
| `ensure` | `Enum['present','absent']` | `'present'` | |
| `service_name` | `String[1]` | `"victorialogs-${title}"` | |
| `service_active` | `Boolean` | `true` | |
| `service_enable` | `Variant[Boolean, Enum['mask']]` | `true` | |
| `user` | `String[1]` | `$victorialogs::user` | |
| `group` | `String[1]` | `$victorialogs::group` | |
| `binary_path` | `Stdlib::Absolutepath` | `$victorialogs::binary_path` | set by install class |
| `options` | `Hash[String[1], Victorialogs::Options]` | `{}` | named flag groups |
| `limit_nofile` | `Integer` | `2097152` | systemd LimitNOFILE |

---

## `victorialogs::vlagent` main class parameters

| Parameter | Type | Default | Notes |
|-----------|------|---------|-------|
| `ensure` | `Enum['present','absent']` | `'present'` | |
| `edition` | `Enum['oss','enterprise']` | `'oss'` | |
| `install_method` | `Enum['archive','package','none']` | `'archive'` | |
| `version` | `Optional[String[1]]` | `undef` | |
| `download_url` | `Stdlib::HTTPUrl` | computed | |
| `checksum_url` | `Stdlib::HTTPUrl` | computed | |
| `package_name` | `String[1]` | `'vlagent'` | |
| `manage_user` | `Boolean` | `true` | |
| `user` | `String[1]` | `'vlagent'` | |
| `group` | `String[1]` | `'vlagent'` | |
| `manage_group` | `Boolean` | `true` | |
| `service_args` | `Hash[String[1], Variant[String, Integer, Boolean]]` | `{}` | flat key→value CLI flags |
| `service_active` | `Boolean` | `true` | |
| `service_enable` | `Variant[Boolean, Enum['mask']]` | `true` | |
| `limit_nofile` | `Integer` | `2097152` | |
| `enterprise_license_key` | `Optional[String[1]]` | `undef` | |
| `enterprise_license_key_file` | `Optional[Stdlib::Absolutepath]` | `undef` | |

Note: vlagent uses a flat `service_args` hash (not the grouped `options` pattern of `victorialogs::instance`) because it runs as a single service with no multi-instance use case.

---

## `victorialogs::github_download_url` function

Fix argument order and add OS architecture mapping.

**Signature:**
```puppet
function victorialogs::github_download_url(
  Optional[String[1]] $version,
  Enum['oss', 'enterprise'] $edition,
  Enum['archive', 'checksum'] $download_type,
  Enum['victorialogs', 'vlagent'] $component = 'victorialogs',
) >> String[1]
```

**Architecture mapping** (OS fact → Go arch):

| `$facts['os']['architecture']` | URL arch |
|-------------------------------|----------|
| `x86_64` | `amd64` |
| `amd64` | `amd64` |
| `aarch64` | `arm64` |
| `arm64` | `arm64` |
| `armv7l` | `arm` |
| `i386` | `386` |
| `i686` | `386` |

Fail with a clear message for unrecognised architectures.

**Binary names by component:**

| Component | Binary |
|-----------|--------|
| `victorialogs` | `victoria-logs-prod` |
| `vlagent` | `vlagent-prod` |

---

## Type aliases

### `Victorialogs::Options`
```puppet
type Victorialogs::Options = Hash[String[1], Variant[String, Integer, Boolean]]
```

### `Victorialogs::InstanceType`
```puppet
type Victorialogs::InstanceType = Struct[{
  Optional[ensure]         => Enum['absent', 'present'],
  Optional[service_active] => Boolean,
  Optional[service_enable] => Variant[Boolean, Enum['mask']],
  Optional[options]        => Hash[String[1], Victorialogs::Options],
  Optional[limit_nofile]   => Integer,
}]
```

---

## Systemd unit template requirements (`instance.service.epp`)

Must include security hardening directives from the Ansible reference:

```ini
[Unit]
Description=VictoriaLogs <%= $service_name %>
After=network.target

[Service]
Type=simple
User=<%= $user %>
Group=<%= $group %>
ExecStart=<%= $binary_path %> \
  <%= $args.join(" \\\n  ") %>
Restart=always
LimitNOFILE=<%= $limit_nofile %>
PrivateTmp=yes
ProtectHome=yes
NoNewPrivileges=yes
ProtectSystem=full
SyslogIdentifier=<%= $service_name %>

[Install]
WantedBy=multi-user.target
```

Conditionally add `ProtectControlGroups`, `ProtectKernelModules`, `ProtectKernelTunables` when systemd >= 232 (check via `$facts['systemd_version']` if available, otherwise omit and accept the gap).

---

## Bolt tasks

### `victorialogs::latest_version`
- Platform: shell
- Queries the GitHub releases API for VictoriaMetrics/VictoriaLogs and returns the latest tag
- Return type: `{ version => String[1] }`
- Does not require the module to be applied; safe to run on the Bolt controller with `run_task('victorialogs::latest_version', 'localhost')`

### `victorialogs::installed_version`
- Platform: shell
- Runs `victoria-logs-prod --version` (or `vlagent-prod --version` via a `component` parameter)
- Returns `{ version => Optional[String] }` — `undef` if binary not found
- Parameter: `component` — `Enum['victorialogs', 'vlagent']`, default `'victorialogs'`

### `victorialogs::status`
- Platform: shell
- Checks `systemctl is-active <service_name>` and `curl -sf http://localhost:<port>/-/ready`
- Parameters: `service_name String[1]`, `port Integer`, default port `9428`
- Returns `{ active => Boolean, ready => Boolean, message => String }`

---

## Bolt plans

### `victorialogs::deploy`
Single-node deploy with automatic latest-version resolution.

```
Parameters:
  targets        TargetSpec
  version        Optional[String[1]]  -- undef = resolve latest via task
  instance_name  String[1]            -- default 'single'
  options        Hash                 -- merged into instances hash

Steps:
  1. If version is undef, run victorialogs::latest_version on localhost
  2. apply($targets) { class { 'victorialogs': version => $real_version, ... } }
  3. run_task('victorialogs::status', $targets)
  4. Return status results
```

### `victorialogs::cluster`
Ordered cluster bootstrap: storage → insert → select.

```
Parameters:
  storage_targets   TargetSpec
  insert_targets    TargetSpec
  select_targets    TargetSpec
  version           String[1]
  storage_port      Integer  -- default 9428

Steps:
  1. apply($storage_targets) { class { 'victorialogs': ... } }
  2. run_task('victorialogs::status', $storage_targets)  -- fail fast if unhealthy
  3. Compute $storage_addrs from target hostnames + $storage_port
  4. apply($insert_targets) with storageNode flag and select.disable=true
  5. apply($select_targets) with storageNode flag and insert.disable=true
  6. run_task('victorialogs::status', all targets)
```

### `victorialogs::upgrade`
Rolling upgrade with per-node health check before advancing.

```
Parameters:
  targets    TargetSpec
  version    String[1]

Steps:
  For each target (sequentially):
    1. run_task('victorialogs::installed_version', $target)
    2. Skip if already at $version
    3. apply($target) { class { 'victorialogs': version => $version } }
    4. run_task('victorialogs::status', $target)
    5. Fail the plan if status is unhealthy (do not advance to next node)
```

---

## metadata.json requirements

- `name`: `voxpupuli-victorialogs`
- `author`: `Vox Pupuli`
- `license`: `Apache-2.0`
- Dependencies:
  - `puppetlabs/stdlib` `>= 9.0.0 < 10.0.0`
  - `puppet/archive` `>= 8.0.0 < 9.0.0`
  - `puppet/systemd` `>= 8.0.0 < 9.0.0`
- `requirements`: `openvox >= 8.0.0 < 9.0.0`

---

## Testing requirements

- `rspec-puppet` unit tests for all classes and defined types
- Test matrix covers at minimum: Debian 12, Ubuntu 22.04, AlmaLinux 9
- `spec/classes/init_spec.rb` — main class with default params and key overrides
- `spec/classes/vlagent/init_spec.rb` — vlagent main class
- `spec/defines/instance_spec.rb` — instance defined type
- `spec/functions/github_download_url_spec.rb` — arch mapping, argument order, component names
- Acceptance tests via litmus (placeholder spec files acceptable at v0.1.0)

---

## Known limitations (document in README)

- `version: undef` with `install_method: archive` will fail at catalog apply time; use the `victorialogs::deploy` Bolt plan to resolve latest automatically
- Cluster deployments require the `victorialogs::cluster` Bolt plan; Puppet-only cluster node ordering is not supported
- `install_method: package` requires a pre-configured package repository; the module does not manage yum/apt repos
- systemd >= 232 hardening directives (`ProtectControlGroups`, etc.) are not conditionally applied; they are omitted from the template to maintain broad compatibility
