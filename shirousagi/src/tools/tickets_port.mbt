///|
/// The Trac operations behind `trac_tickets`.
/// Fields travel as strings because Trac stores every ticket field as text,
/// checkboxes and custom fields included.
pub(open) trait TicketPort {
  async fn query_tickets(Self, query : String) -> Array[Int32] raise @trac.TracError
  async fn get_ticket(Self, id : Int32) -> Json raise @trac.TracError
  async fn ticket_changelog(Self, id : Int32) -> Array[Json] raise @trac.TracError
  async fn ticket_actions(Self, id : Int32) -> Array[Json] raise @trac.TracError
  async fn ticket_fields(Self) -> Json raise @trac.TracError
  async fn recent_ticket_changes(Self, since : String) -> Array[Int32] raise @trac.TracError
  async fn create_ticket(
    Self,
    summary~ : String,
    description~ : String,
    fields~ : Map[String, String],
    notify? : Bool,
  ) -> Int32 raise @trac.TracError
  async fn update_ticket(
    Self,
    id : Int32,
    comment? : String,
    action? : String,
    fields? : Map[String, String],
    ts? : String,
    notify? : Bool,
  ) -> Json raise @trac.TracError
  async fn delete_ticket(Self, id : Int32) -> Unit raise @trac.TracError
}

///|
fn wire_fields(fields : Map[String, String]) -> Map[String, Json] {
  let wire : Map[String, Json] = Map([])
  for key, value in fields {
    wire[key] = Json(value)
  }
  wire
}

///|
pub impl TicketPort for @trac.Trac with fn query_tickets(self, query) {
  self |> @tickets.query(query)
}

///|
pub impl TicketPort for @trac.Trac with fn get_ticket(self, id) {
  self |> @tickets.get(id)
}

///|
pub impl TicketPort for @trac.Trac with fn ticket_changelog(self, id) {
  self |> @tickets.changelog(id)
}

///|
pub impl TicketPort for @trac.Trac with fn ticket_actions(self, id) {
  self |> @tickets.actions(id)
}

///|
pub impl TicketPort for @trac.Trac with fn ticket_fields(self) {
  self |> @tickets.fields()
}

///|
pub impl TicketPort for @trac.Trac with fn recent_ticket_changes(self, since) {
  self |> @tickets.recent_changes(since)
}

///|
pub impl TicketPort for @trac.Trac with fn create_ticket(
  self,
  summary~,
  description~,
  fields~,
  notify?,
) {
  self
  |> @tickets.create(
    summary~,
    description~,
    fields=wire_fields(fields),
    notify?,
  )
}

///|
pub impl TicketPort for @trac.Trac with fn update_ticket(
  self,
  id,
  comment?,
  action?,
  fields?,
  ts?,
  notify?,
) {
  self
  |> @tickets.update(
    id,
    comment?,
    action?,
    fields?=fields.map(wire_fields),
    ts?,
    notify?,
  )
}

///|
pub impl TicketPort for @trac.Trac with fn delete_ticket(self, id) {
  self |> @tickets.delete(id)
}
