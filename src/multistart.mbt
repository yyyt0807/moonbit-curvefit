///|
pub(all) struct Attempt {
  index : Int
  start : Array[Double]
  result : FitResult?
  error : FitError?
} derive(Debug, ToJson)

///|
pub(all) struct MultiStartResult {
  selected : Int
  best : FitResult
  attempts : Array[Attempt]
} derive(Debug, ToJson)

///|
/// Explicit deterministic starts. Converged fits outrank unfinished fits.
pub fn solve_multistart(
  parameters : Array[Parameter],
  residual : ResidualFn,
  starts : Array[Array[Double]],
  jacobian? : JacobianFn,
  weights? : Array[Double],
  options? : Options = default_options(),
) -> Result[MultiStartResult, FitError] {
  match validate_parameters(parameters) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if starts.is_empty() || starts.length() > 64 {
    return Err(InvalidOptions("expected 1..64 starts"))
  }
  let attempts : Array[Attempt] = []
  let mut best : FitResult? = None
  let mut selected = -1
  for index = 0; index < starts.length(); index = index + 1 {
    let start = starts[index].copy()
    let result = if start.length() != parameters.length() {
      Err(InvalidParameter("start dimension differs"))
    } else {
      let ps = Array::makei(parameters.length(), fn(i) {
        { ..parameters[i], initial: start[i], }
      })
      let mut changed_fixed = false
      for i = 0; i < parameters.length(); i = i + 1 {
        if parameters[i].fixed && start[i] != parameters[i].initial {
          changed_fixed = true
        }
      }
      if changed_fixed {
        Err(InvalidParameter("multistart must preserve fixed parameters"))
      } else {
        solve(ps, residual, jacobian?, weights?, options~)
      }
    }
    match result {
      Err(e) => attempts.push({ index, start, result: None, error: Some(e), })
      Ok(fit) => {
        attempts.push({ index, start, result: Some(fit), error: None, })
        let better = match best {
          None => true
          Some(current) =>
            if fit.termination.converged() != current.termination.converged() {
              fit.termination.converged()
            } else {
              fit.cost < current.cost
            }
        }
        if better {
          best = Some(fit)
          selected = index
        }
      }
    }
  }
  match best {
    Some(fit) => Ok({ selected, best: fit, attempts, })
    None =>
      Err(
        InvalidData("all multistart attempts failed input/callback validation"),
      )
  }
}
