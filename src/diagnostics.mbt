///|
pub fn diagnose(
  result : FitResult,
  parameters : Array[Parameter],
  jacobian : Array[Array[Double]],
  loss : Loss,
  rank_tolerance? : Double = 1.0e-10,
) -> FitResult {
  let active = active_indices(parameters)
  let warnings = result.warnings.copy()
  if active.is_empty() {
    return result
  }
  let q = match
    qr_factor(
      jacobian,
      Array::make(jacobian.length(), 0.0),
      tolerance=rank_tolerance,
    ) {
    Ok(q) => q
    Err(_) => {
      warnings.push("final Jacobian could not be factored")
      return { ..result, warnings, }
    }
  }
  let gradient = Array::makei(active.length(), fn(column) {
    let terms = Array::makei(result.residuals.length(), fn(row) {
      let (_, w) = loss_value(loss, result.residuals[row])
      jacobian[row][column] * result.residuals[row] * w
    })
    compensated_sum(terms)
  })
  let final_gradient = norm_inf(
    projected_gradient(gradient, result.values, parameters, active),
  )
  let mut covariance : Array[Array[Double]]? = None
  if !finite(final_gradient) {
    warnings.push("final gradient arithmetic overflow; diagnostics unavailable")
    return { ..result, warnings, }
  }
  let mut errors : Array[Double]? = None
  let mut at_bound = false
  for i in active {
    if parameters[i].lower is Some(lo) && result.values[i] <= lo {
      at_bound = true
    }
    if parameters[i].upper is Some(hi) && result.values[i] >= hi {
      at_bound = true
    }
  }
  if q.rank < active.length() {
    warnings.push(
      "rank-deficient Jacobian: parameters are locally unidentifiable",
    )
  }
  if q.condition_proxy is Some(c) && c > 1.0e8 {
    warnings.push("large QR diagonal ratio: poor parameter conditioning")
  }
  if at_bound {
    warnings.push(
      "active parameter bound: symmetric covariance is not reported",
    )
  }
  if loss != Linear {
    warnings.push(
      "robust loss: classical least-squares covariance is not reported",
    )
  }
  let degrees = result.residuals.length() - active.length()
  if degrees <= 0 {
    warnings.push("no residual degrees of freedom: covariance unavailable")
  }
  if result.termination.converged() &&
    !at_bound &&
    loss == Linear &&
    degrees > 0 &&
    q.rank == active.length() {
    if q.inverse_gram() is Some(inv) {
      let variance = match objective(Linear, result.residuals) {
        Ok(v) => 2.0 * v / degrees.to_double()
        Err(_) => -1.0
      }
      if variance >= 0.0 {
        let cov = zeros(parameters.length(), parameters.length())
        let se = Array::make(parameters.length(), 0.0)
        let mut valid = true
        for j = 0; j < active.length(); j = j + 1 {
          let i = active[j]
          for k = 0; k < active.length(); k = k + 1 {
            let l = active[k]
            cov[i][l] = inv[j][k] *
              variance *
              parameters[i].scale *
              parameters[l].scale
            if !finite(cov[i][l]) {
              valid = false
            }
          }
          se[i] = cov[i][i].sqrt()
          if !finite(se[i]) {
            valid = false
          }
        }
        if valid {
          covariance = Some(cov)
          errors = Some(se)
        } else {
          warnings.push("covariance arithmetic overflow")
        }
      }
    }
  }
  {
    ..result,
    gradient_norm: final_gradient,
    rank: q.rank,
    condition_proxy: q.condition_proxy,
    covariance,
    standard_errors: errors,
    warnings,
  }
}

///|
pub fn correlation_matrix(
  covariance : Array[Array[Double]],
) -> Result[Array[Array[Double?]], FitError] {
  let (m, n) = match matrix_shape(covariance) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  if m != n {
    return Err(InvalidData("covariance must be square"))
  }
  for i = 0; i < n; i = i + 1 {
    if covariance[i][i] < 0.0 {
      return Err(InvalidData("negative covariance diagonal"))
    }
  }
  Ok(
    Array::makei(n, fn(i) {
      Array::makei(n, fn(j) {
        let denominator = covariance[i][i].sqrt() * covariance[j][j].sqrt()
        if denominator == 0.0 {
          None
        } else {
          let r = covariance[i][j] / denominator
          if finite(r) {
            Some(r)
          } else {
            None
          }
        }
      })
    }),
  )
}
