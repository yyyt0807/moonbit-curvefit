///|
test "local linear leverages sum to free parameter count" {
  let model = linear_model()
  let data = [
    observation(0.0, 1.1),
    observation(1.0, 2.9),
    observation(2.0, 5.1),
    observation(3.0, 6.9),
  ]
  let result = fit_curve(model, data, [
    parameter("intercept", 0.0),
    parameter("slope", 0.0),
  ]).unwrap()
  let diagnostics = residual_diagnostics(model, result).unwrap()
  let h = diagnostics.map(fn(d) { d.leverage.unwrap() })
  assert_true((compensated_sum(h) - 2.0).abs() < 1.0e-8)
  assert_true((h[0] - 0.7).abs() < 1.0e-8)
  for d in diagnostics {
    assert_true(d.cooks_distance.unwrap() >= 0.0)
  }
}

///|
test "robust fits do not fabricate OLS influence measures" {
  let model = linear_model()
  let data = [
    observation(0.0, 1.1),
    observation(1.0, 2.9),
    observation(2.0, 5.1),
    observation(3.0, 6.9),
  ]
  let result = fit_curve(
    model,
    data,
    [parameter("intercept", 0.0), parameter("slope", 0.0)],
    options={ ..default_options(), loss: Huber(1.0), },
  ).unwrap()
  for d in residual_diagnostics(model, result).unwrap() {
    assert_eq(d.leverage, None)
    assert_eq(d.internally_studentized, None)
  }
}
