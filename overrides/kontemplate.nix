{ pkgs, ... }:

let master = pkgs.third_party.kontemplate.overrideAttrs(_: {
  src = pkgs.third_party.fetchFromGitHub {
    owner = "tazjin";
    repo = "kontemplate";
    rev = "v1.8.0";
    sha256 = "123mjmmm4hynraq1fpn3j5i0a1i87l265kkjraxxxbl0zacv74i1";
  };
});
in pkgs.third_party.writeShellScriptBin "kontemplate" ''
  export PATH="${pkgs.tools.kms_pass}/bin:$PATH"
  exec ${master}/bin/kontemplate $@
''
