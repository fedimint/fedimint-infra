{ inputs, ... }: {
  environment.etc."nixpkgs-last-modified".text = toString inputs.nixpkgs.lastModified;
}
