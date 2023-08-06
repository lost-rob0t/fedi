{ stdenv, nimPackages, fetchzip }:

let
  jsony = nimPackages.buildNimPackage rec {
    pname = "jsony";
    version = "1.1.3";
    src = fetchzip {
      inherit version;
      url = "https://github.com/treeform/jsony/archive/refs/tags/${version}.zip";
      hash = "sha256-jtUCoqwCmE536Kpv/vZxGgqiHyReZf1WOiBdUzmMhM4=";
    };
    doCheck = true;
  };

in
nimPackages.buildNimPackage rec {
  pname = "fedi";
  version = "0.1.3";
  src = fetchzip {
    inherit version;
    url = "https://gitlab.nobodyhasthe.biz/nsaspy/fedi_nim/-/archive/0.1.3/fedi_nim-${version}.zip";
    hash = "sha256-jMLtSphY3+U/aFKU53SeEKwBt6Ebt8kxDCV1yI0nOzc=";
  };
  propagatedBuildInputs = [ jsony ];
  doCheck = false;
}
