///|
test "R squared is unavailable instead of nonfinite when variance is tiny" {
  let stats = statistics(
    [0.0, 1.0e-150, 2.0e-150],
    [1.0e100, 1.0e100, 1.0e100],
    1,
  ).unwrap()
  assert_true(finite(stats.sse))
  assert_eq(stats.r_squared, None)
  assert_eq(stats.adjusted_r_squared, None)
}

///|
test "constant and exact data do not fabricate information criteria" {
  let constant = statistics([3.0, 3.0, 3.0], [3.0, 3.0, 3.0], 1).unwrap()
  assert_eq(constant.r_squared, None)
  assert_eq(constant.aic, None)
  assert_eq(constant.bic, None)
  assert_eq(constant.aicc, None)
  assert_eq(constant.rmse, 0.0)
  let exact = statistics([1.0, 2.0, 3.0], [1.0, 2.0, 3.0], 2).unwrap()
  assert_eq(exact.r_squared, Some(1.0))
  assert_eq(exact.adjusted_r_squared, Some(1.0))
  assert_eq(exact.aic, None)
}

///|
test "information criteria count estimated variance as a parameter" {
  let stats = statistics(
    [0.0, 1.0, 2.0, 3.0, 4.0],
    [0.1, 1.1, 2.1, 3.1, 4.1],
    1,
  ).unwrap()
  let base = 5.0 * @math.ln(stats.sse / 5.0)
  assert_true((stats.aic.unwrap() - base - 4.0).abs() < 1.0e-12)
  assert_true((stats.aicc.unwrap() - stats.aic.unwrap() - 6.0).abs() < 1.0e-12)
  assert_true((stats.bic.unwrap() - base - 2.0 * @math.ln(5.0)).abs() < 1.0e-12)
  assert_eq(stats.degrees_of_freedom, 4)
}

///|
test "descriptive statistics are permutation invariant" {
  let first = statistics([1.0, 2.0, 4.0, 8.0], [1.1, 1.9, 4.2, 7.8], 2).unwrap()
  let second = statistics([8.0, 4.0, 2.0, 1.0], [7.8, 4.2, 1.9, 1.1], 2).unwrap()
  assert_true((first.sse - second.sse).abs() < 1.0e-15)
  assert_true((first.rmse - second.rmse).abs() < 1.0e-15)
  assert_true((first.residual_mean - second.residual_mean).abs() < 1.0e-15)
  assert_eq(first.r_squared, second.r_squared)
}

///|
test "statistics do not hide invalid data or impossible dimensions" {
  assert_true(statistics([], [], 0) is Err(_))
  assert_true(statistics([1.0], [], 0) is Err(_))
  assert_true(statistics([1.0], [1.0], -1) is Err(_))
  assert_true(statistics([1.0 / 0.0], [1.0], 0) is Err(_))
  assert_true(statistics([1.0e308, -1.0e308], [0.0, 0.0], 0) is Err(_))
}
