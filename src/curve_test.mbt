///|
test "curve workflow produces paired predictions and physical residual statistics" {
  let data = [
    observation(0.0, 2.0),
    observation(1.0, 5.0),
    observation(2.0, 8.0),
  ]
  let fit = fit_curve(linear_model(), data, [
    parameter("intercept", 0.0),
    parameter("slope", 0.0),
  ]).unwrap()
  assert_true(fit.fit.termination.converged())
  assert_true(fit.statistics.rmse < 1.0e-7)
  assert_true(norm_inf(curve_residuals(fit)) < 1.0e-7)
}

///|
test "curve validates names and positive weights" {
  let data = [observation(0.0, 1.0), observation(1.0, 2.0)]
  assert_true(
    fit_curve(linear_model(), data, [
      parameter("slope", 0.0),
      parameter("intercept", 0.0),
    ])
    is Err(_),
  )
  assert_true(
    validate_observations([observation(0.0, 1.0, weight=0.0)]) is Err(_),
  )
}
