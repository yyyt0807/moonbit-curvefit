///|
/// Returns rho(r) and the nonnegative IRLS weight psi(r)/r.
pub fn loss_value(loss : Loss, residual : Double) -> (Double, Double) {
  match loss {
    Linear => (0.5 * residual * residual, 1.0)
    Huber(scale) => {
      let a = residual.abs()
      if a <= scale {
        (0.5 * residual * residual, 1.0)
      } else {
        (scale * (a - 0.5 * scale), scale / a)
      }
    }
    SoftL1(scale) => {
      let u = residual / scale
      let root = norm2([1.0, u])
      // Rationalized expression avoids cancellation near zero.
      (residual * (residual / (root + 1.0)), 1.0 / root)
    }
    Cauchy(scale) => {
      let u = residual / scale
      let root = norm2([1.0, u])
      let logterm = if u.abs() < 1.0e150 {
        0.5 * @math.ln_1p(u * u)
      } else {
        @math.ln(root)
      }
      (scale * scale * logterm, 1.0 / root * (1.0 / root))
    }
  }
}

///|
pub fn objective(
  loss : Loss,
  residuals : Array[Double],
) -> Result[Double, FitError] {
  let values : Array[Double] = []
  for residual in residuals {
    if !finite(residual) {
      return Err(InvalidResidual("nonfinite objective residual"))
    }
    let (cost, _) = loss_value(loss, residual)
    if !finite(cost) {
      return Err(InvalidResidual("objective overflow"))
    }
    values.push(cost)
  }
  let cost = compensated_sum(values)
  if finite(cost) {
    Ok(cost)
  } else {
    Err(InvalidResidual("objective sum overflow"))
  }
}

///|
pub fn robust_linearization(
  loss : Loss,
  residuals : Array[Double],
  jacobian : Array[Array[Double]],
) -> (Array[Double], Array[Array[Double]]) {
  let weights = residuals.map(fn(r) {
    let (_, w) = loss_value(loss, r)
    w.sqrt()
  })
  let r = Array::makei(residuals.length(), fn(i) { residuals[i] * weights[i] })
  let j = Array::makei(jacobian.length(), fn(i) {
    jacobian[i].map(fn(v) { v * weights[i] })
  })
  (r, j)
}
