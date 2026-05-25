///|
pub enum Severity {
  Error
  Warning
} derive(Eq, Debug)

///|
pub struct LintDiagnostic {
  severity : Severity
  code : String
  message : String
  job_id : String
  step_index : Int
  field : String
} derive(Eq, Debug)

///|
pub impl Show for Severity with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub impl Show for LintDiagnostic with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub fn LintDiagnostic::format(self : LintDiagnostic) -> String {
  let sev = match self.severity {
    Error => "error"
    Warning => "warning"
  }
  "[\{self.job_id}/step\{self.step_index}] \{self.field}: \{sev}[\{self.code}]: \{self.message}"
}
