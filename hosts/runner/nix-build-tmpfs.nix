{
  fileSystems."/build" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "mode=1777"
      "size=50%"
    ];
  };

  nix.settings.build-dir = "/build";
}
