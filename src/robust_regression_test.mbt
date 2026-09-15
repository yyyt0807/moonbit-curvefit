///|
test "robust location converges despite one distant outlier" {
  let data = [1.0, 1.0, 1.0, 1.0, 101.0]
  let ordinary = solve([parameter("location", 0.0)], fn(p) {
    data.map(fn(y) { p[0] - y })
  }).unwrap()
  assert_true((ordinary.values[0] - 21.0).abs() < 1.0e-6)
  let robust = solve(
    [parameter("location", 0.0)],
    fn(p) { data.map(fn(y) { p[0] - y }) },
    options={ ..default_options(), loss: Huber(1.0), trace: true, },
  ).unwrap()
  assert_true((robust.values[0] - 1.25).abs() < 1.0e-6)
  assert_true(robust.termination.converged(), msg=@debug.to_string(robust))
  assert_eq(robust.standard_errors, None)
}

///|
test "soft-L1 and Cauchy reduce contaminated-line parameter error" {
  let data = Array::makei(25, fn(i) {
    let outlier = if i == 10 { 100.0 } else { 0.0 }
    observation(i.to_double(), 2.0 + 3.0 * i.to_double() + outlier)
  })
  let model = linear_model()
  let parameters = [parameter("intercept", 0.0), parameter("slope", 0.0)]
  let ordinary = fit_curve(model, data, parameters).unwrap()
  let losses : Array[Loss] = [SoftL1(1.0), Cauchy(1.0), Huber(1.0)]
  for loss in losses {
    let robust = fit_curve(model, data, parameters, options={
      ..default_options(),
      loss,
    }).unwrap()
    assert_true(
      (robust.fit.values[0] - 2.0).abs() < (ordinary.fit.values[0] - 2.0).abs(),
    )
    assert_true(
      (robust.fit.values[1] - 3.0).abs() < (ordinary.fit.values[1] - 3.0).abs(),
    )
    assert_eq(robust.fit.covariance, None)
  }
}

///|
test "loss influence agrees with objective finite difference" {
  let losses : Array[Loss] = [Linear, Huber(2.0), SoftL1(2.0), Cauchy(2.0)]
  for loss in losses {
    for r in [-5.0, -0.1, 0.1, 5.0] {
      let step = 1.0e-5
      let (high, _) = loss_value(loss, r + step)
      let (low, _) = loss_value(loss, r - step)
      let (_, weight) = loss_value(loss, r)
      assert_true(((high - low) / (2.0 * step) - r * weight).abs() < 1.0e-7)
    }
  }
}

///|
test "robust linearization quadratic agrees near zero" {
  let losses : Array[Loss] = [Huber(1.0), SoftL1(1.0), Cauchy(1.0)]
  for loss in losses {
    let (cost, weight) = loss_value(loss, 1.0e-8)
    assert_true((cost - 0.5e-16).abs() < 1.0e-30)
    assert_true((weight - 1.0).abs() < 1.0e-15)
  }
}
