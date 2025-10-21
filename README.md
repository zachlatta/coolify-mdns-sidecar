# mDNS alias sidecar

Do you have Coolify apps you want to deploy locally to your network? For example, I have a server at `rotom.local`. I want to host Immich at `immich.rotom.local` on Coolify. But I don't want to manually edit Avahi config on the host machine!

This is a little Coolify utility that lets you set up arbitrary Avahi domains that resolve to another Avahi domain (must have Avahi on host).

For example, you can set up `immich.rotom.local` to resolve to the IP of `rotom.local`.

## Files
- `docker-compose.yml` – runs the sidecar
- `Dockerfile.mdns` – builds a tiny image with `avahi-utils`
- `publish-mdns-aliases.sh` – resolves `BASE_HOST` and publishes aliases

## Requirements
- Avahi (Bonjour) running on the **host** so the `BASE_HOST` name resolves:
  ```bash
  sudo apt-get install -y avahi-daemon avahi-utils libnss-mdns
  sudo systemctl enable --now avahi-daemon
  ```
- Host networking is used so mDNS can operate: `network_mode: host`
- Container needs the `NET_RAW` capability (added in the compose file).

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
- When deployed through Coolify, update `BASE_HOST` and `ALIASES` from the stack's Environment tab; both variables appear automatically thanks to the compose file references.
- The sidecar auto-selects a non-Docker IPv4 for `BASE_HOST`, so aliases follow the same LAN IP announced by Avahi.

The container now runs its own `dbus-daemon` and `avahi-daemon`, so no host D-Bus mounts are required.

## Coolify
Set your app domain to `immich.rotom.local` and **disable Let's Encrypt** (no public DNS). Deploy.
