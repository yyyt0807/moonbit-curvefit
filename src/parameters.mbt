///|
pub fn active_indices(parameters : Array[Parameter]) -> Array[Int] {
  let indices : Array[Int] = []
  for i = 0; i < parameters.length(); i = i + 1 {
    if !parameters[i].fixed {
      indices.push(i)
    }
  }
  indices
}

///|
pub fn project(value : Double, p : Parameter) -> Double {
  let mut x = value
  if p.lower is Some(lo) && x < lo {
    x = lo
  }
  if p.upper is Some(hi) && x > hi {
    x = hi
  }
  x
}

///|
/// Only feasible descent directions contribute to the stopping gradient.
pub fn projected_gradient(
  gradient : Array[Double],
  values : Array[Double],
  parameters : Array[Parameter],
  active : Array[Int],
) -> Array[Double] {
  Array::makei(active.length(), fn(j) {
    let i = active[j]
    let p = parameters[i]
    let g = gradient[j]
    if p.lower is Some(lo) && values[i] <= lo && g > 0.0 {
      0.0
    } else if p.upper is Some(hi) && values[i] >= hi && g < 0.0 {
      0.0
    } else {
      g
    }
  })
}

///|
/// Steps are in scale-normalized active coordinates.
pub fn apply_step(
  values : Array[Double],
  parameters : Array[Parameter],
  active : Array[Int],
  step : Array[Double],
) -> (Array[Double], Array[Double]) {
  let out = values.copy()
  let actual = Array::make(active.length(), 0.0)
  for j = 0; j < active.length(); j = j + 1 {
    let i = active[j]
    out[i] = project(values[i] + step[j] * parameters[i].scale, parameters[i])
    actual[j] = (out[i] - values[i]) / parameters[i].scale
  }
  (out, actual)
}

///|
pub fn normalized_values(
  values : Array[Double],
  parameters : Array[Parameter],
  active : Array[Int],
) -> Array[Double] {
  active.map(fn(i) { values[i] / parameters[i].scale })
}
