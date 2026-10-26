# node-exporter-smartmon
Text collector script for smartmon

## Usage

```bash
$ docker run --rm --name node-exporter-smartmon \
    --privileged \
    yuanying/node-exporter-smartmon:latest \
    2>&1 > /var/lib/node-exporter/smartmon.prom.tmp && \
    mv /var/lib/node-exporter/smartmon.prom.tmp /var/lib/node-exporter/smartmon.prom
```

## Disks behind a USB bridge

`smartctl --scan-open` leaves out the disks behind a USB bridge it does
not know. The script also reads every disk under `/sys/block` that is
attached through USB, has a medium, and is not in `--scan-open`, with
the first type in `SMARTMON_USB_TYPES` the disk answers to
(`smartctl -n standby -i -d <type>`). A spun down disk is not woken up.

| Variable | Default | |
|---|---|---|
| `SMARTMON_USB_TYPES` | `sat` | Types to try, separated by spaces, e.g. `sat sat,12`. `sat`, `sat,*` and `usb*` are read as ATA. Set it empty to read no disk `--scan-open` does not list |

## Tests

```bash
$ test/smartmon_test.sh
```

The test runs the script with `test/fake-smartctl`, which prints the
smartctl outputs in `test/cases`, and compares what it prints with
`test/expected`. `UPDATE_EXPECTED=1` rewrites `test/expected`.

## Example systemd units

### node-exporter-smartmon.service

```
[Unit]
Description=Collect smart data to /var/lib/node-exporter
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStartPre=-/usr/bin/docker stop node-exporter-smartmon
ExecStartPre=-/usr/bin/docker rm node-exporter-smartmon
ExecStartPre=/usr/bin/docker pull yuanying/node-exporter-smartmon:latest
ExecStart=/bin/sh -c 'mkdir -p /var/lib/node-exporter && \
    /usr/bin/docker run --rm --name node-exporter-smartmon \
    --privileged \
    yuanying/node-exporter-smartmon:latest \
    2>&1 > /var/lib/node-exporter/smartmon.prom.tmp && \
    mv /var/lib/node-exporter/smartmon.prom.tmp /var/lib/node-exporter/smartmon.prom'

[Install]
WantedBy=multi-user.target
```

### node-exporter-smartmon.timer

```
[Unit]
Description=Run node-exporter-smartmon service every 10 minutes

[Timer]
OnCalendar=*:0/10

[Install]
WantedBy=timers.target
```
