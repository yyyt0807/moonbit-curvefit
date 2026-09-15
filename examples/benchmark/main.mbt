///|
/// Deterministic workload. Measure wall-clock externally: this example deliberately
/// avoids platform timers so exactly the same numerical workload runs on all targets.
fn run_decay(count : Int, analytic : Bool) -> (Int, Int, Double) {
  let data = Array::makei(count, fn(i) {
    let x = 8.0 * i.to_double() / (count - 1).to_double()
    let noise = 0.003 * @math.sin(i.to_double())
    @fit.observation(x, 6.0 * @math.exp(-0.45 * x) + 0.8 + noise)
  })
  let result = @fit.fit_curve(
    @fit.exponential_decay_model(),
    data,
    [
      @fit.parameter("amplitude", 4.0, scale=5.0),
      @fit.parameter("rate", 0.2, lower=0.0, scale=0.5),
      @fit.parameter("offset", 0.0),
    ],
    analytic~,
    options={ ..@fit.default_options(), gradient_tolerance: 1.0e-6, },
  ).unwrap()
  if !result.fit.termination.converged() {
    abort("benchmark decay failed: " + @debug.to_string(result.fit.termination))
  }
  if (result.fit.values[1] - 0.45).abs() > 0.001 {
    abort("benchmark decay accuracy regression")
  }
  (result.fit.iterations, result.fit.evaluations, result.statistics.rmse)
}

///|
fn run_peak(count : Int) -> (Int, Int, Double) {
  let model = @fit.gaussian_model()
  let truth = [4.0, 0.7, 1.2, 0.3]
  let data = Array::makei(count, fn(i) {
    let x = -5.0 + 10.0 * i.to_double() / (count - 1).to_double()
    @fit.observation(x, (model.prediction)(x, truth) + 0.001 * @math.cos(x))
  })
  let result = @fit.fit_curve(
    model,
    data,
    [
      @fit.parameter("height", 3.0),
      @fit.parameter("center", 0.0),
      @fit.parameter("width", 2.0, lower=0.01),
      @fit.parameter("offset", 0.0),
    ],
    options={ ..@fit.default_options(), gradient_tolerance: 1.0e-6, },
  ).unwrap()
  if !result.fit.termination.converged() {
    abort("benchmark peak did not converge")
  }
  if (result.fit.values[1] - 0.7).abs() > 0.001 {
    abort("benchmark peak center regression")
  }
  (result.fit.iterations, result.fit.evaluations, result.statistics.rmse)
}

///|
fn run_outliers(count : Int) -> (Int, Int, Double) {
  let data = Array::makei(count, fn(i) {
    let x = i.to_double() / count.to_double()
    let noise = if i % 31 == 0 { 2.0 } else { 0.002 * @math.sin(x * 100.0) }
    @fit.observation(x, 1.0 + 2.0 * x + noise)
  })
  let result = @fit.fit_curve(
    @fit.linear_model(),
    data,
    [@fit.parameter("intercept", 0.0), @fit.parameter("slope", 0.0)],
    options={
      ..@fit.default_options(),
      loss: @fit.Huber(0.02),
      gradient_tolerance: 1.0e-5,
    },
  ).unwrap()
  if !result.fit.termination.converged() {
    abort("benchmark robust regression did not converge")
  }
  if (result.fit.values[0] - 1.0).abs() > 0.01 {
    abort("benchmark robust intercept regression")
  }
  (result.fit.iterations, result.fit.evaluations, result.statistics.rmse)
}

///|
fn emit(label : String, count : Int, result : (Int, Int, Double)) -> Unit {
  let (iterations, evaluations, rmse) = result
  println("\{label},\{count},\{iterations},\{evaluations},\{rmse}")
}

///|
fn main {
  println(
    "workload,observations,iterations,residual_evaluations,unweighted_rmse",
  )
  for count in [100, 1000, 10000] {
    emit("decay-analytic", count, run_decay(count, true))
    emit("decay-numeric", count, run_decay(count, false))
    emit("gaussian-analytic", count, run_peak(count))
    emit("line-huber", count, run_outliers(count))
  }
}
