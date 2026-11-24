# Contributing

The toolchain is managed with [Nix](https://nixos.org/).

Routine tasks are managed with [Task](https://taskfile.dev/).

```sh
nix develop
task check
task test
nix fmt
```

`task check` also rewrites each package's `pkg.generated.mbti`, so commit the rewritten files together with the change.

`task --list` shows the other tasks.

The integration tests need a running Trac.
`task trac:up` starts the throwaway Trac in [compose.yaml](./compose.yaml) on <http://localhost:8000>, and `task trac:reset` removes it together with its data.

```sh
task trac:up
task test:integration
task trac:reset
```

The throwaway Trac has three accounts, so that both a refused write and a refused login can be tested.

- `admin` holds `TRAC_ADMIN`.
- `viewer` may call the RPC and read, but not edit.
- `outsider` can log in but lacks `XML_RPC`.

## Layout

The Trac SDK is a separate module so that another MoonBit program can use it without pulling in the server.

- `shirousagi/` is the server and its CLI.
- `trac/` is the SDK for the JSON-RPC protocol of the [TracXMLRPC](https://trac-hacks.org/wiki/XmlRpcPlugin) plugin.
- `integration-test/` holds the tests that run against a real Trac.
    It is a test module that the root `moon.work` does not list, so a plain `moon test` never compiles it.

## Versioning

Follow [Semantic Versioning 2.0.0](https://semver.org/).

## Commit

Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) and use the well-known [commit types](https://github.com/conventional-changelog/commitlint/tree/master/%40commitlint/config-conventional#type-enum).
