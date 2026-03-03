# devops-server container

A security-hardened Ubuntu 24.04 LTS container with a complete devops toolchain pre-installed.
Works with **Docker** (linux/amd64 + linux/arm64) and **Apple's native `container` CLI** (Apple Silicon).

## What's included

| Tool | Description |
|------|-------------|
| [Tailscale CLI](https://tailscale.com) | Mesh VPN — `tailscale`, `tailscaled` |
| [cloudflared](https://github.com/cloudflare/cloudflared) | Cloudflare Zero Trust tunnels |
| [Aptove](https://www.npmjs.com/package/@aptove/aptove) | Package automation CLI |
| [GitHub CLI](https://cli.github.com) | `gh` — GitHub from the terminal |
| [Rust](https://www.rust-lang.org) | `rustc`, `cargo`, `rustfmt`, `clippy` (stable) |
| [Node.js LTS](https://nodejs.org) | Latest LTS + npm |
| [Chromium](https://www.chromium.org) | Headless browser automation |
| [UFW](https://help.ubuntu.com/community/UFW) | Firewall — default deny inbound |
| [Fail2ban](https://www.fail2ban.org) | SSH brute-force protection |
| [unattended-upgrades](https://wiki.debian.org/UnattendedUpgrades) | Automatic security patches |
| DBus | System bus available at container start |

---

## Quick start

```bash
# 1. Clone or copy the container files
cd containers/devops-server

# 2. Run interactively (one command, prefers Apple container CLI, falls back to Docker)
./run.sh

# 3. With a host folder mounted to /workspace
HOST_SHARE_PATH=/path/to/project ./run.sh
```

---

## Docker usage

### Basic interactive shell

```bash
docker run --rm -it \
  --cap-add=NET_ADMIN \
  --device /dev/net/tun \
  ghcr.io/aptove/devops-server:latest
```

### With host folder sharing

```bash
docker run --rm -it \
  --cap-add=NET_ADMIN \
  --device /dev/net/tun \
  -v /path/to/project:/workspace \
  ghcr.io/aptove/devops-server:latest
```

> **Note:** `--cap-add=NET_ADMIN` and `--device /dev/net/tun` are required for both Tailscale (tun interface) and UFW (iptables rule management).

---

## Apple container CLI usage

```bash
# Basic
container run --rm -it \
  --cap-add=NET_ADMIN \
  ghcr.io/aptove/devops-server:latest

# With host folder sharing
container run --rm -it \
  --cap-add=NET_ADMIN \
  -v /path/to/project:/workspace \
  ghcr.io/aptove/devops-server:latest
```

> Apple's virtualised network handles tun devices natively; `--device /dev/net/tun` is not required.

---

## Tool usage

### Tailscale

Tailscale binaries are available but the daemon is not started automatically.
Start it manually inside the container:

```bash
# Start daemon in background
sudo tailscaled &

# Authenticate (interactive browser auth or auth key)
sudo tailscale up

# Or with an auth key
sudo tailscale up --authkey=tskey-...

# Check status
tailscale status
```

### Cloudflare Zero Trust (cloudflared)

```bash
# Run a named tunnel
cloudflared tunnel run --token <TUNNEL_TOKEN>

# Expose a local service via a quick tunnel (no account needed)
cloudflared tunnel --url http://localhost:3000

# Access a Cloudflare Access-protected URL
cloudflared access curl --url https://protected.example.com
```

Cloudflared uses **outbound** connections only — UFW's `allow outgoing` rule covers this with no extra configuration.

### Headless Chromium

```bash
# Dump DOM of a page
chromium-browser --headless --no-sandbox --dump-dom https://example.com

# Take a screenshot
chromium-browser --headless --no-sandbox --screenshot=/workspace/shot.png https://example.com

# Print to PDF
chromium-browser --headless --no-sandbox --print-to-pdf=/workspace/page.pdf https://example.com
```

> `--no-sandbox` is required when running as a non-root user inside a container.

### GitHub CLI

```bash
# Authenticate with a Personal Access Token
echo "$GITHUB_TOKEN" | gh auth login --with-token

# Check authentication status
gh auth status

# Clone a repo
gh repo clone owner/repo
```

### Rust

```bash
# Compiler and toolchain
rustc --version
cargo --version

# Create and build a new project
cargo new hello-world
cd hello-world && cargo build

# Run clippy
cargo clippy
```

### Node.js / npm / Aptove

```bash
node --version
npm --version

# Install packages globally
npm install -g <package>

# Aptove
aptove --version
```

---

## Security stack

### UFW firewall

UFW is pre-configured and **enabled at container start** by the entrypoint script.

Default policy:
- Inbound: **deny** (default)
- Outbound: **allow** (default)
- Allowed inbound ports: `22/tcp` (SSH), `41641/udp` (Tailscale WireGuard)

```bash
# Check status
sudo ufw status verbose

# Allow an additional port at runtime
sudo ufw allow 8080/tcp

# Remove a rule
sudo ufw delete allow 8080/tcp
```

### Fail2ban

Fail2ban starts automatically and monitors SSH authentication failures.

Default SSH jail configuration:
- `maxretry = 5` — ban after 5 failed attempts
- `bantime = 1h` — ban duration
- `findtime = 10m` — window to count failures

```bash
# Check jail status
sudo fail2ban-client status

# Check SSH jail specifically
sudo fail2ban-client status sshd

# Unban an IP
sudo fail2ban-client set sshd unbanip <IP>
```

### Automatic security updates

`unattended-upgrades` is configured to apply Ubuntu security patches automatically.

```bash
# Dry-run to preview what would be upgraded
sudo unattended-upgrades --dry-run --debug

# View upgrade history
cat /var/log/unattended-upgrades/unattended-upgrades.log
```

### DBus

The DBus system bus is started by the entrypoint and available at `/run/dbus/system_bus_socket`.

```bash
# Verify DBus is running
dbus-send --system --print-reply \
  --dest=org.freedesktop.DBus / \
  org.freedesktop.DBus.Introspectable.Introspect
```

---

## Host folder sharing

Set `HOST_SHARE_PATH` to any directory on your host machine:

```bash
HOST_SHARE_PATH=/Users/yourname/projects/my-app ./run.sh
```

Inside the container, the folder appears at `/workspace`. Files created or modified there persist on the host.

---

## Building locally

```bash
# amd64
docker build --platform linux/amd64 -t devops-server:local .

# arm64
docker build --platform linux/arm64 -t devops-server:local .

# Multi-arch (requires buildx)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t devops-server:local \
  --load .
```

---

## Image registry

Published automatically via GitHub Actions when a semver tag is pushed. Tests run on every commit; the image is only built and pushed on a release tag.

**To release a new version:**
```bash
git tag 0.1.0
git push origin 0.1.0
```

This produces two tags on GHCR: `latest` and the version number (e.g. `0.1.0`).

```bash
docker pull ghcr.io/aptove/devops-server:latest
docker pull ghcr.io/aptove/devops-server:0.1.0
```
