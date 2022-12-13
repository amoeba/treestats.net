{...}: {
  packages = {
    nixpkgs-flox = {
      redis = {};
      hivemind = {}; # foreman replacement

      nodejs-slim = {}; # Javascript env required for "bundle install"

      # Env that allows building native extensions
      gcc = {};
      gitMinimal = {};
      sqlite = {};
      libpcap = {};
      libxml2 = {};
      libxslt = {};
      pkg-config = {};
      bundix = {};
      gnumake = {};
      ruby_3_1 = {};
    };
  };
}
