///|
test "model checker detects incorrect custom analytic gradient" {
  let good = custom_model("square", ["a"], fn(x, p) { p[0] * x * x }, gradient=fn(
    x,
    _,
  ) {
    [x * x]
  }).unwrap()
  let p = [parameter("a", 2.0)]
  assert_eq(check_model_gradient(good, p, [1.0, 2.0]).unwrap().mismatches, 0)
  let bad = custom_model("square", ["a"], fn(x, p) { p[0] * x * x }, gradient=fn(
    _,
    _,
  ) {
    [1.0]
  }).unwrap()
  assert_eq(check_model_gradient(bad, p, [1.0, 2.0]).unwrap().mismatches, 1)
}

///|
test "empty mean-band input is consistent for numerical custom gradients" {
  let model = custom_model("custom-line", ["intercept", "slope"], fn(x, p) {
    p[0] + p[1] * x
  }).unwrap()
  let result = fit_curve(
    model,
    [
      observation(0.0, 1.1),
      observation(1.0, 2.9),
      observation(2.0, 5.1),
      observation(3.0, 6.9),
    ],
    [parameter("intercept", 0.0), parameter("slope", 0.0)],
  ).unwrap()
  assert_eq(mean_bands(model, result.fit, []).unwrap().length(), 0)
}

///|
test "mean curve bands agree with analytical line variance" {
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
  let band = mean_bands(model, result.fit, [0.0]).unwrap()[0]
  let covariance = result.fit.covariance.unwrap()
  assert_true((band.standard_error - covariance[0][0].sqrt()).abs() < 1.0e-12)
  assert_true(band.lower < band.prediction && band.upper > band.prediction)
  assert_true(
    mean_bands(model, { ..result.fit, covariance: None, }, [0.0]) is Err(_),
  )
}
