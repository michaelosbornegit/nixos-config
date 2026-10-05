# Runs scripts/micropython/esp32-c3/agent-monitor/host_monitor.py continuously
# as a per-user LaunchAgent, so the Desk Buddy OLED agent counter stays live
# across reboots without needing a terminal left open.
#
# The script itself lives in the (separately git-managed) scripts repo, not
# copied into the Nix store, so editing it there takes effect on next
# restart without a rebuild here. See that repo's
# micropython/esp32-c3/agent-monitor/README.md for what this actually does.
{
  pkgs,
  config,
  ...
}: let
  pythonEnv = pkgs.python3.withPackages (ps: [ps.pyserial]);
  scriptPath = "${config.home.homeDirectory}/development/repos/scripts/micropython/esp32-c3/agent-monitor/host_monitor.py";
  logPath = "${config.home.homeDirectory}/Library/Logs/claude-agent-monitor.log";
in {
  launchd.agents.claude-agent-monitor = {
    enable = true;
    config = {
      ProgramArguments = ["${pythonEnv}/bin/python3" scriptPath];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = logPath;
      StandardErrorPath = logPath;
    };
  };
}
