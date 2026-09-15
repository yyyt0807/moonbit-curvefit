///|
test "LM solves linear residuals with analytic Jacobian" {
  let result = solve(
    [parameter("intercept", 0.0), parameter("slope", 0.0)],
    fn(p) { [p[0] - 2.0, p[0] + p[1] - 5.0, p[0] + 2.0 * p[1] - 8.0] },
    jacobian=fn(_) { [[1.0, 0.0], [1.0, 1.0], [1.0, 2.0]] },
  ).unwrap()
  assert_true(result.termination.converged())
  assert_true((result.values[0] - 2.0).abs() < 1.0e-6)
  assert_true((result.values[1] - 3.0).abs() < 1.0e-6)
}

///|
test "LM bounded optimum and budget outcomes" {
  let bounded = solve([parameter("a", 0.5, lower=0.0, upper=1.0)], fn(p) {
    [p[0] - 3.0, p[0] - 3.0]
  }).unwrap()
  assert_eq(bounded.values, [1.0])
  assert_eq(bounded.termination, Gradient)
  let limited = solve([parameter("a", 0.0)], fn(p) { [p[0] - 2.0] }, options={
    ..default_options(),
    max_evaluations: 1,
  }).unwrap()
  assert_eq(limited.termination, MaxEvaluations)
}

///|
test "LM nonlinear Rosenbrock residual benchmark" {
  let result = solve([parameter("x", -1.2), parameter("y", 1.0)], fn(p) {
    [10.0 * (p[1] - p[0] * p[0]), 1.0 - p[0]]
  }).unwrap()
  assert_true(result.termination.converged())
  assert_true((result.values[0] - 1.0).abs() < 1.0e-6)
  assert_true((result.values[1] - 1.0).abs() < 1.0e-6)
}
