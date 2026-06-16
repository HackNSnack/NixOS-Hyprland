# modules/services/nanoclaw.nix
#
# NanoClaw personal AI assistant — system-level NixOS module.
#
# This module replaces what `pnpm run setup:auto` (nanoclaw's setup/service.ts)
# would generate on a conventional Linux distro.  On NixOS, all of that is
# declared here instead: the systemd user service, required directories, seeded
# config files, and convenience scripts.
#
# Nanoclaw does NOT start automatically — use `nanoclaw-start` / `nanoclaw-stop`
# to manage the stack by hand.
#
# ┌──────────────────────────────────────────────────────────────────────────┐
# │ One-time bootstrap (run once after the first nixos-rebuild switch)       │
# │                                                                          │
# │ 1. Install the OneCLI gateway — drops ~/.onecli/docker-compose.yml:      │
# │      curl -fsSL onecli.sh/install | sh                                   │
# │                                                                          │
# │ 2. Build the agent Docker image (~5–10 min first time):                  │
# │      cd <projectRoot>/container                                          │
# │      docker build -t nanoclaw-agent-v2-a72e394a:latest .                 │
# │                                                                          │
# │ 3. Register your API credential with OneCLI.  The project .env sets      │
# │    ANTHROPIC_BASE_URL=https://openrouter.ai/api/v1, so the host-pattern  │
# │    must match OpenRouter, not api.anthropic.com:                         │
# │      onecli config set api-host http://127.0.0.1:10254                  │
# │      #   --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}'            │
# │      onecli secrets create \                                             │
# │        --name OpenRouter --type anthropic \                              │
# │        --value sk-or-v1-... \                                            │
# │        --host-pattern openrouter.ai                                      │
# │                                                                          │
# │ 4. Seed the initial agent group into the SQLite database:                │
# │      cd <projectRoot>                                                    │
# │      pnpm exec tsx scripts/init-cli-agent.ts \                           │
# │        --display-name "<username>" --agent-name "Personal Assistant"     │
# │                                                                          │
# │ 5. Create ~/.config/nanoclaw/secrets.env — see EnvironmentFile comment   │
# │    below for exactly what goes in it.                                    │
# │                                                                          │
# │ 6. Populate <projectRoot>/.env — see src/config.ts and                   │
# │    src/channels/slack.ts for the full list of keys read from it.         │
# └──────────────────────────────────────────────────────────────────────────┘
{
  pkgs,
  config,
  username,
  ...
}:
let
  projectRoot = "/home/${username}/Prosjekter/Personal/Slackbot/nanoclaw_bot/nanoclaw";

  # ── Install slug ─────────────────────────────────────────────────────────
  # src/install-slug.ts computes this as sha1(projectRoot)[:8].  It is stamped
  # onto every Docker container spawned by this install:
  #   --label nanoclaw-install=<slug>    scopes orphan cleanup to this checkout
  #   image tag: nanoclaw-agent-v2-<slug>:latest
  # The service name below must match what setup/service.ts would generate for
  # this path — if you ever move the project directory, recompute with:
  #   echo -n "<new-absolute-path>" | sha1sum | cut -c1-8
  installSlug = "a72e394a";
  serviceName = "nanoclaw-v2-${installSlug}";

  # ── Mount allowlist ───────────────────────────────────────────────────────
  # Seeded to ~/.config/nanoclaw/mount-allowlist.json by systemd-tmpfiles on
  # first boot (the 'C' rule below never overwrites, so manual edits survive
  # rebuilds).  src/config.ts reads this path on every container spawn to
  # validate any additionalMounts from container.json.
  # Empty allowedRoots is the safe default — the agent only sees what nanoclaw
  # itself mounts (session DBs, group folder, shared source).
  mountAllowlist = pkgs.writeText "nanoclaw-mount-allowlist.json" (
    builtins.toJSON {
      allowedRoots = [ ];
      blockedPatterns = [ ];
      nonMainReadOnly = true;
    }
  );

  # ── OneCLI paths ─────────────────────────────────────────────────────────
  # The OneCLI installer places files in ~/.onecli/, not /opt/onecli/ as
  # older documentation suggested.
  onecliDir = "/home/${username}/.onecli";

  # Use explicit IPv4 127.0.0.1 — "localhost" resolves to [::1] (IPv6) on this
  # system, which is not listening. 127.0.0.1 is stable regardless of Docker
  # network configuration.
  # NOTE: this URL is used by the nanoclaw HOST PROCESS to register/wake
  # containers. Agent containers use a separate proxy URL (port 10255) injected
  # by OneCLI as HTTPS_PROXY — see onecliOverride below.
  onecliUrl = "http://127.0.0.1:10254";

  # ── OneCLI Docker Compose configuration ──────────────────────────────────
  # Problem: docker-compose.yml uses ${ONECLI_BIND_HOST:-127.0.0.1} for all
  # port bindings.  The OneCLI SDK's applyContainerConfig() adds
  # --add-host host.docker.internal:host-gateway to every docker run, so
  # containers reach the host at 172.17.0.1 (Docker bridge gateway).
  # With loopback-only bindings, the HTTPS proxy on port 10255 is therefore
  # unreachable from inside agent containers (fetch failed / API retry loop).
  #
  # Fix (two files, both deployed via L+ tmpfiles symlinks):
  #
  # 1. ~/.onecli/.env — sets ONECLI_BIND_HOST=0.0.0.0 so docker-compose.yml
  #    computes 0.0.0.0 port bindings.  This is the intended variable for this
  #    purpose (added in onecli/onecli#153).  Docker Compose reads .env from
  #    the same directory as docker-compose.yml for variable substitution.
  #
  # 2. docker-compose.override.yml — corrects APP_URL and GATEWAY_API_URL
  #    back to 127.0.0.1 so the web UI still works (browsers cannot connect
  #    to 0.0.0.0).  environment: is a mapping — override values REPLACE base
  #    values for the same key.  No ports: section here; ports: is an array
  #    and Docker Compose APPENDS arrays across files, which would duplicate
  #    bindings and cause "address already in use" errors.
  onecliEnv = pkgs.writeText "onecli-dot-env" ''
    # ~/.onecli/.env — Docker Compose variable substitution.
    # Managed by ~/NixOS-Hyprland/modules/services/nanoclaw.nix.
    #
    # Bind to all interfaces so agent containers can reach the HTTPS proxy
    # at host.docker.internal:10255 (resolves to 172.17.0.1 via --add-host
    # injected by the OneCLI SDK).  See onecli/onecli#153.
    ONECLI_BIND_HOST=0.0.0.0
  '';

  onecliOverride = pkgs.writeText "docker-compose.override.yml" ''
    # docker-compose.override.yml — URL fix
    # Managed by ~/NixOS-Hyprland/modules/services/nanoclaw.nix.
    # Docker Compose auto-merges this with docker-compose.yml.
    #
    # ONECLI_BIND_HOST=0.0.0.0 (set in .env) makes port bindings use all
    # interfaces but also causes APP_URL/GATEWAY_API_URL to be constructed as
    # http://0.0.0.0:... which browsers cannot connect to.  Correct them back
    # to 127.0.0.1 here.  environment: is a mapping — these values replace
    # the base file values for the same keys (unlike ports: which appends).

    services:
      onecli:
        environment:
          APP_URL: http://127.0.0.1:10254
          GATEWAY_API_URL: http://127.0.0.1:10255
  '';

  # ── Convenience scripts ───────────────────────────────────────────────────

  # nanoclaw-start: bring up the full stack in dependency order.
  # OneCLI gateway must be running before nanoclaw starts — it is the HTTPS
  # credential proxy that injects API keys into agent containers.
  nanoclaw-start = pkgs.writeShellScriptBin "nanoclaw-start" ''
    set -euo pipefail

    # Guard against running before the OneCLI installer has been run.
    if [ ! -f ${onecliDir}/docker-compose.yml ]; then
      echo "ERROR: ${onecliDir}/docker-compose.yml not found."
      echo "Run the OneCLI installer first: curl -fsSL onecli.sh/install | sh"
      exit 1
    fi

    echo "Starting OneCLI gateway..."
    cd ${onecliDir} && ${pkgs.docker}/bin/docker compose up -d

    echo "Starting nanoclaw service..."
    systemctl --user start ${serviceName}

    echo ""
    echo "nanoclaw is running."
    echo "  Logs:   journalctl --user -fu ${serviceName}"
    echo "  Status: systemctl --user status ${serviceName}"
  '';

  # nanoclaw-stop: tear down in reverse dependency order.
  # Stop nanoclaw first so any in-flight messages are flushed before the
  # OneCLI gateway disappears.
  nanoclaw-stop = pkgs.writeShellScriptBin "nanoclaw-stop" ''
    set -euo pipefail

    echo "Stopping nanoclaw service..."
    systemctl --user stop ${serviceName} || true

    if [ -f ${onecliDir}/docker-compose.yml ]; then
      echo "Stopping OneCLI gateway..."
      cd ${onecliDir} && ${pkgs.docker}/bin/docker compose down
    fi

    echo "Done."
  '';

  # nanoclaw-rebuild: rebuild all three layers of the stack in order.
  # 1. OneCLI Docker Compose — pull fresh images and recreate the gateway
  #    containers.  Uses --force-recreate so the containers pick up any image
  #    changes even if the compose spec itself is unchanged.
  # 2. nanoclaw pnpm dist — runs `pnpm run build` in the project root, which
  #    compiles TypeScript → dist/index.js (the target of ExecStart above).
  # 3. nanoclaw Docker image — rebuilds nanoclaw-agent-v2-<slug>:latest from
  #    <projectRoot>/container/Dockerfile.  Agent containers spawned after the
  #    rebuild will use the new image; already-running containers are unaffected
  #    until they exit naturally.
  #
  # The running service is NOT stopped/restarted automatically — use
  # `nanoclaw-restart` (or nanoclaw-stop / nanoclaw-start) after this command
  # to bring up the new dist and pick up the rebuilt Docker image.
  nanoclaw-rebuild = pkgs.writeShellScriptBin "nanoclaw-rebuild" ''
    set -euo pipefail

    # Guard against running before the OneCLI installer has been run.
    if [ ! -f ${onecliDir}/docker-compose.yml ]; then
      echo "ERROR: ${onecliDir}/docker-compose.yml not found."
      echo "Run the OneCLI installer first: curl -fsSL onecli.sh/install | sh"
      exit 1
    fi

    echo "==> [1/3] Rebuilding OneCLI Docker Compose stack..."
    cd ${onecliDir} \
      && ${pkgs.docker}/bin/docker compose pull \
      && ${pkgs.docker}/bin/docker compose up -d --force-recreate

    echo ""
    echo "==> [2/3] Rebuilding nanoclaw pnpm dist..."
    cd ${projectRoot} && pnpm run build

    echo ""
    echo "==> [3/3] Rebuilding nanoclaw Docker container image..."
    cd ${projectRoot}/container \
      && ${pkgs.docker}/bin/docker build -t nanoclaw-agent-v2-${installSlug}:latest .

    echo ""
    echo "Rebuild complete.  Run 'nanoclaw-restart' to apply the new build."
  '';

  # nanoclaw-restart: stop the full stack then bring it back up.
  # Delegates entirely to nanoclaw-stop / nanoclaw-start so the dependency
  # order (OneCLI gateway before nanoclaw service) is always respected.
  nanoclaw-restart = pkgs.writeShellScriptBin "nanoclaw-restart" ''
    set -euo pipefail
    ${nanoclaw-stop}/bin/nanoclaw-stop && ${nanoclaw-start}/bin/nanoclaw-start
  '';

  # ncl: thin wrapper around bin/ncl in the project directory.
  # bin/ncl resolves symlinks on $BASH_SOURCE[0] to find PROJECT_ROOT, so
  # exec-ing it at its absolute path is sufficient — no cd needed here.
  # bin/ncl itself runs: pnpm exec tsx src/cli/client.ts "$@"
  # pnpm is available on PATH from modules/packages/dev-node.nix.
  ncl = pkgs.writeShellScriptBin "ncl" ''
    exec "${projectRoot}/bin/ncl" "$@"
  '';
in
{
  # ── Systemd user service ──────────────────────────────────────────────────
  # Declared at the system level so it lands in /etc/systemd/user/ and is
  # available without home-manager.
  # No `wantedBy` means it never auto-starts on login — use nanoclaw-start.
  systemd.user.services.${serviceName} = {
    description = "NanoClaw personal AI assistant (slug: ${installSlug})";

    # Ensure the network stack is up before nanoclaw attempts to reach the
    # OneCLI gateway or connect to Slack via socket mode.
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";

      # Runs the compiled host process (pnpm run build → dist/).
      # nodejs is pinned to the same derivation used in dev-node.nix so the
      # Node version matches the one that compiled better-sqlite3's native
      # addon (.node file).  If the Node package is bumped in a future
      # nixpkgs update, re-run `pnpm install` in the project root so
      # better-sqlite3 is recompiled against the new version.
      ExecStart = "${pkgs.nodejs_22}/bin/node ${projectRoot}/dist/index.js";
      WorkingDirectory = projectRoot;

      # Restart on crash (e.g. unhandled rejection) but not on intentional
      # stop (clean exit code 0 from nanoclaw-stop).
      Restart = "on-failure";
      RestartSec = "5";

      # Kill only the main process; Docker containers spawned per-session
      # have their own lifecycle and should not be killed with the host.
      KillMode = "process";

      # HOME: os.homedir() calls inside nanoclaw need this — e.g. resolving
      #       ~/.config/nanoclaw/mount-allowlist.json (src/config.ts).
      # PATH: docker must be reachable for container spawning at runtime.
      #       nodejs is included for any child node invocations.
      #       System paths cover everything else (onecli, etc.).
      # TZ:   read by src/config.ts for scheduled task timezone resolution.
      #       Pulled from time.timeZone so it stays in sync with the system.
      Environment = [
        "HOME=/home/${username}"
        "PATH=${pkgs.nodejs_22}/bin:${pkgs.docker}/bin:/run/wrappers/bin:/run/current-system/sw/bin"
        "TZ=${config.time.timeZone}"
      ];

      # Secrets file for variables that must be in process.env at runtime.
      #
      # Background: nanoclaw reads most config via readEnvFile() in src/env.ts,
      # which parses the project's .env file directly and does NOT populate
      # process.env.  Variables read that way (ONECLI_URL, SLACK_BOT_TOKEN,
      # SLACK_SIGNING_SECRET, etc.) belong in <projectRoot>/.env, not here.
      #
      # SLACK_APP_TOKEN is different — @chat-adapter/slack reads it exclusively
      # via process.env.SLACK_APP_TOKEN (see dist/index.js:4262 in the package).
      # src/channels/slack.ts does not pass it through readEnvFile, so it must
      # arrive via the environment.  This EnvironmentFile is the right place.
      #
      # Minimum contents of ~/.config/nanoclaw/secrets.env:
      #   SLACK_APP_TOKEN=xapp-...
      #
      # The leading '-' tells systemd not to fail if the file is absent,
      # allowing the service to start before the secrets file is created.
      EnvironmentFile = "-/home/${username}/.config/nanoclaw/secrets.env";

      # Append to files rather than writing to the journal, so logs survive
      # restarts and are easy to inspect from the project directory.
      # The directories are created by the tmpfiles rules below.
      StandardOutput = "append:${projectRoot}/logs/nanoclaw.log";
      StandardError = "append:${projectRoot}/logs/nanoclaw.error.log";
    };
  };

  # ── systemd-tmpfiles ──────────────────────────────────────────────────────
  # Creates directories and seeds config files.  All rules are idempotent and
  # run at boot (and on `systemd-tmpfiles --create` after a rebuild).
  systemd.tmpfiles.rules = [
    # Config directory — holds mount-allowlist.json and secrets.env.
    "d /home/${username}/.config/nanoclaw 0755 ${username} users -"

    # Seed mount-allowlist.json from the Nix store on first creation.
    # 'C' (copy) only acts if the target does not already exist, so manual
    # edits to allowedRoots are preserved across nixos-rebuild invocations.
    "C /home/${username}/.config/nanoclaw/mount-allowlist.json 0644 ${username} users - ${mountAllowlist}"

    # Log directory referenced by StandardOutput/StandardError above.
    # Must exist before the service attempts to open the append target,
    # otherwise systemd will refuse to start the service.
    "d ${projectRoot}/logs 0755 ${username} users -"

    # SQLite database directory.  src/config.ts resolves DATA_DIR as
    # path.resolve(process.cwd(), 'data') → <projectRoot>/data at runtime.
    "d ${projectRoot}/data 0755 ${username} users -"

    # Ensure ~/.onecli/ exists before writing into it.  The OneCLI installer
    # creates it, but the 'd' rule is harmless if it already exists.
    "d /home/${username}/.onecli 0755 ${username} users -"

    # ~/.onecli/.env — sets ONECLI_BIND_HOST=0.0.0.0 so port bindings use all
    # interfaces.  Docker Compose reads this file for variable substitution.
    "L+ /home/${username}/.onecli/.env - - - - ${onecliEnv}"

    # docker-compose.override.yml — corrects APP_URL/GATEWAY_API_URL back to
    # 127.0.0.1 (environment mapping merge replaces; no ports section to avoid
    # array-append duplication).
    "L+ /home/${username}/.onecli/docker-compose.override.yml - - - - ${onecliOverride}"
  ];

  # ── System packages ───────────────────────────────────────────────────────
  # nanoclaw-start / nanoclaw-stop manage the full stack (OneCLI gateway +
  # nanoclaw service) in the correct dependency order.
  # ncl is the interactive CLI client for sending messages to the running service.
  environment.systemPackages = [
    nanoclaw-start
    nanoclaw-stop
    nanoclaw-rebuild
    nanoclaw-restart
    ncl
  ];
}
