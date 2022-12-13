{
  self,
  stdenv,
  bundlerEnv,
  ruby,
}: let
  # running the bundix command
  # will generate the gemset.nix file below
  gems = bundlerEnv {
    name = "my-package-env";
    inherit ruby;
    gemfile = ../../Gemfile;
    lockfile = ../../Gemfile.lock;
    #gemset = ../../gemset.nix;
  };
in
  stdenv.mkDerivation rec {
    pname = "treestats";
    version = "0.0.0";
    src = self; # + "/src";
    buildInputs = [gems ruby];
    installPhase = ''
      mkdir -p $out/bin  $out/share/${pname}
      cp -r * $out/share/${pname}
      bin=$out/bin/${pname}
      # we are using bundle exec to start in the bundled environment
      cat > $bin <<EOF
      #!/bin/sh -e
        exec ${gems}/bin/bundle exec ${ruby}/bin/ruby $out/share/${pname}/lib/${pname}.rb "\$@"
      EOF
      chmod +x $bin
    '';
  }
