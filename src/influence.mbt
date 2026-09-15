///|
pub(all) struct ResidualDiagnostic {
  index : Int
  residual : Double
  weighted_residual : Double
  leverage : Double?
  internally_studentized : Double?
  cooks_distance : Double?
} derive(Debug, ToJson)

///|
/// Local linear influence diagnostics, only when classical covariance is available.
pub fn residual_diagnostics(
  model : Model,
  result : CurveResult,
) -> Result[Array[ResidualDiagnostic], FitError] {
  let x = result.observations.map(fn(o) { o.x })
  let r = curve_residuals(result)
  let fit = result.fit
  let out : Array[ResidualDiagnostic] = []
  let variance = if result.statistics.degrees_of_freedom > 0 {
    match objective(Linear, fit.residuals) {
      Ok(cost) => 2.0 * cost / result.statistics.degrees_of_freedom.to_double()
      Err(e) => return Err(e)
    }
  } else {
    0.0
  }
  let gradients = if fit.covariance is Some(_) && variance > 0.0 {
    match model.gradient {
      Some(callback) => Some(x.map(fn(v) { callback(v, fit.values.copy()) }))
      None => {
        let p = Array::makei(fit.values.length(), fn(i) {
          parameter(fit.names[i], fit.values[i])
        })
        match
          numerical_jacobian(
            fn(p) { x.map(fn(v) { (model.prediction)(v, p.copy()) }) },
            p,
          ) {
          Ok(j) => Some(j)
          Err(e) => return Err(e)
        }
      }
    }
  } else {
    None
  }
  for i = 0; i < x.length(); i = i + 1 {
    let weighted = r[i] * result.observations[i].weight.sqrt()
    let mut leverage : Double? = None
    let mut studentized : Double? = None
    let mut cooks : Double? = None
    if gradients is Some(j) && fit.covariance is Some(cov) {
      let cg = match matvec(cov, j[i]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let h = match dot(j[i], cg) {
        Ok(v) => v * result.observations[i].weight / variance
        Err(e) => return Err(e)
      }
      if finite(h) && h >= -1.0e-8 && h <= 1.0 + 1.0e-8 {
        let h = if h < 0.0 { 0.0 } else if h > 1.0 { 1.0 } else { h }
        leverage = Some(h)
        if h < 1.0 - 1.0e-12 {
          let t = weighted / (variance * (1.0 - h)).sqrt()
          let d = t *
            t *
            h /
            (result.statistics.free_parameters.to_double() * (1.0 - h))
          if finite(t) {
            studentized = Some(t)
          }
          if finite(d) {
            cooks = Some(d)
          }
        }
      }
    }
    out.push({
      index: i,
      residual: r[i],
      weighted_residual: weighted,
      leverage,
      internally_studentized: studentized,
      cooks_distance: cooks,
    })
  }
  Ok(out)
}
