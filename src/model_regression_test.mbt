///|
fn recover_model(
  model : Model,
  truth : Array[Double],
  seed : Array[Double],
  x : Array[Double],
) -> Unit raise {
  let y = model.predict(x, truth).unwrap()
  let data = Array::makei(x.length(), fn(i) { observation(x[i], y[i]) })
  let p = Array::makei(seed.length(), fn(i) {
    parameter(model.parameter_names[i], seed[i])
  })
  let check = check_model_gradient(model, p, x).unwrap()
  assert_eq(check.mismatches, 0)
  let analytic = fit_curve(model, data, p).unwrap()
  let numeric = fit_curve(model, data, p, analytic=false).unwrap()
  assert_true(
    analytic.fit.termination.converged(),
    msg=@debug.to_string(analytic.fit),
  )
  assert_true(
    numeric.fit.termination.converged(),
    msg=@debug.to_string(numeric.fit),
  )
  assert_eq(analytic.fit.rank, p.length())
  assert_true(analytic.statistics.rmse < 1.0e-6)
  assert_true(numeric.statistics.rmse < 1.0e-6)
  for i = 0; i < truth.length(); i = i + 1 {
    assert_true(
      (analytic.fit.values[i] - truth[i]).abs() <
      1.0e-4 * (1.0 + truth[i].abs()),
    )
    assert_true(
      (numeric.fit.values[i] - truth[i]).abs() < 1.0e-4 * (1.0 + truth[i].abs()),
    )
  }
}

///|
test "exponential growth recovery and analytic-numerical Jacobian agreement" {
  let x = Array::makei(30, fn(i) { i.to_double() / 10.0 })
  recover_model(
    exponential_growth_model(),
    [2.0, 0.4, 1.0],
    [1.8, 0.35, 0.8],
    x,
  )
}

///|
test "Gaussian calibration peak recovery" {
  let x = Array::makei(41, fn(i) { (i.to_double() - 20.0) / 5.0 })
  recover_model(gaussian_model(), [5.0, 0.5, 0.9, 1.0], [4.0, 0.2, 1.1, 0.8], x)
}

///|
test "logistic increasing and decreasing response recovery" {
  let x = Array::makei(41, fn(i) { (i.to_double() - 20.0) / 3.0 })
  recover_model(logistic_model(), [1.0, 5.0, 0.5, 0.8], [0.8, 4.8, 0.4, 1.0], x)
  recover_model(logistic_model(), [5.0, 1.0, 0.5, 0.8], [4.8, 0.8, 0.4, 1.0], x)
}

///|
test "generalized logistic asymmetric response recovery" {
  let x = Array::makei(61, fn(i) { (i.to_double() - 30.0) / 5.0 })
  recover_model(
    logistic5_model(),
    [1.0, 5.0, 0.5, 0.8, 1.3],
    [0.9, 4.9, 0.4, 0.9, 1.1],
    x,
  )
}

///|
test "Michaelis-Menten and Hill saturation recovery" {
  let x = Array::makei(41, fn(i) { i.to_double() / 4.0 })
  recover_model(saturation_model(), [8.0, 2.0, 0.5], [7.0, 1.5, 0.3], x)
  recover_model(hill_model(), [8.0, 2.0, 1.4, 0.5], [7.0, 1.8, 1.1, 0.3], x)
}

///|
test "polynomial calibration recovers coefficients without normal equations" {
  let x = Array::makei(31, fn(i) { (i.to_double() - 15.0) / 15.0 })
  recover_model(
    polynomial_model(3).unwrap(),
    [1.0, 2.0, -0.5, 0.3],
    [0.0, 0.0, 0.0, 0.0],
    x,
  )
}

///|
test "model numerical domains have explicit typed failures" {
  let nan = 0.0 / 0.0
  let inf = 1.0 / 0.0
  assert_true(linear_model().predict([nan], [1.0, 2.0]) is Err(_))
  assert_true(linear_model().predict([1.0], [inf, 2.0]) is Err(_))
  assert_true(
    exponential_growth_model().predict([1000.0], [1.0, 1.0, 0.0]) is Err(_),
  )
  assert_true(logistic_model().predict([0.0], [0.0, 1.0, 0.0, -1.0]) is Err(_))
  assert_true(
    logistic5_model().predict([0.0], [0.0, 1.0, 0.0, 1.0, 0.0]) is Err(_),
  )
  assert_true(saturation_model().predict([1.0], [1.0, 0.0, 0.0]) is Err(_))
  assert_true(hill_model().predict([1.0], [1.0, 1.0, 0.0, 0.0]) is Err(_))
}

///|
test "Hill remains finite across a wide positive input range" {
  let model = hill_model()
  let values = [10.0, 1.0, 3.0, 0.2]
  let y = model.predict([1.0e-200, 1.0, 1.0e200], values).unwrap()
  assert_true((y[0] - 0.2).abs() < 1.0e-12)
  assert_true((y[1] - 5.2).abs() < 1.0e-12)
  assert_true((y[2] - 10.2).abs() < 1.0e-12)
}

///|
test "fixed offset preserves parameter order and zero uncertainty" {
  let x = Array::makei(20, fn(i) { i.to_double() / 4.0 })
  let model = exponential_decay_model()
  let y = model.predict(x, [4.0, 0.8, 0.5]).unwrap()
  let data = Array::makei(x.length(), fn(i) {
    let noise = if i % 2 == 0 { 0.001 } else { -0.001 }
    observation(x[i], y[i] + noise)
  })
  let result = fit_curve(model, data, [
    parameter("amplitude", 3.0),
    parameter("rate", 0.4),
    parameter("offset", 0.5, fixed=true),
  ]).unwrap()
  assert_eq(result.fit.values[2], 0.5)
  assert_eq(result.fit.standard_errors.unwrap()[2], 0.0)
  assert_eq(result.fit.rank, 2)
}

///|
test "linear recovery across deterministic generated calibrations" {
  for index = 1; index <= 25; index = index + 1 {
    let a = index.to_double() / 3.0 - 4.0
    let b = index.to_double() / 7.0 - 2.0
    let data = Array::makei(12, fn(i) {
      let x = i.to_double() - 5.0
      observation(x, a + b * x)
    })
    let result = fit_curve(linear_model(), data, [
      parameter("intercept", 0.0),
      parameter("slope", 0.0),
    ]).unwrap()
    assert_true(result.fit.termination.converged())
    assert_true((result.fit.values[0] - a).abs() < 1.0e-6)
    assert_true((result.fit.values[1] - b).abs() < 1.0e-6)
  }
}
