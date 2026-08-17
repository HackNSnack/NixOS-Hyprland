# Productivity and note-taking apps
# FreeCAD moved to Flatpak (org.freecad.FreeCAD, see
# hosts/default/config.nix services.flatpak.packages) — it pulls ~7.6 GB
# of closure (pyside6, vtk, shiboken6, OCCT) that we don't want in the system path.
# To revert: uncomment the freecad line below and remove the Flatpak entry.
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    obsidian        # Note-taking
    libqalculate    # Calculator library
    rofi-calc       # Rofi calculator plugin
    # freecad       # Now via Flatpak (org.freecadweb.FreeCAD)
  ];
}