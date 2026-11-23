///|
/// Failure of a Trac call.
/// `Fault` is an RPC error Trac reported, with its code and message;
/// `Http` is an answer whose status is not 200, such as 401 for a rejected login;
/// `Decode` is a 200 answer that is not a JSON-RPC reply;
/// `Transport` is any other failure without an HTTP status (connection, TLS, an unusable endpoint);
/// `InvalidArgument` is a request the SDK refused to send.
/// No case holds the request headers or the password.
#derive(Debug, ToJson)
pub(all) suberror TracError {
  Fault(code~ : Int32, message~ : String)
  Http(status~ : Int32)
  Decode(message~ : String)
  Transport(message~ : String)
  InvalidArgument(message~ : String)
}

///|
pub extend TracError with @debug.Debug::{to_repr}

///|
pub extend TracError with ToJson::{to_json}

///|
/// One line for a person to read; like the cases themselves, it never holds credentials.
pub impl Show for TracError with fn output(self, logger) {
  match self {
    Fault(code~, message~) =>
      logger.write_string("Trac fault \{code}: \{message}")
    Http(status=401) =>
      logger.write_string("HTTP 401: the username or password was rejected")
    Http(status~) => logger.write_string("HTTP \{status}")
    Decode(message~) | Transport(message~) | InvalidArgument(message~) =>
      logger.write_string(message)
  }
}

///|
pub extend TracError with Show::{to_string, output}
