/// Logs a command's rejection where it happens and returns the error to throw:
/// `throw rejected(.clipNotFound(id))`.
func rejected(_ error: CommandError) -> CommandError {
  // why: the case name alone (no payload) keeps user content out of the log.
  let reason = Mirror(reflecting: error).children.first?.label ?? "\(error)"
  logger.error("command.rejected reason=\(reason, privacy: .public)")
  return error
}
