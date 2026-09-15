///|
pub type PredictionFn = (Double, Array[Double]) -> Double

///|
pub type GradientFn = (Double, Array[Double]) -> Array[Double]

///|
/// Custom models use the same protocol as the convenience catalogue.
pub(all) struct Model {
  name : String
  parameter_names : Array[String]
  prediction : PredictionFn
  gradient : GradientFn?
}

///|
pub fn custom_model(
  name : String,
  names : Array[String],
  prediction : PredictionFn,
  gradient? : GradientFn,
) -> Result[Model, FitError] {
  let parameters = names.map(fn(n) { parameter(n, 0.0) })
  match validate_parameters(parameters) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if name.is_empty() {
    return Err(InvalidData("empty model name"))
  }
  Ok({ name, parameter_names: names.copy(), prediction, gradient, })
}

///|
pub fn linear_model() -> Model {
  {
    name: "linear",
    parameter_names: ["intercept", "slope"],
    prediction: fn(x, p) { p[0] + p[1] * x },
    gradient: Some(fn(x, _) { [1.0, x] }),
  }
}

///|
/// Horner polynomial evaluation, degrees 0..12. Center and scale x externally.
pub fn polynomial_model(degree : Int) -> Result[Model, FitError] {
  if degree < 0 || degree > 12 {
    return Err(InvalidOptions("polynomial degree must be 0..12"))
  }
  let names = Array::makei(degree + 1, fn(i) { "c" + i.to_string() })
  Ok({
    name: "polynomial-" + degree.to_string(),
    parameter_names: names,
    prediction: fn(x, p) {
      let mut y = p[degree]
      for i = degree - 1; i >= 0; i = i - 1 {
        y = y * x + p[i]
      }
      y
    },
    gradient: Some(fn(x, _) {
      let out = Array::make(degree + 1, 1.0)
      for i = 1; i <= degree; i = i + 1 {
        out[i] = out[i - 1] * x
      }
      out
    }),
  })
}

///|
/// amplitude * exp(-rate*x) + offset; positive rate gives decay.
pub fn exponential_decay_model() -> Model {
  {
    name: "exponential-decay",
    parameter_names: ["amplitude", "rate", "offset"],
    prediction: fn(x, p) { p[0] * @math.exp(-p[1] * x) + p[2] },
    gradient: Some(fn(x, p) {
      let e = @math.exp(-p[1] * x)
      [e, -x * p[0] * e, 1.0]
    }),
  }
}

///|
pub fn exponential_growth_model() -> Model {
  {
    name: "exponential-growth",
    parameter_names: ["amplitude", "rate", "offset"],
    prediction: fn(x, p) { p[0] * @math.exp(p[1] * x) + p[2] },
    gradient: Some(fn(x, p) {
      let e = @math.exp(p[1] * x)
      [e, x * p[0] * e, 1.0]
    }),
  }
}

///|
/// Validated batch evaluation. Invalid model domains return a typed error.
pub fn Model::predict(
  self : Model,
  x : Array[Double],
  values : Array[Double],
) -> Result[Array[Double], FitError] {
  if values.length() != self.parameter_names.length() {
    return Err(InvalidParameter("model parameter count differs"))
  }
  for v in values {
    if !finite(v) {
      return Err(InvalidParameter("nonfinite model parameter"))
    }
  }
  let y : Array[Double] = []
  for input in x {
    if !finite(input) {
      return Err(InvalidData("nonfinite model input"))
    }
    let prediction = (self.prediction)(input, values.copy())
    if !finite(prediction) {
      return Err(InvalidData("model outside numerical domain"))
    }
    y.push(prediction)
  }
  Ok(y)
}
