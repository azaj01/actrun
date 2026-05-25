///|
#cfg(target="native")
async fn run_command(
  cmd : String,
  args : Array[String],
  cwd? : String = ".",
) -> (Int, String, String) {
  let (code, stdout, stderr) = try
    @process.collect_output(cmd, args, cwd~)
  catch {
    _ => return (-1, "", "failed to run command: " + cmd)
  } noraise {
    value => value
  }
  (code, stdout.text(), stderr.text())
}
