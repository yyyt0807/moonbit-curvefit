///|
test "statistics handles constant response and zero residual variance" {
  let s = statistics([2.0, 2.0, 2.0], [2.0, 2.0, 2.0], 1).unwrap()
  assert_eq(s.r_squared, None)
  assert_eq(s.aic, None)
  assert_eq(s.rmse, 0.0)
  let line = statistics([1.0, 2.0, 3.0], [1.1, 2.1, 3.1], 2).unwrap()
  assert_true(line.r_squared.unwrap() > 0.98)
  assert_eq(line.aicc, None)
  assert_true(statistics([], [], 0) is Err(_))
}
