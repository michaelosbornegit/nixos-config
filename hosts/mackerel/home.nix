{...}: {
  # work email
  programs.git.settings.user.email = "mosborne@blankmetal.ai";

  # Drive the Desk Buddy OLED agent counter from aut's database.
  services.aut.deskbuddy.enable = true;
}
