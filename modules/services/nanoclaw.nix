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
# │ 1. Install the OneCLI gateway — drops /opt/onecli/docker-compose.yml:    │
# │      curl -fsSL onecli.sh/install | sh                                   │
# │                                                                          │
# │ 2. Build the agent Docker image (~5–10 min first time):                  │
# │      cd <projectRoot>/container                                          │
# │      docker build -t nanoclaw-agent-v2-a72e394a:latest .                 │
# │                                                                          │
# │ 3. Register your API credential with OneCLI.  The project .env sets      │
# │    ANTHROPIC_BASE_URL=https://openrouter.ai/api/v1, so the host-pattern  │
# │    must match OpenRouter, not api.anthropic.com:                         │
# │      onecli config set api-host http://localhost:10254                   │
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
  lib,
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

  # ── Convenience scripts ───────────────────────────────────────────────────

  # nanoclaw-start: bring up the full stack in dependency order.
  # OneCLI gateway must be running before nanoclaw starts — it is the HTTPS
  # credential proxy that injects API keys into agent containers.
  nanoclaw-start = pkgs.writeShellScriptBin "nanoclaw-start" ''
    set -euo pipefail

    # Guard against running before the OneCLI installer has been run.
    if [ ! -f /opt/onecli/docker-compose.yml ]; then
      echo "ERROR: /opt/onecli/docker-compose.yml not found."
      echo "Run the OneCLI installer first: curl -fsSL onecli.sh/install | sh"
      exit 1
    fi

    echo "Starting OneCLI gateway..."
    cd /opt/onecli && ${pkgs.docker}/bin/docker compose up -d

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

    if [ -f /opt/onecli/docker-compose.yml ]; then
      echo "Stopping OneCLI gateway..."
      cd /opt/onecli && ${pkgs.docker}/bin/docker compose down
    fi

    echo "Done."
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
      ExecStart = "${pkgs.nodejs}/bin/node ${projectRoot}/dist/index.js";
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
        "PATH=${pkgs.nodejs}/bin:${pkgs.docker}/bin:/run/wrappers/bin:/run/current-system/sw/bin"
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
  ];

  # ── System packages ───────────────────────────────────────────────────────
  # nanoclaw-start / nanoclaw-stop manage the full stack (OneCLI gateway +
  # nanoclaw service) in the correct dependency order.
  # ncl is the interactive CLI client for sending messages to the running service.
  environment.systemPackages = [
    nanoclaw-start
    nanoclaw-stop
    ncl
  ];
}
