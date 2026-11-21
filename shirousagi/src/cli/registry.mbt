///|
/// Every tool the server exposes for `mode`, bound to `trac`.
pub fn registered_tools(
  trac : @trac.Trac,
  mode : @tools.Mode,
) -> Array[@mcp.Tool] {
  [
    @tools.tickets_tool(trac, mode),
    @tools.wiki_tool(trac, mode),
    @tools.milestones_tool(trac, mode),
    @tools.components_tool(trac, mode),
    @tools.attachments_tool(trac, mode),
    @tools.search_tool(trac),
    @tools.server_info_tool(trac),
  ]
}

///|
/// The MCP server `serve` runs, kept apart from stdio so a test can drive it
/// over an in-memory pipe.
pub fn build_server(trac : @trac.Trac, read_only : Bool) -> @mcp.Server {
  let mode : @tools.Mode = if read_only { Readonly } else { Full }
  @mcp.Server::new(
    name="shirousagi",
    version=@build.version,
    tools=registered_tools(trac, mode),
    on_invalid=@tools.on_invalid,
  )
}
