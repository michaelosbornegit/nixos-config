# A user service that runs a machine-local script, ~/.config/agent-runner/start (not in this repo), so what it
# runs can change without a rebuild. It starts only where that script exists. Stopping signals only the main
# process (KillMode=process), so the script can let work in flight finish; a switch never restarts it.
_: {
  systemd.user.services.agent-runner = {
    Unit = {
      Description = "Agent task runner (machine-local script)";
      ConditionPathExists = "%h/.config/agent-runner/start";
      X-RestartIfChanged = false;
    };
    Service = {
      ExecStart = "%h/.config/agent-runner/start";
      Restart = "on-failure";
      RestartSec = 30;
      KillMode = "process";
      TimeoutStopSec = "2h";
    };
    Install.WantedBy = ["default.target"];
  };
}
