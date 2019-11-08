{
  buildInfo ? null,
  language ? null,
  pkgs ? import <nixpkgs> { config = { allowUnfree = true; }; },
  unstable ? import <nixpkgs-unstable> { config = { allowUnfree = true; }; }
}:

let

# Base Image should contain only the essentials to run the application in a container.
# Alternatives to nologin are 'su' and 'shadow' (full suite)
imagePackages = [ pkgs.coreutils pkgs.nologin pkgs.bash ];
path = "PATH=/usr/bin:/bin:${goss}/bin:${language.package}/bin";

#######################
# Derivations         #
#######################

goss = pkgs.callPackage ./pkgs/goss.nix {};
s6-overlay = pkgs.callPackage ./pkgs/s6-overlay.nix {};

#######################
# Build Image Code    #
#######################


in
  pkgs.dockerTools.buildLayeredImage {
    name = buildInfo.name;
    tag = buildInfo.tag;
    contents = imagePackages ++ buildInfo.packages ++ [ s6-overlay goss ];
    maxLayers = 104; # 128 is the maximum number of layers, leaving 24 available for extension
    config = ({
      Entrypoint = [ "/init" ];
    } // buildInfo.config // { Env = buildInfo.config.Env ++ [ path ]; });
    extraCommands = ''
      chmod 755 ./etc
      echo "root:x:0:0::/root:${pkgs.bash}" > ./etc/passwd
      chmod 0555 ./etc/passwd
      echo "root:!x:::::::" > ./etc/shadow
      chmod 0555 ./etc/shadow
      echo "root:x:0:" > ./etc/group
      chmod 0555 ./etc/group
      echo "root:x::" > ./etc/gshadow
      chmod 0555 ./etc/gshadow
      mkdir -p ./etc/pam.d
      chmod 755 ./etc/pam.d
      cat > ./etc/pam.d/other <<EOF
      account sufficient pam_unix.so
      auth sufficient pam_rootok.so
      password requisite pam_unix.so nullok sha512
      session required pam_unix.so
      EOF
      chmod 0555 ./etc/pam.d/other
      chmod 0555 ./etc/pam.d
      ln -s "${pkgs.bash}/bin/bash" ./bash
      mkdir -p ./opt/app
    '';
  }
