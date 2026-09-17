///|
/// A scalar observation/equation mismatch. Domain packages can expose these
/// terms without adopting a matrix type or a curve-shaped data model.
pub type ScalarResidual = (Array[Double]) -> Double

///|
/// Physical derivatives in the same full parameter order used by `Parameter`.
pub type ScalarGradient = (Array[Double]) -> Array[Double]

///|
/// Named, independently weighted contribution to a residual problem.
pub(all) struct ResidualTerm {
  name : String
  precision : Double
  evaluate : ScalarResidual
  gradient : ScalarGradient?
}

///|
pub fn residual_term(
  name : String,
  evaluate : ScalarResidual,
  precision? : Double = 1.0,
  gradient? : ScalarGradient,
) -> ResidualTerm {
  { name, precision, evaluate, gradient, }
}

///|
/// Per-term evidence at the selected solution. Objective contribution uses the
/// configured loss in weighted-residual space and sums to the reported cost.
pub(all) struct TermDiagnostic {
  name : String
  precision : Double
  residual : Double
  weighted_residual : Double
  objective_contribution : Double
} derive(Debug, ToJson)

///|
pub(all) struct ResidualProblemResult {
  fit : FitResult
  terms : Array[TermDiagnostic]
  used_analytic_jacobian : Bool
} derive(Debug, ToJson)

///|
fn validate_terms(
  parameters : Array[Parameter],
  terms : Array[ResidualTerm],
) -> Result[Unit, FitError] {
  if terms.is_empty() || terms.length() > 1000000 {
    return Err(InvalidData("expected 1..1000000 residual terms"))
  }
  if parameters.length() > 0 && terms.length() > 1000000 / parameters.length() {
    return Err(
      InvalidData("dense residual Jacobian exceeds one million entries"),
    )
  }
  let names : Map[String, Bool] = Map([])
  for term in terms {
    if term.name.trim().is_empty() {
      return Err(InvalidData("residual term names must be nonempty"))
    }
    if names.contains(term.name) {
      return Err(InvalidData("duplicate residual term name: " + term.name))
    }
    names[term.name] = true
    if !finite(term.precision) || term.precision <= 0.0 {
      return Err(InvalidData("residual term precision must be positive finite"))
    }
  }
  Ok(())
}

///|
/// Solve a general named residual problem. If every term supplies a gradient,
/// the analytic Jacobian is used; otherwise the complete Jacobian is computed
/// numerically so mixed derivative quality cannot silently bias the result.
pub fn solve_terms(
  parameters : Array[Parameter],
  terms : Array[ResidualTerm],
  options? : Options = default_options(),
) -> Result[ResidualProblemResult, FitError] {
  match validate_parameters(parameters) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match validate_options(options) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match validate_terms(parameters, terms) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let mut all_analytic = true
  for term in terms {
    if term.gradient is None {
      all_analytic = false
    }
  }
  let residual : ResidualFn = fn(values) {
    Array::makei(terms.length(), fn(i) { (terms[i].evaluate)(values.copy()) })
  }
  let analytic : JacobianFn? = if all_analytic {
    Some(fn(values) {
      Array::makei(terms.length(), fn(i) {
        terms[i].gradient.unwrap()(values.copy())
      })
    })
  } else {
    None
  }
  let fit = match
    solve(
      parameters,
      residual,
      jacobian?=analytic,
      weights=terms.map(fn(term) { term.precision }),
      options~,
    ) {
    Ok(value) => value
    Err(e) => return Err(e)
  }
  let raw = residual(fit.values)
  match validate_residuals(raw, Some(terms.length())) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let diagnostics : Array[TermDiagnostic] = []
  for i = 0; i < terms.length(); i = i + 1 {
    let weighted = raw[i] * terms[i].precision.sqrt()
    let (contribution, _) = loss_value(options.loss, weighted)
    if !finite(weighted) || !finite(contribution) {
      return Err(InvalidResidual("nonfinite final residual term"))
    }
    diagnostics.push({
      name: terms[i].name,
      precision: terms[i].precision,
      residual: raw[i],
      weighted_residual: weighted,
      objective_contribution: contribution,
    })
  }
  Ok({ fit, terms: diagnostics, used_analytic_jacobian: all_analytic, })
}
