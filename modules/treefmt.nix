{
  perSystem = {
    config,
    lib,
    ...
  }: {
    treefmt.config = {
      projectRootFile = "flake.nix";
      programs.alejandra.enable = true;
      programs.shellcheck.enable = true;
      programs.shfmt.enable = true;
    };

    formatter = config.treefmt.build.wrapper;

    apps.fmt = {
      type = "app";
      program = lib.getExe config.treefmt.build.wrapper;
      meta.description = "Format the nixos-imx95 source tree";
    };
  };
}
