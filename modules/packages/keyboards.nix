# QMK/Mechanical keyboard support
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    vial  # QMK Firmware GUI
    via   # Alternative keyboard configurator
  ];

  # udev rules for QMK keyboards
  services.udev.packages = with pkgs; [
    qmk
    qmk-udev-rules
    qmk_hid
    via
    vial
  ];
}
