# A launchd agent that runs a machine-local script, ~/.config/agent-runner/start (not in this repo), so what it
# runs can change without a rebuild. It runs while that script exists (launchd starts it when the file appears)
# and starts it again whenever it exits: the script exits by itself to pick up new code
# (AGENT_RUNNER_KEEPALIVE tells it something restarts it). Stopping it signals the script, which can let work
# in flight finish: launchd waits up to 4 hours for that. launchd enforces no memory cap; the script sizes its
# own work to the machine's memory.
{config, ...}: let
  start = "${config.home.homeDirectory}/.config/agent-runner/start";
in {
  launchd.agents.agent-runner = {
    enable = true;
    config = {
      ProgramArguments = ["/bin/bash" start];
      EnvironmentVariables.AGENT_RUNNER_KEEPALIVE = "1";
      KeepAlive.PathState.${start} = true;
      RunAtLoad = true;
      ThrottleInterval = 30;
      ExitTimeOut = 14400;
      ProcessType = "Standard";
    };
  };
}
