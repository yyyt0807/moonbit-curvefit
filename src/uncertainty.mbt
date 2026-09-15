///|
pub(all) struct JacobianCheck {
  tested_entries : Int
  maximum_absolute_error : Double
  maximum_relative_error : Double
  mismatches : Int
} derive(Debug, ToJson)

///|
/// Explicit checker for custom analytic gradients; not silently run during fitting.
pub fn check_model_gradient(
  model : Model,
  parameters : Array[Parameter],
  x : Array[Double],
  absolute_tolerance? : Double = 1.0e-5,
  relative_tolerance? : Double = 1.0e-4,
) -> Result[JacobianCheck, FitError] {
  if !finite(absolute_tolerance) ||
    !finite(relative_tolerance) ||
    absolute_tolerance <= 0.0 ||
    relative_tolerance <= 0.0 {
    return Err(InvalidOptions("positive gradient-check tolerances required"))
  }
  let callback = match model.gradient {
    Some(g) => g
    None => return Err(InvalidJacobian("model has no analytic gradient"))
  }
  let values = parameters.map(fn(p) { p.initial })
  match model.predict(x, values) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let numeric = match
    numerical_jacobian(
      fn(p) { x.map(fn(v) { (model.prediction)(v, p.copy()) }) },
      parameters,
    ) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let mut tested = 0
  let mut abs_error = 0.0
  let mut rel_error = 0.0
  let mut mismatches = 0
  for row = 0; row < x.length(); row = row + 1 {
    let exact = callback(x[row], values.copy())
    if exact.length() != parameters.length() {
      return Err(InvalidJacobian("gradient column count differs"))
    }
    for column = 0; column < parameters.length(); column = column + 1 {
      if parameters[column].fixed {
        continue
      }
      if !finite(exact[column]) {
        return Err(InvalidJacobian("nonfinite analytic gradient"))
      }
      let difference = (exact[column] - numeric[row][column]).abs()
      let magnitude = if exact[column].abs() > numeric[row][column].abs() {
        exact[column].abs()
      } else {
        numeric[row][column].abs()
      }
      let relative = difference / (absolute_tolerance + magnitude)
      if difference > abs_error {
        abs_error = difference
      }
      if relative > rel_error {
        rel_error = relative
      }
      if difference > absolute_tolerance + relative_tolerance * magnitude {
        mismatches = mismatches + 1
      }
      tested = tested + 1
    }
  }
  Ok({
    tested_entries: tested,
    maximum_absolute_error: abs_error,
    maximum_relative_error: rel_error,
    mismatches,
  })
}

///|
pub(all) struct MeanBand {
  x : Double
  prediction : Double
  standard_error : Double
  lower : Double
  upper : Double
} derive(Debug, ToJson)

///|
/// Delta-method confidence bands for the mean curve, NOT future-observation bands.
pub fn mean_bands(
  model : Model,
  fit : FitResult,
  x : Array[Double],
  multiplier? : Double = 1.96,
) -> Result[Array[MeanBand], FitError] {
  if !finite(multiplier) || multiplier <= 0.0 {
    return Err(InvalidOptions("positive finite band multiplier required"))
  }
  let covariance = match fit.covariance {
    Some(c) => c
    None => return Err(InvalidData("fit covariance unavailable"))
  }
  let (m, n) = match matrix_shape(covariance) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  if m != n || n != fit.values.length() {
    return Err(InvalidData("covariance dimensions differ"))
  }
  let predictions = match model.predict(x, fit.values) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if x.is_empty() {
    return Ok([])
  }
  let numeric = if model.gradient is None {
    let parameters = Array::makei(fit.values.length(), fn(i) {
      parameter(model.parameter_names[i], fit.values[i])
    })
    match
      numerical_jacobian(
        fn(p) { x.map(fn(v) { (model.prediction)(v, p.copy()) }) },
        parameters,
      ) {
      Ok(v) => Some(v)
      Err(e) => return Err(e)
    }
  } else {
    None
  }
  let bands : Array[MeanBand] = []
  for row = 0; row < x.length(); row = row + 1 {
    let g = match model.gradient {
      Some(callback) => callback(x[row], fit.values.copy())
      None => numeric.unwrap()[row]
    }
    if g.length() != n {
      return Err(InvalidJacobian("band gradient dimension differs"))
    }
    let cg = match matvec(covariance, g) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let variance = match dot(g, cg) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    if variance < 0.0 {
      return Err(InvalidData("negative propagated variance"))
    }
    let se = variance.sqrt()
    let lower = predictions[row] - multiplier * se
    let upper = predictions[row] + multiplier * se
    if !finite(se) || !finite(lower) || !finite(upper) {
      return Err(InvalidData("mean band overflow"))
    }
    bands.push({
      x: x[row],
      prediction: predictions[row],
      standard_error: se,
      lower,
      upper,
    })
  }
  Ok(bands)
}
