{
  description = "Trac MCP server by moonbit";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur-packages = {
      url = "github:Omochice/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    moonbit-overlay = {
      url = "github:moonbit-community/moonbit-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # The fork carries the fixes this workspace needs (./ members, pkgtype executables, dev_build in sub-packages) until upstream merges them.
    moon-nix = {
      url = "github:Omochice/moon-nix/fix-moon-compat";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.moonbit-overlay.follows = "moonbit-overlay";
    };
    mooncakes-index = {
      url = "git+https://mooncakes.io/git/index";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      flake-utils,
      nur-packages,
      git-hooks,
      moonbit-overlay,
      moon-nix,
      mooncakes-index,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            nur-packages.overlays.default
            moonbit-overlay.overlays.default
          ];
        };
        # moonbit-overlay publishes toolchains only for aarch64-darwin and x86_64-linux.
        moonbitToolchain = pkgs.lib.optional (pkgs.moonbit-bin ? latest) pkgs.moonbit-bin.latest;
        moonManifests = map builtins.readFile [
          ./integration-test/moon.mod
          ./shirousagi/moon.mod
          ./trac/moon.mod
        ];
        matchesIn = pattern: text: builtins.filter builtins.isList (builtins.split pattern text);
        workspaceModules = pkgs.lib.concatMap (
          manifest: map builtins.head (matchesIn ''name = "([^"]+)"'' manifest)
        ) moonManifests;
        # A dependency that only another dependency declares is not found this way and has to be declared in a manifest.
        registryModules = pkgs.lib.pipe moonManifests [
          (pkgs.lib.concatMap (matchesIn ''"([^"@]+)@([^"]+)"''))
          pkgs.lib.unique
          (builtins.filter (module: !(builtins.elem (builtins.head module) workspaceModules)))
        ];
        mooncakesArchive =
          module:
          let
            name = builtins.elemAt module 0;
            version = builtins.elemAt module 1;
            records = pkgs.lib.pipe "${mooncakes-index}/user/${name}.index" [
              builtins.readFile
              (pkgs.lib.splitString "\n")
              (builtins.filter (line: line != ""))
              (map builtins.fromJSON)
            ];
            record =
              pkgs.lib.findFirst (record: record.version == version)
                (throw "${name}@${version} is not in the pinned mooncakes index; run `nix flake update mooncakes-index`")
                records;
          in
          {
            inherit name;
            archive = pkgs.fetchurl {
              url = "https://download.mooncakes.io/user/${name}/${version}.zip";
              sha256 = record.checksum;
            };
          };
        # `task check` is not reused: it syncs dependencies from the registry, which a build cannot reach.
        moonCheck =
          pkgs.runCommand "moon-check"
            {
              nativeBuildInputs = [ pkgs.unzip ] ++ moonbitToolchain;
              src = self;
            }
            ''
              cp -r $src source
              chmod -R u+w source
              cd source
              export MOON_HOME=$TMPDIR/moon-home
              mkdir -p $MOON_HOME/registry
              # Even a frozen check resolves the dependency graph through the index.
              ln -s ${mooncakes-index} $MOON_HOME/registry/index
              for workspace in . integration-test; do
                ${pkgs.lib.concatMapStrings (
                  module:
                  "mkdir -p $workspace/.mooncakes/${module.name}\nunzip -q ${module.archive} -d $workspace/.mooncakes/${module.name}\n"
                ) (map mooncakesArchive registryModules)}
              done
              moon check --deny-warn --frozen
              (cd integration-test && moon check --deny-warn --frozen)
              touch $out
            '';
        treefmt = treefmt-nix.lib.evalModule pkgs (
          { ... }:
          let
            rumdlConfig = (pkgs.formats.toml { }).generate "rumdl.toml" {
              # keep-sorted start
              MD004.style = "dash";
              MD007.indent = 4;
              MD007.style = "fixed";
              MD041.enabled = false;
              MD049.style = "underscore";
              MD050.style = "asterisk";
              MD055.style = "leading-and-trailing";
              MD060.enabled = true;
              MD060.style = "aligned";
              MD077.enabled = false;
              global.line_length = 0;
              # keep-sorted end
            };
          in
          {
            settings.global.excludes = [ ];
            settings.formatter.moonfmt = pkgs.lib.mkIf (moonbitToolchain != [ ]) {
              command = pkgs.lib.getExe (
                pkgs.writeShellApplication {
                  name = "moonfmt-each";
                  runtimeInputs = moonbitToolchain;
                  text = ''
                    for file in "$@"; do
                      moonfmt -w "$file"
                    done
                  '';
                }
              );
              includes = [
                "*.mbt"
                "*.mbt.md"
                "moon.mod"
                "moon.pkg"
              ];
            };
            settings.formatter.rumdl-format.options = [
              "--config"
              (toString rumdlConfig)
            ];
            programs = {
              # keep-sorted start block=yes
              keep-sorted.enable = true;
              nixfmt.enable = true;
              rumdl-format.enable = true;
              toml-sort.enable = true;
              yamlfmt = {
                enable = true;
                settings = {
                  formatter = {
                    type = "basic";
                    retain_line_breaks_single = true;
                  };
                };
              };
              # keep-sorted end
            };
          }
        );
        pre-commit-check = git-hooks.lib.${system}.run {
          src = ./.;
          package = pkgs.prek;
          hooks = {
            # Claude Code sets CLAUDECODE; humans are covered by the pre-push hook
            gitleaks-commit = {
              enable = true;
              name = "gitleaks (claude commit)";
              entry = pkgs.lib.getExe (
                pkgs.writeShellApplication {
                  name = "gitleaks-when-claude";
                  runtimeInputs = [ pkgs.gitleaks ];
                  text = ''
                    if [ -z "''${CLAUDECODE:-}" ]; then
                      exit 0
                    fi
                    gitleaks git --pre-commit --staged --no-banner --redact
                  '';
                }
              );
              pass_filenames = false;
              stages = [ "pre-commit" ];
            };
            gitleaks-push = {
              enable = true;
              name = "gitleaks";
              entry = "${pkgs.lib.getExe pkgs.gitleaks} git --no-banner --redact";
              pass_filenames = false;
              stages = [ "pre-push" ];
            };
            # Not on the pre-commit stage: `checks.pre-commit` runs that stage inside a nix build, which cannot reach the registry.
            moon-check = {
              enable = moonbitToolchain != [ ];
              name = "moon check";
              entry = pkgs.lib.getExe (
                pkgs.writeShellApplication {
                  name = "moon-check";
                  runtimeInputs = [ pkgs.go-task ] ++ moonbitToolchain;
                  text = ''
                    task check
                  '';
                }
              );
              pass_filenames = false;
              stages = [ "pre-push" ];
            };
            treefmt = {
              enable = true;
              packageOverrides.treefmt = treefmt.config.build.wrapper;
              stages = [ "pre-push" ];
            };
          };
        };
        devPackages = rec {
          # keep-sorted start block=yes
          actions = with pkgs; [
            actionlint
            ghalint
            zizmor
          ];
          moonbit = moonbitToolchain;
          # keep-sorted end
          default = [
            pkgs.go-task
            treefmt.config.build.wrapper
          ]
          ++ actions
          ++ moonbit;
        };
      in
      {
        # keep-sorted start block=yes
        checks = {
          # keep-sorted start
          actions =
            pkgs.runCommand "check-actions"
              {
                buildInputs = with pkgs; [
                  actionlint
                  ghalint
                  zizmor
                ];
                src = self;
              }
              ''
                cd $src
                actionlint -config-file .github/actionlint.yaml .github/**/*.{yaml,yml}
                ghalint run
                zizmor .github/workflows .github/actions
                touch $out
              '';
          formatting = treefmt.config.build.check self;
          moon-check = moonCheck;
          pre-commit = pre-commit-check;
          renovate =
            pkgs.runCommand "validate-renovate-config"
              {
                buildInputs = with pkgs; [
                  renovate
                ];
                src = self;
              }
              ''
                cd $src
                renovate-config-validator --strict renovate.json5
                touch $out
              '';
          # keep-sorted end
        };
        devShells = pkgs.lib.pipe devPackages [
          (pkgs.lib.attrsets.mapAttrs (
            name: buildInputs:
            pkgs.mkShell (
              {
                buildInputs =
                  buildInputs
                  ++ pre-commit-check.enabledPackages
                  ++ pkgs.lib.optional pkgs.stdenv.hostPlatform.isDarwin pkgs.llvmPackages.lld;
                inherit (pre-commit-check) shellHook;
              }
              # nixpkgs' ld64 cannot build compact unwind info for moonc's output and
              # prints a warning per function; lld from the same LLVM release builds it.
              // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
                NIX_CFLAGS_LINK = "-fuse-ld=lld";
              }
            )
          ))
        ];
        formatter = treefmt.config.build.wrapper;
        packages = pkgs.lib.optionalAttrs (moonbitToolchain != [ ]) rec {
          shirousagi =
            (moon-nix.lib.mkMoonNix {
              inherit pkgs;
              toolchain = builtins.head moonbitToolchain;
            }).buildProject
              {
                # Not `self`: moon-nix builds attribute names from paths under src, and a string from `self` carries store-path context that Nix rejects there.
                src = ./.;
                mainPackage = "omochice/shirousagi/cmd/shirousagi";
                target = "native";
                registry = mooncakes-index;
                meta = {
                  description = "Trac MCP server";
                  license = pkgs.lib.licenses.zlib;
                };
              };
          default = shirousagi;
        };
        # keep-sorted end
      }
    );
}
