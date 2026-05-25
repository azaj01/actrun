///|
test "parse string literal" {
  let (expr, errors) = parse_expression("'hello'")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(expr, Literal(LitString("hello")))
}

///|
test "parse number literal" {
  let (expr, errors) = parse_expression("42")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(expr, Literal(LitNumber("42")))
}

///|
test "parse float literal" {
  let (expr, errors) = parse_expression("3.14")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(expr, Literal(LitNumber("3.14")))
}

///|
test "parse negative number" {
  let (expr, errors) = parse_expression("-1")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(expr, Literal(LitNumber("-1")))
}

///|
test "parse bool literals" {
  let (expr1, _) = parse_expression("true")
  @debug.assert_eq(expr1, Literal(LitBool(true)))
  let (expr2, _) = parse_expression("false")
  @debug.assert_eq(expr2, Literal(LitBool(false)))
}

///|
test "parse null literal" {
  let (expr, errors) = parse_expression("null")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(expr, Literal(LitNull))
}

///|
test "parse identifier" {
  let (expr, errors) = parse_expression("github")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(expr, Ident("github"))
}

///|
test "parse property access" {
  let (expr, errors) = parse_expression("github.ref")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(expr, PropertyAccess(Ident("github"), "ref"))
}

///|
test "parse chained property access" {
  let (expr, errors) = parse_expression("steps.build.outputs.version")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(
    expr,
    PropertyAccess(
      PropertyAccess(PropertyAccess(Ident("steps"), "build"), "outputs"),
      "version",
    ),
  )
}

///|
test "parse index access" {
  let (expr, errors) = parse_expression("matrix['os']")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(expr, IndexAccess(Ident("matrix"), Literal(LitString("os"))))
}

///|
test "parse wildcard property" {
  let (expr, errors) = parse_expression("steps.*.outputs")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(
    expr,
    PropertyAccess(PropertyAccess(Ident("steps"), "*"), "outputs"),
  )
}

///|
test "parse function call no args" {
  let (expr, errors) = parse_expression("success()")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(expr, FunctionCall("success", []))
}

///|
test "parse function call one arg" {
  let (expr, errors) = parse_expression("toJSON(env)")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(expr, FunctionCall("toJSON", [Ident("env")]))
}

///|
test "parse function call multiple args" {
  let (expr, errors) = parse_expression("contains('hello world', 'world')")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(
    expr,
    FunctionCall("contains", [
      Literal(LitString("hello world")),
      Literal(LitString("world")),
    ]),
  )
}

///|
test "parse equality" {
  let (expr, errors) = parse_expression("github.event_name == 'push'")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(
    expr,
    BinaryOp(
      OpEq,
      PropertyAccess(Ident("github"), "event_name"),
      Literal(LitString("push")),
    ),
  )
}

///|
test "parse not equal" {
  let (expr, errors) = parse_expression("github.ref != 'refs/heads/main'")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(
    expr,
    BinaryOp(
      OpNeq,
      PropertyAccess(Ident("github"), "ref"),
      Literal(LitString("refs/heads/main")),
    ),
  )
}

///|
test "parse logical and" {
  let (expr, errors) = parse_expression(
    "github.event_name == 'push' && github.ref == 'refs/heads/main'",
  )
  @debug.assert_eq(errors.length(), 0)
  match expr {
    BinaryOp(OpAnd, BinaryOp(OpEq, _, _), BinaryOp(OpEq, _, _)) => ()
    _ => fail("expected And(Eq, Eq), got \{expr}")
  }
}

///|
test "parse logical or" {
  let (expr, errors) = parse_expression("success() || failure()")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(
    expr,
    BinaryOp(OpOr, FunctionCall("success", []), FunctionCall("failure", [])),
  )
}

///|
test "parse not" {
  let (expr, errors) = parse_expression("!cancelled()")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(expr, UnaryOp(OpNot, FunctionCall("cancelled", [])))
}

///|
test "parse grouped expression" {
  let (expr, errors) = parse_expression("(true || false) && true")
  @debug.assert_eq(errors.length(), 0)
  match expr {
    BinaryOp(OpAnd, BinaryOp(OpOr, _, _), Literal(LitBool(true))) => ()
    _ => fail("unexpected: \{expr}")
  }
}

///|
test "parse comparison operators" {
  let (expr, errors) = parse_expression("github.run_number > 10")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(
    expr,
    BinaryOp(
      OpGt,
      PropertyAccess(Ident("github"), "run_number"),
      Literal(LitNumber("10")),
    ),
  )
}

///|
test "parse complex expression" {
  let (expr, errors) = parse_expression(
    "github.event_name == 'push' && contains(github.ref, 'main') || always()",
  )
  @debug.assert_eq(errors.length(), 0)
  // || has lower precedence than &&, so: (push && contains) || always
  match expr {
    BinaryOp(OpOr, BinaryOp(OpAnd, _, _), FunctionCall("always", _)) => ()
    _ => fail("unexpected: \{expr}")
  }
}

///|
test "parse escaped string (doubled quotes)" {
  let (expr, errors) = parse_expression("'it''s'")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(expr, Literal(LitString("it's")))
}

///|
test "parse hashFiles variadic" {
  let (expr, errors) = parse_expression(
    "hashFiles('**/package-lock.json', '**/yarn.lock')",
  )
  @debug.assert_eq(errors.length(), 0)
  match expr {
    FunctionCall("hashFiles", args) => @debug.assert_eq(args.length(), 2)
    _ => fail("unexpected: \{expr}")
  }
}

///|
test "parse format function" {
  let (expr, errors) = parse_expression("format('Hello {0}', github.actor)")
  @debug.assert_eq(errors.length(), 0)
  match expr {
    FunctionCall("format", args) => @debug.assert_eq(args.length(), 2)
    _ => fail("unexpected: \{expr}")
  }
}

///|
test "tokenizer error: bad operator" {
  let (_, errors) = parse_expression("a & b")
  assert_true(errors.length() > 0)
}

///|
test "parse needs access" {
  let (expr, errors) = parse_expression("needs.build.result == 'success'")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(
    expr,
    BinaryOp(
      OpEq,
      PropertyAccess(PropertyAccess(Ident("needs"), "build"), "result"),
      Literal(LitString("success")),
    ),
  )
}

///|
test "parse steps output" {
  let (expr, errors) = parse_expression("steps.test.outputs.coverage")
  @debug.assert_eq(errors.length(), 0)
  @debug.assert_eq(
    expr,
    PropertyAccess(
      PropertyAccess(PropertyAccess(Ident("steps"), "test"), "outputs"),
      "coverage",
    ),
  )
}
