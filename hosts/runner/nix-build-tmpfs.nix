{
  fileSystems."/build" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "mode=0755"
      "size=50%"
    ];
  };

  nix.settings.build-dir = "/build";
}
