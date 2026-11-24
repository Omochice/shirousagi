# shirousagi

A [Trac](https://trac.edgewall.org/) MCP server written in MoonBit.

The username and password are kept in the OS credential store rather than in the MCP client's configuration, so the password never appears in an argument list, an environment variable, or a plain-text file.

## Requirements

The Trac project needs the [TracXMLRPC](https://trac-hacks.org/wiki/XmlRpcPlugin) plugin enabled, and the user needs the `XML_RPC` permission.

shirousagi speaks the plugin's JSON-RPC protocol at `<project>/login/rpc` and logs in with HTTP Basic authentication, so the web server in front of Trac has to accept Basic authentication there.

## Usage

Prebuilt binaries for macOS, Linux, and Windows are attached to each [release](https://github.com/Omochice/shirousagi/releases).

### login

`login` prompts for the password of a user on an endpoint, checks it against Trac, and stores it.

```console
$ shirousagi login --endpoint https://trac.example.com/project --username alice
Trac password:
Stored the password of alice for https://trac.example.com/project.
```

The password is read from stdin instead when stdin is not a terminal.

### serve

The MCP client then runs `serve` over stdio.

```json
{
  "mcpServers": {
    "trac": {
      "type": "stdio",
      "command": "shirousagi",
      "args": ["serve", "--endpoint", "https://trac.example.com/project"]
    }
  }
}
```

`--readonly` drops every create, update, put, and delete action.
`shirousagi serve --help` lists every option.

### logout

`logout` deletes the stored credential of an endpoint.

```console
$ shirousagi logout --endpoint https://trac.example.com/project
Removed the credential for https://trac.example.com/project.
```

### list

`list` prints the endpoints that have a stored credential, one per line.

```console
$ shirousagi list
https://trac.example.com/project
```

## Development

See [CONTRIBUTING.md](./CONTRIBUTING.md) for how to develop on this project.

## License

shirousagi is licensed under the zlib License in [LICENSE](./LICENSE).
