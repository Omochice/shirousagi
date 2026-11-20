///|
/// The subcommand the user asked for, with its options.
#derive(Eq, @debug.Debug)
pub(all) enum Invocation {
  Serve(endpoint~ : String, read_only~ : Bool)
  Login(endpoint~ : String, username~ : String)
  Logout(endpoint~ : String)
  List
}

///|
pub extend Invocation with Eq::{equal, not_equal}

///|
pub extend Invocation with @debug.Debug::{to_repr}

///|
fn endpoint_option() -> @argparse.OptionArg {
  @argparse.OptionArg(
    "endpoint",
    about="Trac project URL, such as https://trac.example.com/project.",
    required=true,
  )
}

///|
fn command() -> @argparse.Command {
  @argparse.Command(
    "shirousagi",
    about="MCP server for Trac.",
    version=@build.version,
    subcommand_required=true,
    arg_required_else_help=true,
    subcommands=[
      @argparse.Command(
        "serve",
        about="Run the stdio MCP server for a Trac project.",
        options=[endpoint_option()],
        flags=[
          @argparse.FlagArg(
            "readonly",
            about="Expose only read actions; create, update, put, and delete are pruned.",
          ),
        ],
      ),
      @argparse.Command(
        "login",
        about="Store the username and password for an endpoint in the OS keyring; the password is read from the terminal, or from stdin when it is not a terminal.",
        options=[
          endpoint_option(),
          @argparse.OptionArg(
            "username",
            about="Trac user to log in as.",
            required=true,
          ),
        ],
      ),
      @argparse.Command(
        "logout",
        about="Delete the stored credential for an endpoint from the OS keyring.",
        options=[endpoint_option()],
      ),
      @argparse.Command(
        "list",
        about="List endpoints that have a stored credential.",
      ),
    ],
  )
}

///|
/// Parses the process arguments, or `argv` when given.
///
/// # Raises
/// `Message` with the parse error, whose text includes the usage; `--help`
/// and `--version` print and exit instead of returning.
pub fn parse_arguments(argv? : ArrayView[String]) -> Invocation raise CliError {
  let matches = command().parse(argv?, env=Map([])) catch {
    error => raise Message("\{error}")
  }
  // The parser already rejects a missing subcommand, a name outside the four
  // above, and a missing required option, so the fallbacks below only
  // complete the Option and the match; no argv reaches them.
  guard matches.subcommand is Some((name, sub)) else {
    raise Message("no subcommand")
  }
  let endpoint = sub.values.get("endpoint").map(values => values[0])
  let username = sub.values.get("username").map(values => values[0])
  match (name, endpoint, username) {
    ("serve", Some(endpoint), _) =>
      Serve(endpoint~, read_only=sub.flags.get("readonly").unwrap_or(false))
    ("login", Some(endpoint), Some(username)) => Login(endpoint~, username~)
    ("logout", Some(endpoint), _) => Logout(endpoint~)
    ("list", _, _) => List
    _ => raise Message("unknown subcommand \{name}")
  }
}
