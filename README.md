# mDNS alias sidecar

Do you have Coolify apps you want to deploy locally to your network? For example, I have a server at `rotom.local`. I want to host Immich at `immich.rotom.local` on Coolify. But I don't want to manually edit Avahi config on the host machine!

This is a little Coolify utility that lets you set up arbitrary Avahi domains that resolve to another Avahi domain (must have Avahi on host).

For example, you can set up `immich.rotom.local` to resolve to the IP of `rotom.local`.

## Files
- `docker-compose.yml` – runs the sidecar
- `Dockerfile.mdns` – builds a tiny image with `avahi-utils`
- `publish-mdns-aliases.sh` – resolves `BASE_HOST` and publishes aliases

## Requirements
- Avahi (Bonjour) running on the **host**
  ```bash
  sudo apt-get install -y avahi-daemon avahi-utils libnss-mdns
  sudo systemctl enable --now avahi-daemon
  ```
- Host must allow the container to talk to D-Bus:
  - The compose file mounts `/var/run/dbus` read-only.
- Host networking is used so mDNS can operate: `network_mode: host`

## Use
```bash
docker compose up -d --build
# verify from any LAN client:
avahi-resolve -n immich.rotom.local
```

### Customize
- Change `BASE_HOST` (default `rotom.local`).
- Add more aliases (comma-separated) in `ALIASES`, e.g.:
  ```yaml
  ALIASES: immich.rotom.local,api.rotom.local,ui.rotom.local
  ```

## Coolify
Set your app domain to `immich.rotom.local` and **disable Let's Encrypt** (no public DNS). Deploy.
