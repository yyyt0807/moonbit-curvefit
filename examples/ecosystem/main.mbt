///|
fn show(label : String, result : @fit.ResidualProblemResult) -> Unit {
  println("\n" + label)
  println("termination=" + @debug.to_string(result.fit.termination))
  println("values=" + @debug.to_string(result.fit.values))
  println(
    "terms=\{result.terms.length()}; analytic=\{result.used_analytic_jacobian}; cost=\{result.fit.cost}",
  )
}

///|
/// Range observations from radio, ultrasound or game-engine anchors all share
/// the same residual formulation; no curve-shaped x/y table is required.
fn locate_from_ranges() -> Unit raise {
  let anchors = [(0.0, 0.0, 5.0), (8.0, 0.0, 5.0), (4.0, 6.0, 3.0)]
  let terms = anchors.map(fn(anchor) {
    let (ax, ay, distance) = anchor
    @fit.residual_term(
      "anchor-\{ax}-\{ay}",
      fn(p) {
        let dx = p[0] - ax
        let dy = p[1] - ay
        (dx * dx + dy * dy).sqrt() - distance
      },
      gradient=fn(p) {
        let dx = p[0] - ax
        let dy = p[1] - ay
        let predicted = (dx * dx + dy * dy).sqrt()
        [dx / predicted, dy / predicted]
      },
    )
  })
  let result = @fit.solve_terms(
    [
      @fit.parameter("x", 2.0, lower=-100.0, upper=100.0),
      @fit.parameter("y", 2.0, lower=-100.0, upper=100.0),
    ],
    terms,
  ).unwrap()
  show("1. range-based 2D localization", result)
  assert_true(result.fit.termination.converged())
  assert_true((result.fit.values[0] - 4.0).abs() < 1.0e-7)
  assert_true((result.fit.values[1] - 3.0).abs() < 1.0e-7)
}

///|
/// A forward simulator can expose observations as terms without depending on
/// MoonCurveFit's built-in curve catalogue. Here we identify an RC low-pass.
fn identify_rc_response() -> Unit raise {
  let gain = 2.0
  let tau = 0.5
  let frequencies = [0.2, 1.0, 2.0, 5.0, 10.0]
  let terms = frequencies.map(fn(omega) {
    let observed = gain / (1.0 + omega * omega * tau * tau).sqrt()
    @fit.residual_term(
      "omega-\{omega}",
      fn(p) {
        let root = (1.0 + omega * omega * p[1] * p[1]).sqrt()
        p[0] / root - observed
      },
      gradient=fn(p) {
        let square = 1.0 + omega * omega * p[1] * p[1]
        let root = square.sqrt()
        [1.0 / root, -p[0] * omega * omega * p[1] / (square * root)]
      },
    )
  })
  let result = @fit.solve_terms(
    [
      @fit.parameter("gain", 1.0, lower=0.0),
      @fit.parameter("time_constant", 0.2, lower=1.0e-6),
    ],
    terms,
  ).unwrap()
  show("2. forward-model parameter identification", result)
  assert_true(result.fit.termination.converged())
  assert_true((result.fit.values[0] - gain).abs() < 1.0e-7)
  assert_true((result.fit.values[1] - tau).abs() < 1.0e-7)
}

///|
/// Capacity planning uses the same kernel on software telemetry. Bounds prevent
/// a fitted capacity below the largest observed load.
fn fit_service_capacity() -> Unit raise {
  let base = 20.0
  let capacity = 250.0
  let queue = 15.0
  let loads = [10.0, 40.0, 80.0, 120.0, 160.0, 190.0]
  let terms = loads.map(fn(load) {
    let observed = base + queue * load / (capacity - load)
    @fit.residual_term("requests-\{load}", fn(p) {
      p[0] + p[2] * load / (p[1] - load) - observed
    })
  })
  let result = @fit.solve_terms(
    [
      @fit.parameter("base_latency_ms", 10.0, lower=0.0),
      @fit.parameter("capacity_rps", 300.0, lower=200.0),
      @fit.parameter("queue_scale_ms", 10.0, lower=0.0),
    ],
    terms,
    options={ ..@fit.default_options(), gradient_tolerance: 1.0e-6, },
  ).unwrap()
  show("3. service telemetry capacity planning", result)
  assert_true(result.fit.termination.converged())
  assert_false(result.used_analytic_jacobian)
  assert_true((result.fit.values[0] - base).abs() < 1.0e-4)
  assert_true((result.fit.values[1] - capacity).abs() < 1.0e-3)
  assert_true((result.fit.values[2] - queue).abs() < 1.0e-4)
}

///|
fn main raise {
  locate_from_ranges()
  identify_rc_response()
  fit_service_capacity()
  println("\nAll ecosystem-extension scenarios passed.")
}
