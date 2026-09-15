///|
fn show(label : String, result : @fit.CurveResult) -> Unit {
  println("\n" + label)
  println("termination=" + @debug.to_string(result.fit.termination))
  println("values=" + @debug.to_string(result.fit.values))
  println(
    "RMSE=\{result.statistics.rmse}; rank=\{result.fit.rank}; evaluations=\{result.fit.evaluations}",
  )
}

///|
fn main raise {
  let calibration = Array::makei(20, fn(i) {
    let x = i.to_double() / 2.0
    let noise = if i % 2 == 0 { 0.03 } else { -0.03 }
    @fit.observation(x, 1.5 + 2.2 * x + noise)
  })
  let line = @fit.fit_curve(@fit.linear_model(), calibration, [
    @fit.parameter("intercept", 0.0),
    @fit.parameter("slope", 0.0),
  ]).unwrap()
  show("1. instrument calibration", line)
  assert_true(line.fit.termination.converged())
  assert_true((line.fit.values[1] - 2.2).abs() < 0.01)

  let kinetics = Array::makei(30, fn(i) {
    let t = i.to_double() / 4.0
    @fit.observation(t, 8.0 * @math.exp(-0.7 * t) + 0.4)
  })
  let decay = @fit.fit_curve(@fit.exponential_decay_model(), kinetics, [
    @fit.parameter("amplitude", 5.0),
    @fit.parameter("rate", 0.2, lower=0.0),
    @fit.parameter("offset", 0.0),
  ]).unwrap()
  show("2. exponential kinetics", decay)
  assert_true(decay.fit.termination.converged())
  assert_true((decay.fit.values[1] - 0.7).abs() < 1.0e-5)

  let contaminated = Array::makei(30, fn(i) {
    let x = i.to_double() / 5.0
    let outlier = if i == 7 || i == 20 { 15.0 } else { 0.0 }
    @fit.observation(x, 2.0 + 3.0 * x + outlier)
  })
  let ordinary = @fit.fit_curve(@fit.linear_model(), contaminated, [
    @fit.parameter("intercept", 0.0),
    @fit.parameter("slope", 0.0),
  ]).unwrap()
  let robust = @fit.fit_curve(
    @fit.linear_model(),
    contaminated,
    [@fit.parameter("intercept", 0.0), @fit.parameter("slope", 0.0)],
    options={ ..@fit.default_options(), loss: @fit.Huber(0.1), trace: true, },
  ).unwrap()
  show("3. offline robust analysis", robust)
  println(
    "ordinary vs robust intercept: \{ordinary.fit.values[0]} vs \{robust.fit.values[0]}",
  )
  assert_true(
    (robust.fit.values[0] - 2.0).abs() < (ordinary.fit.values[0] - 2.0).abs(),
  )
  println("\nAll three reproducible scenarios passed.")
}
