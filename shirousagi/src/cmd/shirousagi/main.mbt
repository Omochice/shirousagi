///|
extern "C" fn exit(code : Int32) = "exit"

///|
async fn run() -> Unit {
  let store = @cli.OsKeyring::new()
  match @cli.parse_arguments() {
    Serve(endpoint~, read_only~) => @cli.run_serve(endpoint, read_only, store)
    Login(endpoint~, username~) => {
      let account = @cli.run_login(endpoint, username~, store, async fn() {
        @tty.read_secret("Trac password: ")
      })
      eprintln("Stored the password of \{username} for \{account}.")
    }
    Logout(endpoint~) => {
      let account = @cli.run_logout(endpoint, store)
      eprintln("Removed the credential for \{account}.")
    }
    List => {
      let endpoints = @cli.run_list(store)
      if endpoints.is_empty() {
        eprintln("No stored credentials.")
      }
      for endpoint in endpoints {
        println(endpoint)
      }
    }
  }
}

///|
async fn main {
  run() catch {
    error => {
      eprintln("error: \{error}")
      exit(1)
    }
  }
}
