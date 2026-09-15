///|
test "full-rank noisy line has covariance and physical standard errors" {
  let result = solve([parameter("a", 0.0, scale=3.0), parameter("b", 0.0)], fn(
    p,
  ) {
    [
      p[0] - 2.1,
      p[0] + p[1] - 4.9,
      p[0] + 2.0 * p[1] - 8.1,
      p[0] + 3.0 * p[1] - 10.9,
    ]
  }).unwrap()
  assert_eq(result.rank, 2)
  assert_true(result.standard_errors.unwrap()[0] > 0.0)
  let correlation = correlation_matrix(result.covariance.unwrap()).unwrap()
  assert_true((correlation[0][0].unwrap() - 1.0).abs() < 1.0e-12)
}

///|
test "rank deficiency and robust covariance exclusions" {
  let rank = solve([parameter("a", 0.0), parameter("b", 0.0)], fn(p) {
    [p[0] + p[1] - 3.0, 2.0 * (p[0] + p[1] - 3.0), 3.0 * (p[0] + p[1] - 3.0)]
  }).unwrap()
  assert_eq(rank.rank, 1)
  assert_eq(rank.covariance, None)
  let robust = solve(
    [parameter("a", 0.0)],
    fn(p) { [p[0] - 1.0, p[0] - 2.0] },
    options={ ..default_options(), loss: Huber(1.0), },
  ).unwrap()
  assert_eq(robust.covariance, None)
}
