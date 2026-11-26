# A user service that runs a machine-local script, ~/.config/agent-runner/start (not in this repo), so what it
# runs can change without a rebuild. It starts only where that script exists, and starts it again whenever it
# exits: the script exits by itself to pick up new code (AGENT_RUNNER_KEEPALIVE tells it something restarts it).
# Stopping signals only the main process (KillMode=process), so the script can let work in flight finish; a
# switch never restarts it. MemoryMax caps it and everything it starts.
_: {
  systemd.user.services.agent-runner = {
    Unit = {
      Description = "Agent task runner (machine-local script)";
      ConditionPathExists = "%h/.config/agent-runner/start";
      X-RestartIfChanged = false;
    };
    Service = {
      ExecStart = "%h/.config/agent-runner/start";
      Environment = ["AGENT_RUNNER_KEEPALIVE=1"];
      Restart = "always";
      RestartSec = 30;
      KillMode = "process";
      TimeoutStopSec = "4h";
      MemoryMax = "8G";
    };
    Install.WantedBy = ["default.target"];
  };
}
