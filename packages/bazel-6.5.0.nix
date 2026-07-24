{
  enableNixHacks ? false,
  fetchFromGitHub,
  stdenv,
}: let
  nixpkgs = fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "e7eabdc701d7dbb810fd91a97ec358caa4c1fc50";
    hash = "sha256-di5L6e5Iiv+oegS07j9h23FdqEpXn0ZQqMlDOEMw1EY=";
  };
in
  (import nixpkgs {
    system = stdenv.buildPlatform.system;
  }).bazel.override {inherit enableNixHacks;}
