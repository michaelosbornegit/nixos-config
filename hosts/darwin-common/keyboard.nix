# Modifier-key remaps, per keyboard: what System Settings > Keyboard >
# Keyboard Shortcuts > Modifier Keys writes. macOS keeps one list per keyboard
# (vendor-product IDs) in the per-host global preferences, so each keyboard
# below gets its own entry; an unlisted keyboard keeps the default layout.
#
# Changes apply at the next login (or when the keyboard reconnects).
#
# To add a keyboard: remap it once in System Settings, then read its key and
# list with `defaults -currentHost read -g | grep -A30 modifiermapping`.
{lib, ...}: let
  # HID usages as macOS stores them (usage page << 32 | usage).
  key = {
    leftControl = 30064771296; # 0x7000000E0
    leftOption = 30064771298; # 0x7000000E2
    leftCommand = 30064771299; # 0x7000000E3
    rightControl = 30064771300; # 0x7000000E4
    rightOption = 30064771302; # 0x7000000E6
    rightCommand = 30064771303; # 0x7000000E7
    fn = 1095216660483; # 0xFF00000003, keyboard fn/Globe
    fnBuiltIn = 280379760050179; # 0xFF0100000003, MacBook fn/Globe
  };

  keyboards = {
    # MacBook built-in keyboard: fn is Command, Command is Control, Control is
    # Option.
    "0-0-0" = with key; [
      [fnBuiltIn leftCommand]
      [leftCommand leftControl]
      [leftControl leftOption]
      [rightCommand rightControl]
      [rightControl rightOption]
      [fn rightCommand]
    ];

    # Logitech keyboard (1133 = Logitech): Command and Control swapped.
    "1133-45943-0" = with key; [
      [leftControl leftCommand]
      [leftCommand leftControl]
      [rightControl rightCommand]
      [rightCommand rightControl]
      [fnBuiltIn fn]
    ];

    # Logitech Bolt receiver with a Windows-layout keyboard: Ctrl is Command,
    # Win is Option, Alt is Control, on both sides.
    "1133-50504-0" = with key; [
      [leftControl leftCommand]
      [leftCommand leftOption]
      [leftOption leftControl]
      [rightControl rightCommand]
      [rightCommand rightOption]
      [rightOption rightControl]
      [fnBuiltIn fn]
    ];
  };

  toPlist = pairs:
    lib.generators.toPlist {escape = true;} (map (p: {
        HIDKeyboardModifierMappingSrc = builtins.elemAt p 0;
        HIDKeyboardModifierMappingDst = builtins.elemAt p 1;
      })
      pairs);
in {
  home.activation.modifierKeys = lib.hm.dag.entryAfter ["writeBoundary"] (
    lib.concatStrings (lib.mapAttrsToList (id: pairs: ''
        run /usr/bin/defaults -currentHost write -g com.apple.keyboard.modifiermapping.${id} ${lib.escapeShellArg (toPlist pairs)}
      '')
      keyboards)
  );
}
