///|
test "named residual terms solve a generic equation system analytically" {
  let result = solve_terms([parameter("x", 1.0), parameter("y", 1.0)], [
    residual_term("sum", fn(p) { p[0] + p[1] - 5.0 }, gradient=fn(_) {
      [1.0, 1.0]
    }),
    residual_term("difference", fn(p) { p[0] - p[1] - 1.0 }, gradient=fn(_) {
      [1.0, -1.0]
    }),
  ]).unwrap()
  assert_true(result.fit.termination.converged())
  assert_true(result.used_analytic_jacobian)
  assert_true((result.fit.values[0] - 3.0).abs() < 1.0e-8)
  assert_true((result.fit.values[1] - 2.0).abs() < 1.0e-8)
  assert_eq(result.terms.map(fn(term) { term.name }), ["sum", "difference"])
  assert_true(result.terms[0].objective_contribution < 1.0e-16)
}

///|
test "missing one term gradient selects complete numerical Jacobian" {
  let result = solve_terms([parameter("x", 0.5, lower=0.0)], [
    residual_term("square", fn(p) { p[0] * p[0] - 4.0 }, gradient=fn(p) {
      [2.0 * p[0]]
    }),
    residual_term("direct", fn(p) { p[0] - 2.0 }),
  ]).unwrap()
  assert_false(result.used_analytic_jacobian)
  assert_true(result.fit.termination.converged())
  assert_true((result.fit.values[0] - 2.0).abs() < 1.0e-7)
}

///|
test "term precision and robust contribution remain auditable" {
  let result = solve_terms(
    [parameter("location", 0.0)],
    [
      residual_term("trusted-a", fn(p) { p[0] - 2.0 }, precision=4.0),
      residual_term("trusted-b", fn(p) { p[0] - 2.0 }, precision=4.0),
      residual_term("outlier", fn(p) { p[0] - 100.0 }, precision=0.01),
    ],
    options={
      ..default_options(),
      loss: Huber(1.0),
      gradient_tolerance: 1.0e-6,
    },
  ).unwrap()
  assert_true(result.fit.termination.converged())
  assert_true(
    (result.terms[0].weighted_residual - 2.0 * result.terms[0].residual).abs() <
    1.0e-12,
  )
  let total = compensated_sum(
    result.terms.map(fn(term) { term.objective_contribution }),
  )
  assert_true((total - result.fit.cost).abs() < 1.0e-10)
}

///|
test "term validation rejects ambiguous and unsafe problem contracts" {
  let p = [parameter("x", 0.0)]
  assert_true(solve_terms(p, []) is Err(_))
  assert_true(solve_terms(p, [residual_term("", fn(_) { 0.0 })]) is Err(_))
  assert_true(
    solve_terms(p, [
      residual_term("same", fn(_) { 0.0 }),
      residual_term("same", fn(_) { 1.0 }),
    ])
    is Err(_),
  )
  assert_true(
    solve_terms(p, [residual_term("bad", fn(_) { 0.0 }, precision=0.0)])
    is Err(_),
  )
  assert_true(
    solve_terms(p, [residual_term("nan", fn(_) { 0.0 / 0.0 })]) is Err(_),
  )
  assert_true(
    solve_terms(p, [
      residual_term("gradient-shape", fn(q) { q[0] }, gradient=fn(_) { [] }),
    ])
    is Err(_),
  )
}
