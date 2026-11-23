///|
/// Calls every `(rpc_method, params)` of `calls` in one request and returns their outcomes in the same order,
/// `Err` holding the `Fault` Trac reported for that call alone.
/// Datetimes in the results are ISO 8601 text, as `call` answers them.
///
/// # Raises
/// `TracError` as `call` does when the batch as a whole fails, and `Decode` when the answer does not hold
/// one outcome per call.
///
/// ```mbt check
/// #skip("needs a live Trac")
/// async test {
///   let trac = @trac.new(
///     endpoint="https://trac.example.com",
///     username="alice",
///     password="...",
///   )
///   let outcomes = trac
///     |> @trac.multicall([("ticket.get", [1]), ("ticket.get", [2])])
///   for outcome in outcomes {
///     match outcome {
///       Ok(ticket) => ignore(ticket)
///       Err(error) => ignore(error)
///     }
///   }
/// }
/// ```
pub async fn multicall(
  trac : Trac,
  calls : Array[(String, Array[Json])],
) -> Array[Result[Json, TracError]] raise TracError {
  let batch : Array[Json] = calls.mapi((index, entry) => {
    let (rpc_method, params) = entry
    envelope(rpc_method, params, id=Json(index.to_string()))
  })
  outcomes_of(calls.length(), trac |> call("system.multicall", batch))
}

///|
/// Each entry is checked against the id it was sent with, because pairing outcomes with calls by position alone
/// would hand one call's result to another if Trac ever answered in another order.
fn outcomes_of(
  count : Int32,
  json : Json,
) -> Array[Result[Json, TracError]] raise TracError {
  guard json is Array(entries) && entries.length() == count else {
    raise unexpected("system.multicall")
  }
  entries.mapi((index, entry) => {
    guard entry is { "id": String(id), .. } && id == index.to_string() else {
      raise unexpected("system.multicall")
    }
    guard outcome_of(entry) is Some(outcome) else {
      raise unexpected("system.multicall")
    }
    outcome
  })
}
