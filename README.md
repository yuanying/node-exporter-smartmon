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
