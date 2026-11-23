# shirousagi

An MCP server for [Trac](https://trac.edgewall.org/), written in MoonBit.
It gives an MCP client the tickets, wiki, attachments, milestones, components, versions, ticket field values and search of one Trac project over stdio.

The username and password live together in the OS credential store (the macOS keychain, the Secret Service on Linux, or the Windows Credential Manager).
The password is never put in a config file, an environment variable or an argument list; only the username is passed as an argument, to `login`.

## Requirements

The Trac project needs the [TracXMLRPC](https://trac-hacks.org/wiki/XmlRpcPlugin) plugin enabled, and the user needs the `XML_RPC` permission.
shirousagi speaks the plugin's JSON-RPC protocol at `<project>/login/rpc` and logs in with HTTP Basic authentication, so the web server in front of Trac has to accept Basic authentication there.

## Build

The dev shell of the flake provides the toolchain.

```sh
nix develop
task build
```

The executable is written to `_build/native/release/build/omochice/shirousagi/cmd/shirousagi/shirousagi.exe`.

## Usage

Store the password for a project once; it is read at a hidden prompt, or from stdin when stdin is not a terminal.

```sh
shirousagi login --endpoint https://trac.example.com/project --username alice
shirousagi list
shirousagi logout --endpoint https://trac.example.com/project
```

Register the server with an MCP client, for example Claude Code:

```sh
claude mcp add trac -- shirousagi serve --endpoint https://trac.example.com/project
```

`serve --readonly` leaves out every action that writes, so a write cannot even be expressed.

On macOS a keychain item is readable without a prompt only by the executable that stored it, so after rebuilding or upgrading shirousagi, run `logout` and `login` again.

## Tools

Each tool takes exactly one key, the action name, whose value holds that action's arguments, e.g. `{"get": {"id": 42}}`.
The readonly column lists what `--readonly` keeps.

| Tool               | Readonly                                                                         | Also in full mode            |
| ------------------ | -------------------------------------------------------------------------------- | ---------------------------- |
| `trac_tickets`     | `query`, `get`, `changelog`, `actions`, `fields`, `recent_changes`               | `create`, `update`, `delete` |
| `trac_wiki`        | `list`, `get`, `info`, `recent_changes`, `html`, `render`                        | `put`, `delete`              |
| `trac_attachments` | `list`, `get`                                                                    | `put`, `delete`              |
| `trac_milestones`  | `list`, `get`                                                                    | `create`, `update`, `delete` |
| `trac_components`  | `list`, `get`                                                                    | `create`, `update`, `delete` |
| `trac_versions`    | `list`, `get`                                                                    | `create`, `update`, `delete` |
| `trac_enums`       | `list`, `get`, `statuses`                                                        | `create`, `update`, `delete` |
| `trac_search`      | `search`, `filters`                                                              |                              |
| `shirousagi_info`  | `show`, `ping`, `wiki_rpc_version`, `methods`, `method_help`, `method_signature` |                              |

A ticket `update` takes as `ts` the `_ts` that `get` answers, so Trac refuses it when someone changed the ticket in between.
Datetimes are ISO 8601 text with an optional offset, such as `2030-01-31T09:00:00+09:00`, and are answered in UTC.
A failure answers `{"status": ..., "errors": [...]}`, where the status is Trac's fault code or the HTTP status, and 0 for a failure that has neither.

`trac_attachments` names the owner with exactly one of `ticket` and `page`, and carries the content as base64 in `content_base64`, because tool arguments and results are JSON text and attachments are often binary.
Its `list` answers the size, time and author of a ticket's attachments only, since TracXMLRPC answers no more than the filenames for a wiki page.
A `put` without `replace` keeps an existing attachment of the same name, and Trac stores the new one under a numbered name such as `a.2.bin`, which `put` answers.
`trac_enums` covers the lists of the ticket fields `type`, `resolution`, `priority` and `severity`, chosen by `kind`.

Some TracXMLRPC methods are left out on purpose.

- `system.multicall` is in the SDK only, because a raw batch can name any method and would let a readonly server express a write.
- `ticket.status.get`, `create`, `update` and `delete` do nothing in the plugin, since the workflow configuration defines the statuses, so only `statuses` lists them.
- `ticket.getAvailableActions` is a deprecated duplicate of `ticket.getActions`, which the `actions` action already calls.
- The `when` argument of `ticket.changeLog` is ignored by the plugin, so `changelog` always answers the whole history.
- `wiki.listLinks` is not implemented by the plugin and always answers an empty list.

## Development

```sh
task check            # type-check everything, warnings are errors
task test             # unit tests
task trac:up          # start the throwaway Trac in compose.yaml on http://localhost:8000
task test:integration # end-to-end tests against it
task trac:reset       # remove it together with its data
```

The throwaway Trac has an administrator `admin` and a user `viewer` that may read but not edit, so a refused write can be tested.

The `keyring`, `schema` and `mcp` modules come from mooncakes as `Omochice/keyring`, `Omochice/schema` and `Omochice/mcp`, which are developed in [moonmoon](https://github.com/Omochice/moonmoon).
The `tty` and `build` packages are copied unchanged from [redmoon](https://github.com/Omochice/redmoon) at 8c13a28, so that they can later be merged into shared modules.
