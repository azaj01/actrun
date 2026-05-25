///|
// Helper: parse YAML and lint, return formatted diagnostics
fn lint_yaml(yaml : String) -> String {
  let parsed = @ar.parse_workflow_yaml(yaml)
  match parsed.workflow {
    Option::Some(workflow) => {
      let diags = lint_workflow(workflow)
      if diags.length() == 0 {
        "(no diagnostics)"
      } else {
        let lines : Array[String] = []
        for d in diags {
          lines.push(d.format())
        }
        lines.join("\n")
      }
    }
    Option::None => {
      let lines : Array[String] = []
      for e in parsed.errors {
        lines.push("parse error: " + e)
      }
      lines.join("\n")
    }
  }
}

///|
test "snapshot: undefined context reference" {
  let yaml =
    #|name: test
    #|'on': push
    #|jobs:
    #|  build:
    #|    runs-on: ubuntu-latest
    #|    steps:
    #|      - run: echo "${{ foobar.value }}"
  @debug.debug_inspect(
    lint_yaml(yaml),
    content=(
      #|"[build/step0] run: error[undefined-context]: undefined context 'foobar'"
    ),
  )
}

///|
test "snapshot: unknown function call" {
  let yaml =
    #|name: test
    #|'on': push
    #|jobs:
    #|  build:
    #|    runs-on: ubuntu-latest
    #|    steps:
    #|      - run: echo "${{ myFunc(github.ref) }}"
  @debug.debug_inspect(
    lint_yaml(yaml),
    content=(
      #|"[build/step0] run: error[unknown-function]: unknown function 'myFunc'"
    ),
  )
}

///|
test "snapshot: wrong function arity" {
  let yaml =
    #|name: test
    #|'on': push
    #|jobs:
    #|  build:
    #|    runs-on: ubuntu-latest
    #|    steps:
    #|      - run: |
    #|          echo "${{ contains('one') }}"
    #|          echo "${{ startsWith('a', 'b', 'c') }}"
    #|          echo "${{ success('x') }}"
    #|          echo "${{ hashFiles() }}"
  @debug.debug_inspect(
    lint_yaml(yaml),
    content=(
      #|"[build/step0] run: error[wrong-arity]: contains() requires 2 arguments, got 1\n[build/step0] run: error[wrong-arity]: startsWith() requires 2 arguments, got 3\n[build/step0] run: error[wrong-arity]: success() takes no arguments, got 1\n[build/step0] run: error[wrong-arity]: hashFiles() requires at least 1 argument"
    ),
  )
}

///|
test "snapshot: unknown github property" {
  let yaml =
    #|name: test
    #|'on': push
    #|jobs:
    #|  build:
    #|    runs-on: ubuntu-latest
    #|    steps:
    #|      - run: echo "${{ github.nonexistent_field }}"
  @debug.debug_inspect(
    lint_yaml(yaml),
    content=(
      #|"[build/step0] run: warning[unknown-property]: unknown property 'nonexistent_field', known: [\n  \"event_name\",\n  \"ref\",\n  \"ref_name\",\n  \"sha\",\n  \"head_ref\",\n  \"base_ref\",\n  \"repository\",\n  \"repository_owner\",\n  \"actor\",\n  \"workflow\",\n  \"run_id\",\n  \"run_number\",\n  \"run_attempt\",\n  \"action\",\n  \"action_path\",\n  \"workspace\",\n  \"server_url\",\n  \"api_url\",\n  \"graphql_url\",\n  \"token\",\n  \"job\",\n  \"triggering_actor\",\n  \"event\",\n  \"output\",\n]"
    ),
  )
}

///|
test "snapshot: unreachable step" {
  let yaml =
    #|name: test
    #|'on': push
    #|jobs:
    #|  build:
    #|    runs-on: ubuntu-latest
    #|    steps:
    #|      - run: echo ok
    #|      - if: 'false'
    #|        run: echo dead
  @debug.debug_inspect(
    lint_yaml(yaml),
    content=(
      #|"[build/step1] if: warning[unreachable-step]: step is unreachable: condition is always false"
    ),
  )
}

///|
test "snapshot: undefined step reference" {
  let yaml =
    #|name: test
    #|'on': push
    #|jobs:
    #|  build:
    #|    runs-on: ubuntu-latest
    #|    steps:
    #|      - id: setup
    #|        run: echo setup
    #|      - run: echo "${{ steps.missing.outputs.foo }}"
    #|      - run: echo "${{ steps.setup.outputs.ok }}"
  @debug.debug_inspect(
    lint_yaml(yaml),
    content=(
      #|"[build/step1] run: warning[unknown-property]: unknown property 'missing', known: [\"setup\"]\n[build/step1] expression: error[undefined-step-ref]: reference to undefined step 'missing'"
    ),
  )
}

///|
test "snapshot: future step reference" {
  let yaml =
    #|name: test
    #|'on': push
    #|jobs:
    #|  build:
    #|    runs-on: ubuntu-latest
    #|    steps:
    #|      - id: first
    #|        run: echo "${{ steps.second.outputs.x }}"
    #|      - id: second
    #|        run: echo done
  @debug.debug_inspect(
    lint_yaml(yaml),
    content=(
      #|"[build/step0] run: warning[unknown-property]: unknown property 'second', known: []\n[build/step0] expression: error[future-step-ref]: reference to future step 'second' (defined at index 1, current index 0)"
    ),
  )
}

///|
test "snapshot: undefined needs reference" {
  let yaml =
    #|name: test
    #|'on': push
    #|jobs:
    #|  deploy:
    #|    runs-on: ubuntu-latest
    #|    needs: [build, test]
    #|    steps:
    #|      - run: echo deploy
  @debug.debug_inspect(
    lint_yaml(yaml),
    content=(
      #|"[deploy/step-1] needs: error[undefined-needs]: job 'deploy' depends on undefined job 'build'\n[deploy/step-1] needs: error[undefined-needs]: job 'deploy' depends on undefined job 'test'"
    ),
  )
}

///|
test "snapshot: circular dependency" {
  let yaml =
    #|name: test
    #|'on': push
    #|jobs:
    #|  a:
    #|    runs-on: ubuntu-latest
    #|    needs: [b]
    #|    steps:
    #|      - run: echo a
    #|  b:
    #|    runs-on: ubuntu-latest
    #|    needs: [c]
    #|    steps:
    #|      - run: echo b
    #|  c:
    #|    runs-on: ubuntu-latest
    #|    needs: [a]
    #|    steps:
    #|      - run: echo c
  @debug.debug_inspect(
    lint_yaml(yaml),
    content=(
      #|"[a/step-1] needs: error[circular-needs]: circular dependency detected: a -> b -> c -> a"
    ),
  )
}

///|
test "snapshot: unused job outputs" {
  let yaml =
    #|name: test
    #|'on': push
    #|jobs:
    #|  build:
    #|    runs-on: ubuntu-latest
    #|    outputs:
    #|      version: ${{ steps.ver.outputs.version }}
    #|    steps:
    #|      - id: ver
    #|        run: echo "version=1.0" >> $GITHUB_OUTPUT
    #|  deploy:
    #|    runs-on: ubuntu-latest
    #|    needs: [build]
    #|    steps:
    #|      - run: echo "deploying without using outputs"
  @debug.debug_inspect(
    lint_yaml(yaml),
    content=(
      #|"[build/step-1] outputs: warning[unused-outputs]: job 'build' declares outputs but they are not referenced by downstream jobs"
    ),
  )
}

///|
test "snapshot: multiple errors in one workflow" {
  let yaml =
    #|name: test
    #|'on': push
    #|jobs:
    #|  build:
    #|    runs-on: ubuntu-latest
    #|    steps:
    #|      - run: echo "${{ badctx.x }}"
    #|      - run: echo "${{ noSuchFn() }}"
    #|      - if: 'false'
    #|        run: echo dead
    #|  broken:
    #|    runs-on: ubuntu-latest
    #|    needs: [missing]
    #|    steps:
    #|      - run: echo "${{ steps.ghost.outputs.y }}"
  @debug.debug_inspect(
    lint_yaml(yaml),
    content=(
      #|"[build/step0] run: error[undefined-context]: undefined context 'badctx'\n[build/step1] run: error[unknown-function]: unknown function 'noSuchFn'\n[broken/step0] run: warning[unknown-property]: unknown property 'ghost', known: []\n[build/step2] if: warning[unreachable-step]: step is unreachable: condition is always false\n[broken/step0] expression: error[undefined-step-ref]: reference to undefined step 'ghost'\n[broken/step-1] needs: error[undefined-needs]: job 'broken' depends on undefined job 'missing'"
    ),
  )
}

///|
test "snapshot: clean workflow (no errors)" {
  let yaml =
    #|name: test
    #|'on': push
    #|jobs:
    #|  build:
    #|    runs-on: ubuntu-latest
    #|    steps:
    #|      - id: greet
    #|        run: echo "${{ github.actor }}"
    #|      - run: echo "${{ steps.greet.outputs.msg }}"
    #|      - run: echo "${{ contains(github.ref, 'main') }}"
    #|      - if: success()
    #|        run: echo "${{ toJSON(env) }}"
  @debug.debug_inspect(
    lint_yaml(yaml),
    content=(
      #|"(no diagnostics)"
    ),
  )
}

///|
test "snapshot: needs expression type check" {
  let yaml =
    #|name: test
    #|'on': push
    #|jobs:
    #|  build:
    #|    runs-on: ubuntu-latest
    #|    steps:
    #|      - run: echo build
    #|  deploy:
    #|    runs-on: ubuntu-latest
    #|    needs: [build]
    #|    steps:
    #|      - if: needs.build.result == 'success'
    #|        run: echo "${{ needs.build.outputs.version }}"
    #|      - run: echo "${{ needs.unknown_job.result }}"
  @debug.debug_inspect(
    lint_yaml(yaml),
    content=(
      #|"[deploy/step1] run: warning[unknown-property]: unknown property 'unknown_job', known: [\"build\"]"
    ),
  )
}

///|
test "snapshot: job-level if condition error" {
  let yaml =
    #|name: test
    #|'on': push
    #|jobs:
    #|  build:
    #|    runs-on: ubuntu-latest
    #|    if: badcontext.value == 'x'
    #|    steps:
    #|      - run: echo build
  @debug.debug_inspect(
    lint_yaml(yaml),
    content=(
      #|"[build/step-1] if: error[undefined-context]: undefined context 'badcontext'"
    ),
  )
}
