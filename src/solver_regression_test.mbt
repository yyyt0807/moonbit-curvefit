///|
test "all fixed reports objective without fake free-parameter covariance" {
  let result = solve([parameter("a", 2.0, fixed=true)], fn(p) {
    [p[0] - 1.0, p[0] - 3.0]
  }).unwrap()
  assert_eq(result.termination, AllFixed)
  assert_eq(result.cost, 1.0)
  assert_eq(result.evaluations, 1)
  assert_eq(result.iterations, 0)
  assert_eq(result.covariance, None)
}

///|
test "square exact problem has no residual variance estimate" {
  let result = solve([parameter("a", 0.0)], fn(p) { [p[0] - 2.0] }).unwrap()
  assert_true(result.termination.converged())
  assert_true((result.values[0] - 2.0).abs() < 1.0e-7)
  assert_eq(result.standard_errors, None)
  assert_true(
    result.warnings.contains(
      "no residual degrees of freedom: covariance unavailable",
    ),
  )
}

///|
test "weighted constant estimator matches closed-form weighted mean" {
  let ys = [1.0, 3.0, 9.0]
  let weights = [1.0, 2.0, 1.0]
  let result = solve(
    [parameter("mean", 0.0)],
    fn(p) { ys.map(fn(y) { p[0] - y }) },
    weights~,
  ).unwrap()
  assert_true((result.values[0] - 4.0).abs() < 1.0e-7)
  assert_true((result.residuals[1] - 2.0.sqrt()).abs() < 1.0e-7)
}

///|
test "scaled physical covariance does not depend on parameter scale" {
  let callback : ResidualFn = fn(p) {
    [p[0] - 0.9, p[0] - 1.1, p[0] - 1.0, p[0] - 1.0]
  }
  let a = solve([parameter("a", 0.0)], callback).unwrap()
  let b = solve([parameter("a", 0.0, scale=1000.0)], callback).unwrap()
  assert_true((a.values[0] - b.values[0]).abs() < 1.0e-7)
  assert_true(
    (a.covariance.unwrap()[0][0] - b.covariance.unwrap()[0][0]).abs() < 1.0e-10,
  )
}

///|
test "parameter permutation preserves linear fitted curve" {
  let a = solve([parameter("intercept", 0.0), parameter("slope", 0.0)], fn(p) {
    [
      p[0] - 1.1,
      p[0] + p[1] - 2.9,
      p[0] + 2.0 * p[1] - 5.1,
      p[0] + 3.0 * p[1] - 6.9,
    ]
  }).unwrap()
  let b = solve([parameter("slope", 0.0), parameter("intercept", 0.0)], fn(p) {
    [
      p[1] - 1.1,
      p[1] + p[0] - 2.9,
      p[1] + 2.0 * p[0] - 5.1,
      p[1] + 3.0 * p[0] - 6.9,
    ]
  }).unwrap()
  assert_true((a.values[0] - b.values[1]).abs() < 1.0e-7)
  assert_true((a.values[1] - b.values[0]).abs() < 1.0e-7)
  assert_true((a.cost - b.cost).abs() < 1.0e-12)
}

///|
test "trace records real trial acceptance and monotonically accepted costs" {
  let result = solve(
    [parameter("x", -1.2), parameter("y", 1.0)],
    fn(p) { [10.0 * (p[1] - p[0] * p[0]), 1.0 - p[0]] },
    options={ ..default_options(), trace: true, },
  ).unwrap()
  assert_true(!result.trace.is_empty())
  let mut previous = 1.0e300
  let mut rejected = 0
  for entry in result.trace {
    assert_true(entry.cost <= previous + 1.0e-12)
    if entry.accepted {
      assert_true(entry.trial_cost.unwrap() < entry.cost)
      previous = entry.trial_cost.unwrap()
    } else {
      rejected = rejected + 1
    }
  }
  assert_true(rejected > 0)
}

///|
test "tiny iteration budget never claims convergence" {
  let result = solve(
    [parameter("x", -1.2), parameter("y", 1.0)],
    fn(p) { [10.0 * (p[1] - p[0] * p[0]), 1.0 - p[0]] },
    options={ ..default_options(), max_iterations: 1, },
  ).unwrap()
  assert_eq(result.termination, MaxIterations)
  assert_true(!result.termination.converged())
  assert_eq(result.covariance, None)
}

///|
test "evaluation counts include finite differences but do not exceed budget" {
  for budget in [1, 2, 3, 4, 10, 30] {
    let result = solve(
      [parameter("a", 0.0)],
      fn(p) { [p[0] - 2.0, p[0] - 3.0] },
      options={ ..default_options(), max_evaluations: budget, },
    ).unwrap()
    assert_true(result.evaluations <= budget)
    assert_true(result.evaluations >= 1)
  }
}

///|
test "invalid weights and underdetermined problems fail before linear algebra" {
  let p = [parameter("a", 0.0)]
  let r : ResidualFn = fn(p) { [p[0] - 1.0, p[0] - 2.0] }
  assert_true(solve(p, r, weights=[1.0]) is Err(_))
  assert_true(solve(p, r, weights=[1.0, 0.0]) is Err(_))
  assert_true(solve(p, r, weights=[1.0, -1.0]) is Err(_))
  assert_true(solve(p, r, weights=[1.0, 1.0 / 0.0]) is Err(_))
  assert_true(
    solve([parameter("a", 0.0), parameter("b", 0.0)], fn(p) { [p[0] + p[1]] })
    is Err(_),
  )
  assert_true(solve(p, fn(_) { [] }) is Err(_))
}

///|
test "analytic Jacobian dimensions and nonfinite entries are not accepted" {
  let p = [parameter("a", 0.0)]
  let residual : ResidualFn = fn(p) { [p[0] - 1.0, p[0] - 2.0] }
  assert_true(solve(p, residual, jacobian=fn(_) { [[1.0]] }) is Err(_))
  assert_true(
    solve(p, residual, jacobian=fn(_) { [[1.0, 1.0], [1.0, 1.0]] }) is Err(_),
  )
  assert_true(
    solve(p, residual, jacobian=fn(_) { [[1.0 / 0.0], [1.0]] }) is Err(_),
  )
}

///|
test "nonfinite initial residual and overflowing weighted objective are typed errors" {
  let p = [parameter("a", 0.0)]
  assert_true(solve(p, fn(_) { [0.0 / 0.0] }) is Err(_))
  assert_true(solve(p, fn(_) { [1.0 / 0.0] }) is Err(_))
  assert_true(solve(p, fn(_) { [1.0e300] }) is Err(_))
  assert_true(solve(p, fn(_) { [1.0e100] }, weights=[1.0e300]) is Err(_))
}

///|
test "outward bound blocks one variable but not a feasible coupled descent" {
  let result = solve([parameter("a", 0.0, lower=0.0), parameter("b", 0.0)], fn(
    p,
  ) {
    [p[0] + p[1] - 2.0, p[0] - 4.0 * p[1] + 9.0, p[0] + 1.0]
  }).unwrap()
  assert_true(result.termination.converged())
  assert_true(result.values[0] >= 0.0)
  assert_true(result.cost < 1.0)
}

///|
test "callback cannot mutate solver parameter state" {
  let result = solve([parameter("a", 0.0)], fn(p) {
    let value = p[0]
    p[0] = 999.0
    [value - 2.0, value - 2.0]
  }).unwrap()
  assert_true((result.values[0] - 2.0).abs() < 1.0e-7)
}

///|
test "repeated identical x are preserved as replicates" {
  let data = [
    observation(0.0, 1.0),
    observation(0.0, 1.2),
    observation(1.0, 3.0),
    observation(1.0, 3.2),
  ]
  let result = fit_curve(linear_model(), data, [
    parameter("intercept", 0.0),
    parameter("slope", 0.0),
  ]).unwrap()
  assert_eq(result.observations.length(), 4)
  assert_true((result.fit.values[0] - 1.1).abs() < 1.0e-7)
  assert_true((result.fit.values[1] - 2.0).abs() < 1.0e-7)
}

///|
test "scale invariance of nonlinear exponential amplitude and offset" {
  let x = Array::makei(20, fn(i) { i.to_double() / 5.0 })
  let data = x.map(fn(t) { observation(t, 4.0 * @math.exp(-0.8 * t) + 0.2) })
  let model = exponential_decay_model()
  let a = fit_curve(model, data, [
    parameter("amplitude", 2.0),
    parameter("rate", 0.3),
    parameter("offset", 0.0),
  ]).unwrap()
  let scaled = data.map(fn(o) { observation(o.x, o.y * 10.0) })
  let b = fit_curve(model, scaled, [
    parameter("amplitude", 20.0, scale=10.0),
    parameter("rate", 0.3),
    parameter("offset", 0.0, scale=10.0),
  ]).unwrap()
  assert_true((a.fit.values[1] - b.fit.values[1]).abs() < 1.0e-7)
  assert_true((a.fit.values[0] * 10.0 - b.fit.values[0]).abs() < 1.0e-6)
}
