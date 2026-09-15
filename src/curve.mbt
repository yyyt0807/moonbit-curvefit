///|
pub(all) struct Observation {
  x : Double
  y : Double
  weight : Double
} derive(Debug, ToJson)

///|
pub fn observation(
  x : Double,
  y : Double,
  weight? : Double = 1.0,
) -> Observation {
  { x, y, weight, }
}

///|
pub(all) struct CurveResult {
  model : String
  observations : Array[Observation]
  predictions : Array[Double]
  fit : FitResult
  statistics : Statistics
  loss : Loss
} derive(Debug, ToJson)

///|
/// Duplicate x are legitimate replicates, not implicitly discarded or averaged.
pub fn validate_observations(
  data : Array[Observation],
) -> Result[Unit, FitError] {
  if data.is_empty() || data.length() > 1000000 {
    return Err(InvalidData("expected 1..1000000 observations"))
  }
  for i = 0; i < data.length(); i = i + 1 {
    let row = data[i]
    if !finite(row.x) ||
      !finite(row.y) ||
      !finite(row.weight) ||
      row.weight <= 0.0 {
      return Err(InvalidData("invalid observation at row " + i.to_string()))
    }
  }
  Ok(())
}

///|
pub fn fit_curve(
  model : Model,
  data : Array[Observation],
  parameters : Array[Parameter],
  options? : Options = default_options(),
  analytic? : Bool = true,
) -> Result[CurveResult, FitError] {
  match validate_observations(data) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if parameters.length() != model.parameter_names.length() {
    return Err(InvalidParameter("model parameter count differs"))
  }
  for i = 0; i < parameters.length(); i = i + 1 {
    if parameters[i].name != model.parameter_names[i] {
      return Err(InvalidParameter("parameter names/order differ from model"))
    }
  }
  let rows = data.copy()
  let residual : ResidualFn = fn(p) {
    rows.map(fn(o) { (model.prediction)(o.x, p.copy()) - o.y })
  }
  let weights = rows.map(fn(o) { o.weight })
  let result = if analytic && model.gradient is Some(gradient) {
    solve(parameters, residual, weights~, options~, jacobian=fn(p) {
      rows.map(fn(o) { gradient(o.x, p.copy()) })
    })
  } else {
    solve(parameters, residual, weights~, options~)
  }
  let fit = match result {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let predictions = match model.predict(rows.map(fn(o) { o.x }), fit.values) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let stats = match
    statistics(
      rows.map(fn(o) { o.y }),
      predictions,
      active_indices(parameters).length(),
    ) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok({
    model: model.name,
    observations: rows,
    predictions,
    fit,
    statistics: stats,
    loss: options.loss,
  })
}

///|
pub fn curve_residuals(result : CurveResult) -> Array[Double] {
  Array::makei(result.observations.length(), fn(i) {
    result.predictions[i] - result.observations[i].y
  })
}
