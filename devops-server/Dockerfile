# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# devops-server — Ubuntu 24.04 LTS tooling container
# Supports: Docker (linux/amd64, linux/arm64) and Apple container CLI
# ─────────────────────────────────────────────────────────────────────────────
FROM ubuntu:24.04

ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    PATH="/home/developer/.cargo/bin:$PATH"

# ── Labels ────────────────────────────────────────────────────────────────────
LABEL org.opencontainers.image.title="devops-server" \
      org.opencontainers.image.description="Ubuntu 24.04 server container with Tailscale, cloudflared, Aptove, GitHub CLI, Rust, Node.js, headless Chromium, UFW, Fail2ban, and unattended-upgrades" \
      org.opencontainers.image.source="https://github.com/openspec-agents/containers" \
      org.opencontainers.image.version="1.0.0"

# ── 1. Core system packages + security stack ──────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gnupg \
      lsb-release \
      wget \
      unzip \
      git \
      build-essential \
      software-properties-common \
      # DBus
      dbus \
      dbus-user-session \
      # Firewall
      ufw \
      iptables \
      # Brute-force protection
      fail2ban \
      # Auto security updates
      unattended-upgrades \
      apt-listchanges \
      # Misc utilities
      jq \
      iputils-ping \
      net-tools \
      procps \
      sudo \
  && rm -rf /var/lib/apt/lists/*

# ── 2. Tailscale ──────────────────────────────────────────────────────────────
RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg \
      | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null \
  && curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list \
      | tee /etc/apt/sources.list.d/tailscale.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends tailscale \
  && rm -rf /var/lib/apt/lists/*

# ── 3. GitHub CLI ─────────────────────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | tee /usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*

# ── 4. Node.js LTS (via NodeSource) ──────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

# ── 5. cloudflared (arch-aware binary from GitHub releases) ──────────────────
RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) CF_ARCH="amd64" ;; \
      arm64) CF_ARCH="arm64" ;; \
      *) echo "Unsupported arch: $TARGETARCH" && exit 1 ;; \
    esac; \
    LATEST=$(curl -fsSL https://api.github.com/repos/cloudflare/cloudflared/releases/latest \
              | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\(.*\)".*/\1/'); \
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/download/${LATEST}/cloudflared-linux-${CF_ARCH}" \
      -o /usr/local/bin/cloudflared \
  && chmod +x /usr/local/bin/cloudflared

# ── 6. Headless Chromium ──────────────────────────────────────────────────────
# chromium-browser on Ubuntu 24.04 is a snap stub — use ppa:xtradeb/apps
# which ships a real .deb for both amd64 and arm64.
RUN add-apt-repository ppa:xtradeb/apps -y \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
      chromium \
      fonts-liberation \
      libatk-bridge2.0-0 \
      libgtk-3-0 \
      libnss3 \
      libxss1 \
      libxtst6 \
  && rm -rf /var/lib/apt/lists/*

# ── 7. unattended-upgrades configuration ─────────────────────────────────────
RUN printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' \
      > /etc/apt/apt.conf.d/20auto-upgrades \
  && printf 'Unattended-Upgrade::Allowed-Origins {\n  "Ubuntu:24.04";\n  "Ubuntu:noble-security";\n};\nUnattended-Upgrade::AutoFixInterruptedDpkg "true";\nUnattended-Upgrade::MinimalSteps "true";\n' \
      > /etc/apt/apt.conf.d/50unattended-upgrades-devops

# ── 8. UFW pre-configuration ──────────────────────────────────────────────────
# Rules are stored but not enabled at build time — entrypoint enables UFW.
RUN ufw --force reset \
  && ufw default deny incoming \
  && ufw default allow outgoing \
  && ufw allow 22/tcp comment 'SSH' \
  && ufw allow 41641/udp comment 'Tailscale WireGuard'

# ── 9. Fail2ban configuration ────────────────────────────────────────────────
RUN printf '[DEFAULT]\nbantime  = 1h\nfindtime = 10m\nmaxretry = 5\n\n[sshd]\nenabled = true\n' \
      > /etc/fail2ban/jail.local

# ── 10. Non-root developer user ───────────────────────────────────────────────
RUN useradd -m -s /bin/bash developer \
  && echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/developer \
  && chmod 0440 /etc/sudoers.d/developer

# ── 11. Rust (installed as developer user) ────────────────────────────────────
USER developer
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --no-modify-path \
  && /home/developer/.cargo/bin/rustup component add clippy rustfmt

USER root

# ── 12. Aptove (global npm install, requires nodejs already present) ──────────
RUN npm install -g @aptove/aptove

# ── 13. Entrypoint script ─────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ── 14. Final setup ───────────────────────────────────────────────────────────
WORKDIR /workspace
RUN chown developer:developer /workspace

USER developer

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
