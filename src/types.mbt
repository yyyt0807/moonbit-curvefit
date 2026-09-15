///|
/// A residual callback returns unweighted residuals in observation order.
pub type ResidualFn = (Array[Double]) -> Array[Double]

///|
/// Jacobian rows are residuals, columns are full (including fixed) parameters.
pub type JacobianFn = (Array[Double]) -> Array[Array[Double]]

///|
pub(all) struct Parameter {
  name : String
  initial : Double
  lower : Double?
  upper : Double?
  fixed : Bool
  scale : Double
} derive(Debug, ToJson)

///|
pub fn parameter(
  name : String,
  initial : Double,
  lower? : Double,
  upper? : Double,
  fixed? : Bool = false,
  scale? : Double = 1.0,
) -> Parameter {
  { name, initial, lower, upper, fixed, scale, }
}

///|
pub(all) enum Loss {
  Linear
  Huber(Double)
  SoftL1(Double)
  Cauchy(Double)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Options {
  max_iterations : Int
  max_evaluations : Int
  gradient_tolerance : Double
  step_tolerance : Double
  cost_tolerance : Double
  difference_step : Double
  initial_damping : Double
  rank_tolerance : Double
  loss : Loss
  trace : Bool
} derive(Debug, ToJson)

///|
pub fn default_options() -> Options {
  {
    max_iterations: 250,
    max_evaluations: 10000,
    gradient_tolerance: 1.0e-8,
    step_tolerance: 1.0e-9,
    cost_tolerance: 1.0e-10,
    difference_step: 6.0e-6,
    initial_damping: 1.0e-3,
    rank_tolerance: 1.0e-10,
    loss: Linear,
    trace: false,
  }
}

///|
pub(all) enum FitError {
  InvalidParameter(String)
  InvalidOptions(String)
  InvalidData(String)
  InvalidResidual(String)
  InvalidJacobian(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum Termination {
  Gradient
  Step
  Cost
  AllFixed
  MaxIterations
  MaxEvaluations
  Stalled
  NumericalFailure
} derive(Eq, Debug, ToJson)

///|
pub fn Termination::converged(self : Termination) -> Bool {
  match self {
    Gradient | Step | Cost | AllFixed => true
    _ => false
  }
}

///|
pub(all) struct Iteration {
  index : Int
  cost : Double
  trial_cost : Double?
  damping : Double
  gradient_norm : Double
  step_norm : Double
  accepted : Bool
} derive(Debug, ToJson)

///|
pub(all) struct FitResult {
  names : Array[String]
  values : Array[Double]
  residuals : Array[Double]
  cost : Double
  termination : Termination
  iterations : Int
  evaluations : Int
  jacobian_evaluations : Int
  gradient_norm : Double
  rank : Int
  condition_proxy : Double?
  covariance : Array[Array[Double]]?
  standard_errors : Array[Double]?
  warnings : Array[String]
  trace : Array[Iteration]
} derive(Debug, ToJson)

///|
pub fn finite(value : Double) -> Bool {
  value == value && value.abs() <= 1.7976931348623157e308
}

///|
pub fn validate_parameters(
  parameters : Array[Parameter],
) -> Result[Unit, FitError] {
  if parameters.is_empty() || parameters.length() > 64 {
    return Err(InvalidParameter("expected 1..64 parameters"))
  }
  let names : Map[String, Bool] = Map([])
  for p in parameters {
    if p.name.is_empty() || names.contains(p.name) {
      return Err(InvalidParameter("empty or duplicate name: " + p.name))
    }
    names[p.name] = true
    if !finite(p.initial) || !finite(p.scale) || p.scale <= 0.0 {
      return Err(
        InvalidParameter("nonfinite initial or nonpositive scale: " + p.name),
      )
    }
    if p.lower is Some(lo) {
      if !finite(lo) || p.initial < lo {
        return Err(InvalidParameter("invalid lower bound: " + p.name))
      }
    }
    if p.upper is Some(hi) {
      if !finite(hi) || p.initial > hi {
        return Err(InvalidParameter("invalid upper bound: " + p.name))
      }
    }
    if p.lower is Some(lo) && p.upper is Some(hi) && lo >= hi {
      return Err(InvalidParameter("bounds must have positive width: " + p.name))
    }
  }
  Ok(())
}

///|
pub fn validate_options(options : Options) -> Result[Unit, FitError] {
  if options.max_iterations < 1 || options.max_evaluations < 1 {
    return Err(InvalidOptions("positive iteration/evaluation budgets required"))
  }
  for
    value in [
      options.gradient_tolerance,
      options.step_tolerance,
      options.cost_tolerance,
      options.difference_step,
      options.initial_damping,
      options.rank_tolerance,
    ] {
    if !finite(value) || value <= 0.0 {
      return Err(
        InvalidOptions("finite positive tolerances and damping required"),
      )
    }
  }
  if options.rank_tolerance >= 1.0 || options.difference_step >= 1.0 {
    return Err(
      InvalidOptions("rank tolerance and difference step must be below one"),
    )
  }
  let scale = match options.loss {
    Linear => 1.0
    Huber(s) | SoftL1(s) | Cauchy(s) => s
  }
  if !finite(scale) || scale <= 0.0 {
    return Err(InvalidOptions("robust loss scale must be finite and positive"))
  }
  Ok(())
}

///|
pub fn validate_residuals(
  values : Array[Double],
  expected : Int?,
) -> Result[Unit, FitError] {
  if values.is_empty() || values.length() > 1000000 {
    return Err(InvalidResidual("expected 1..1000000 residuals"))
  }
  if expected is Some(n) && values.length() != n {
    return Err(InvalidResidual("callback changed residual count"))
  }
  for value in values {
    if !finite(value) {
      return Err(InvalidResidual("callback returned NaN or infinity"))
    }
  }
  Ok(())
}
