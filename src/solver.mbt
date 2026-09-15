///|
/// Local projected, scaled Levenberg–Marquardt for small dense problems.
pub fn solve(
  parameters : Array[Parameter],
  residual : ResidualFn,
  jacobian? : JacobianFn,
  weights? : Array[Double],
  options? : Options = default_options(),
) -> Result[FitResult, FitError] {
  match validate_parameters(parameters) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match validate_options(options) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let active = active_indices(parameters)
  let mut values = parameters.map(fn(p) { p.initial })
  let first = residual(values.copy()).copy()
  match validate_residuals(first, None) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if first.length() < active.length() {
    return Err(
      InvalidData(
        "underdetermined problem: fewer observations than free parameters",
      ),
    )
  }
  let precision = match weights {
    Some(w) => w.copy()
    None => Array::make(first.length(), 1.0)
  }
  if precision.length() != first.length() {
    return Err(InvalidData("precision weight count differs"))
  }
  for w in precision {
    if !finite(w) || w <= 0.0 {
      return Err(InvalidData("precision weights must be positive finite"))
    }
  }
  let ev : Evaluator = {
    residual,
    weights: precision,
    count: 1,
    expected: first.length(),
  }
  let mut r = Array::makei(first.length(), fn(i) {
    first[i] * precision[i].sqrt()
  })
  let mut cost = match objective(options.loss, r) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let mut damping = options.initial_damping
  let mut growth = 2.0
  let mut iterations = 0
  let mut jac_count = 0
  let mut gradient_norm = 0.0
  let mut termination : Termination = MaxIterations
  let trace : Array[Iteration] = []
  let warnings : Array[String] = []
  if active.is_empty() {
    termination = AllFixed
  } else {
    for iteration = 0
        iteration < options.max_iterations
        iteration = iteration + 1 {
      iterations = iteration + 1
      let required = if jacobian is Some(_) {
        1
      } else {
        2 * active.length() + 1
      }
      if ev.count + required > options.max_evaluations {
        termination = MaxEvaluations
        break
      }
      let j = match jacobian {
        Some(callback) =>
          analytic_jacobian(callback, values, parameters, active, precision)
        None =>
          difference_jacobian(
            ev,
            values,
            parameters,
            active,
            r,
            options.difference_step,
          )
      }
      let j = match j {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      jac_count = jac_count + 1
      let (robust_r, robust_j) = robust_linearization(options.loss, r, j)
      let gradient = Array::makei(active.length(), fn(column) {
        let terms = Array::makei(r.length(), fn(row) {
          robust_j[row][column] * robust_r[row]
        })
        compensated_sum(terms)
      })
      let pg = projected_gradient(gradient, values, parameters, active)
      gradient_norm = norm_inf(pg)
      if !finite(gradient_norm) {
        return Err(InvalidJacobian("gradient arithmetic overflow"))
      }
      if gradient_norm <= options.gradient_tolerance {
        termination = Gradient
        break
      }
      // Freeze outward-facing bound columns; they must not steal a feasible step.
      let working = Array::makei(robust_j.length(), fn(row) {
        Array::makei(active.length(), fn(col) {
          if pg[col] == 0.0 && gradient[col] != 0.0 {
            0.0
          } else {
            robust_j[row][col]
          }
        })
      })
      let augmented = working.map(fn(row) { row.copy() })
      let rhs = robust_r.map(fn(x) { -x })
      for col = 0; col < active.length(); col = col + 1 {
        let column = Array::makei(working.length(), fn(row) {
          working[row][col]
        })
        let length = norm2(column)
        let diagonal = if length > 1.0e-12 { length } else { 1.0 }
        let row = Array::make(active.length(), 0.0)
        row[col] = damping.sqrt() * diagonal
        augmented.push(row)
        rhs.push(0.0)
      }
      let step = match
        qr_factor(augmented, rhs, tolerance=options.rank_tolerance) {
        Ok(q) =>
          match q.solve() {
            Ok(v) => v
            Err(_) => {
              termination = NumericalFailure
              break
            }
          }
        Err(_) => {
          termination = NumericalFailure
          break
        }
      }
      let (candidate, actual) = apply_step(values, parameters, active, step)
      let step_norm = norm2(actual)
      let linear_change = match matvec(robust_j, actual) {
        Ok(v) => v
        Err(_) => {
          termination = NumericalFailure
          break
        }
      }
      let predicted = match dot(gradient, actual) {
        Ok(v) => -v - 0.5 * norm2(linear_change) * norm2(linear_change)
        Err(_) => {
          termination = NumericalFailure
          break
        }
      }
      let trial_r = ev.evaluate(candidate)
      let trial = match trial_r {
        Ok(tr) =>
          match objective(options.loss, tr) {
            Ok(tc) => Some((tr, tc))
            Err(_) => None
          }
        Err(InvalidResidual("callback changed residual count")) =>
          return Err(InvalidResidual("callback changed residual count"))
        Err(_) => None
      }
      let trial_cost = trial.map(fn(pair) { pair.1 })
      let ratio = match trial_cost {
        Some(tc) => if predicted > 0.0 { (cost - tc) / predicted } else { -1.0 }
        None => -1.0
      }
      let accepted = finite(ratio) && ratio > 1.0e-4
      if options.trace {
        trace.push({
          index: iteration,
          cost,
          trial_cost,
          damping,
          gradient_norm,
          step_norm,
          accepted,
        })
      }
      if accepted {
        let (new_r, new_cost) = trial.unwrap()
        let reduction = cost - new_cost
        let old_cost = cost
        values = candidate
        r = new_r
        cost = new_cost
        let factor = 1.0 - @math.pow(2.0 * ratio - 1.0, 3.0)
        let multiplier = if factor > 1.0 / 3.0 { factor } else { 1.0 / 3.0 }
        damping = damping * multiplier
        if damping < 1.0e-18 {
          damping = 1.0e-18
        }
        growth = 2.0
        if reduction <= options.cost_tolerance * (old_cost + 1.0e-30) {
          termination = Cost
          break
        }
        let position_norm = norm2(normalized_values(values, parameters, active))
        if step_norm <=
          options.step_tolerance * (position_norm + options.step_tolerance) {
          termination = Step
          break
        }
      } else {
        damping = damping * growth
        growth = growth * 2.0
        if !finite(damping) || damping > 1.0e30 || step_norm == 0.0 {
          termination = Stalled
          break
        }
      }
    }
  }
  if !termination.converged() {
    warnings.push("solver stopped without convergence")
  }
  warnings.push("local convergence does not establish global optimality")
  let result : FitResult = {
    names: parameters.map(fn(p) { p.name }),
    values,
    residuals: r,
    cost,
    termination,
    iterations,
    evaluations: ev.count,
    jacobian_evaluations: jac_count,
    gradient_norm,
    rank: 0,
    condition_proxy: None,
    covariance: None,
    standard_errors: None,
    warnings,
    trace,
  }
  if active.is_empty() {
    return Ok(result)
  }
  let needed = if jacobian is Some(_) { 0 } else { 2 * active.length() }
  if ev.count + needed > options.max_evaluations {
    warnings.push("evaluation budget prevents final Jacobian diagnostics")
    return Ok(result)
  }
  let final_j = match jacobian {
    Some(callback) =>
      analytic_jacobian(callback, values, parameters, active, precision)
    None =>
      difference_jacobian(
        ev,
        values,
        parameters,
        active,
        r,
        options.difference_step,
      )
  }
  match final_j {
    Ok(j) =>
      Ok(
        diagnose(
          {
            ..result,
            evaluations: ev.count,
            jacobian_evaluations: jac_count + 1,
          },
          parameters,
          j,
          options.loss,
          rank_tolerance=options.rank_tolerance,
        ),
      )
    Err(_) => {
      warnings.push("final Jacobian evaluation failed; covariance unavailable")
      Ok({ ..result, evaluations: ev.count, })
    }
  }
}
