///|
/// Unweighted descriptive statistics; information criteria assume iid Gaussian errors.
pub(all) struct Statistics {
  count : Int
  free_parameters : Int
  degrees_of_freedom : Int
  sse : Double
  rmse : Double
  residual_mean : Double
  maximum_error : Double
  r_squared : Double?
  adjusted_r_squared : Double?
  aic : Double?
  aicc : Double?
  bic : Double?
} derive(Debug, ToJson)

///|
pub fn statistics(
  observed : Array[Double],
  predicted : Array[Double],
  free_parameters : Int,
) -> Result[Statistics, FitError] {
  if observed.is_empty() ||
    observed.length() != predicted.length() ||
    free_parameters < 0 {
    return Err(
      InvalidData(
        "statistics require paired nonempty values and nonnegative parameter count",
      ),
    )
  }
  for i = 0; i < observed.length(); i = i + 1 {
    if !finite(observed[i]) || !finite(predicted[i]) {
      return Err(InvalidData("nonfinite statistics input"))
    }
  }
  let n = observed.length()
  let residuals = Array::makei(n, fn(i) { predicted[i] - observed[i] })
  let sse = match objective(Linear, residuals) {
    Ok(v) => 2.0 * v
    Err(e) => return Err(e)
  }
  let mean = compensated_sum(observed.map(fn(x) { x / n.to_double() }))
  let centered = observed.map(fn(y) { y - mean })
  let total = match objective(Linear, centered) {
    Ok(v) => 2.0 * v
    Err(e) => return Err(e)
  }
  let r2 = if total > 0.0 { Some(1.0 - sse / total) } else { None }
  let df = n - free_parameters
  if !finite(sse) || !finite(total) || !finite(mean) {
    return Err(InvalidData("statistics arithmetic overflow"))
  }
  let adjusted = if df > 0 && n > 1 {
    r2.map(fn(r) { 1.0 - (1.0 - r) * (n - 1).to_double() / df.to_double() })
  } else {
    None
  }
  // +1 accounts for the estimated Gaussian variance parameter.
  let k = (free_parameters + 1).to_double()
  let log_likelihood_part = if sse > 0.0 {
    Some(n.to_double() * (@math.ln(sse) - @math.ln(n.to_double())))
  } else {
    None
  }
  let aic = log_likelihood_part.map(fn(v) { v + 2.0 * k })
  let aicc = if n.to_double() > k + 1.0 {
    aic.map(fn(v) { v + 2.0 * k * (k + 1.0) / (n.to_double() - k - 1.0) })
  } else {
    None
  }
  let bic = log_likelihood_part.map(fn(v) { v + k * @math.ln(n.to_double()) })
  Ok({
    count: n,
    free_parameters,
    degrees_of_freedom: df,
    sse,
    rmse: (sse / n.to_double()).sqrt(),
    residual_mean: compensated_sum(residuals.map(fn(v) { v / n.to_double() })),
    maximum_error: norm_inf(residuals),
    r_squared: r2,
    adjusted_r_squared: adjusted,
    aic,
    aicc,
    bic,
  })
}

///|
/// Approximate normal intervals, not exact nonlinear/profile-likelihood intervals.
pub fn normal_intervals(
  result : FitResult,
  multiplier? : Double = 1.96,
) -> Result[Array[(Double, Double)], FitError] {
  if !finite(multiplier) || multiplier <= 0.0 {
    return Err(InvalidOptions("positive finite interval multiplier required"))
  }
  let errors = match result.standard_errors {
    Some(e) => e
    None => return Err(InvalidData("standard errors unavailable for this fit"))
  }
  let intervals : Array[(Double, Double)] = []
  for i = 0; i < result.values.length(); i = i + 1 {
    let low = result.values[i] - multiplier * errors[i]
    let high = result.values[i] + multiplier * errors[i]
    if !finite(low) || !finite(high) {
      return Err(InvalidData("interval overflow"))
    }
    intervals.push((low, high))
  }
  Ok(intervals)
}
