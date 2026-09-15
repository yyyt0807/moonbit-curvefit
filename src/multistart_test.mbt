///|
test "multistart retains failed attempts and stable winner" {
  let result = solve_multistart(
    [parameter("x", 1.0, lower=0.0)],
    fn(p) { [p[0] * p[0] - 4.0] },
    [[-1.0], [1.0], [5.0]],
  ).unwrap()
  assert_true((result.best.values[0] - 2.0).abs() < 1.0e-6)
  assert_true(result.attempts[0].error is Some(_))
  assert_eq(result.attempts.length(), 3)
  let again = solve_multistart(
    [parameter("x", 1.0, lower=0.0)],
    fn(p) { [p[0] * p[0] - 4.0] },
    [[-1.0], [1.0], [5.0]],
  ).unwrap()
  assert_eq(result.selected, again.selected)
}
