///|
priv struct Evaluator {
  residual : ResidualFn
  weights : Array[Double]
  mut count : Int
  expected : Int
}

///|
fn Evaluator::evaluate(
  self : Evaluator,
  values : Array[Double],
) -> Result[Array[Double], FitError] {
  self.count = self.count + 1
  // Defensively isolate callback-side writes from solver-owned state.
  let raw = (self.residual)(values.copy()).copy()
  match validate_residuals(raw, Some(self.expected)) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let weighted = Array::makei(raw.length(), fn(i) {
    raw[i] * self.weights[i].sqrt()
  })
  match validate_residuals(weighted, Some(self.expected)) {
    Err(e) => Err(e)
    Ok(_) => Ok(weighted)
  }
}

///|
fn difference_jacobian(
  evaluator : Evaluator,
  values : Array[Double],
  parameters : Array[Parameter],
  active : Array[Int],
  base : Array[Double],
  relative_step : Double,
) -> Result[Array[Array[Double]], FitError] {
  let matrix = zeros(base.length(), active.length())
  for j = 0; j < active.length(); j = j + 1 {
    let i = active[j]
    let p = parameters[i]
    let magnitude = if values[i].abs() > p.scale {
      values[i].abs()
    } else {
      p.scale
    }
    let h = relative_step * magnitude
    let plus = values.copy()
    let minus = values.copy()
    plus[i] = project(values[i] + h, p)
    minus[i] = project(values[i] - h, p)
    let hp = plus[i] - values[i]
    let hm = values[i] - minus[i]
    if !finite(h) || (hp == 0.0 && hm == 0.0) {
      return Err(
        InvalidJacobian("unrepresentable finite-difference step: " + p.name),
      )
    }
    let rp = if hp > 0.0 { evaluator.evaluate(plus) } else { Ok(base) }
    let rm = if hm > 0.0 { evaluator.evaluate(minus) } else { Ok(base) }
    let high = match rp {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let low = match rm {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    for row = 0; row < base.length(); row = row + 1 {
      // Unequal bounded steps use a quadratic three-point derivative.
      let derivative = if hp > 0.0 && hm > 0.0 {
        let left = (base[row] - low[row]) / hm
        let right = (high[row] - base[row]) / hp
        hp / (hp + hm) * left + hm / (hp + hm) * right
      } else if hp > 0.0 {
        (high[row] - base[row]) / hp
      } else {
        (base[row] - low[row]) / hm
      }
      matrix[row][j] = derivative * p.scale
      if !finite(matrix[row][j]) {
        return Err(InvalidJacobian("finite difference overflow: " + p.name))
      }
    }
  }
  Ok(matrix)
}

///|
pub fn analytic_jacobian(
  callback : JacobianFn,
  values : Array[Double],
  parameters : Array[Parameter],
  active : Array[Int],
  weights : Array[Double],
) -> Result[Array[Array[Double]], FitError] {
  let raw = callback(values.copy())
  if raw.length() != weights.length() {
    return Err(InvalidJacobian("wrong Jacobian row count"))
  }
  for row in raw {
    if row.length() != parameters.length() {
      return Err(
        InvalidJacobian("Jacobian requires columns for all parameters"),
      )
    }
    for value in row {
      if !finite(value) {
        return Err(InvalidJacobian("nonfinite analytic derivative"))
      }
    }
  }
  let scaled = Array::makei(raw.length(), fn(row) {
    active.map(fn(i) { raw[row][i] * parameters[i].scale * weights[row].sqrt() })
  })
  for row in scaled {
    for v in row {
      if !finite(v) {
        return Err(InvalidJacobian("scaled Jacobian overflow"))
      }
    }
  }
  Ok(scaled)
}

///|
/// Public derivative checker. Returns columns in physical parameter units.
pub fn numerical_jacobian(
  residual : ResidualFn,
  parameters : Array[Parameter],
  step? : Double = 6.0e-6,
) -> Result[Array[Array[Double]], FitError] {
  match validate_parameters(parameters) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if !finite(step) || step <= 0.0 || step >= 1.0 {
    return Err(InvalidOptions("difference step outside (0,1)"))
  }
  let values = parameters.map(fn(p) { p.initial })
  let base = residual(values.copy()).copy()
  match validate_residuals(base, None) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let ev = {
    residual,
    weights: Array::make(base.length(), 1.0),
    count: 1,
    expected: base.length(),
  }
  let active = active_indices(parameters)
  let out = zeros(base.length(), parameters.length())
  if active.is_empty() {
    return Ok(out)
  }
  let scaled = match
    difference_jacobian(ev, values, parameters, active, base, step) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  for row = 0; row < base.length(); row = row + 1 {
    for j = 0; j < active.length(); j = j + 1 {
      out[row][active[j]] = scaled[row][j] / parameters[active[j]].scale
    }
  }
  Ok(out)
}
