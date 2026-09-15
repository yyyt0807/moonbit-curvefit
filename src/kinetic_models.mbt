///|
/// maximum*x/(half+x) + offset. Also Michaelis–Menten / Langmuir.
pub fn saturation_model() -> Model {
  {
    name: "saturation",
    parameter_names: ["maximum", "half", "offset"],
    prediction: fn(x, p) {
      if x < 0.0 || p[1] <= 0.0 {
        return 0.0 / 0.0
      }
      let fraction = if x <= p[1] {
        x / p[1] / (1.0 + x / p[1])
      } else {
        1.0 / (1.0 + p[1] / x)
      }
      p[0] * fraction + p[2]
    },
    gradient: Some(fn(x, p) {
      let fraction = if x <= p[1] {
        x / p[1] / (1.0 + x / p[1])
      } else {
        1.0 / (1.0 + p[1] / x)
      }
      [fraction, -p[0] * fraction * (1.0 - fraction) / p[1], 1.0]
    }),
  }
}

///|
/// Saturation with a Hill exponent, implemented in log space.
pub fn hill_model() -> Model {
  {
    name: "hill",
    parameter_names: ["maximum", "half", "exponent", "offset"],
    prediction: fn(x, p) {
      if x < 0.0 || p[1] <= 0.0 || p[2] <= 0.0 {
        return 0.0 / 0.0
      }
      if x == 0.0 {
        return p[3]
      }
      let log_ratio = @math.ln(x) - @math.ln(p[1])
      p[0] * sigmoid(p[2] * log_ratio) + p[3]
    },
    gradient: Some(fn(x, p) {
      if x == 0.0 {
        return [0.0, 0.0, 0.0, 1.0]
      }
      let log_ratio = @math.ln(x) - @math.ln(p[1])
      let s = sigmoid(p[2] * log_ratio)
      let d = p[0] * s * (1.0 - s)
      [s, -d * p[2] / p[1], d * log_ratio, 1.0]
    }),
  }
}

///|
/// Stable explicit names; unknown models fail instead of silently defaulting.
pub fn named_model(name : String) -> Result[Model, FitError] {
  match name {
    "linear" => Ok(linear_model())
    "exponential-decay" => Ok(exponential_decay_model())
    "exponential-growth" => Ok(exponential_growth_model())
    "gaussian" => Ok(gaussian_model())
    "logistic" => Ok(logistic_model())
    "logistic5" => Ok(logistic5_model())
    "saturation" => Ok(saturation_model())
    "hill" => Ok(hill_model())
    "polynomial-0" => polynomial_model(0)
    "polynomial-1" => polynomial_model(1)
    "polynomial-2" => polynomial_model(2)
    "polynomial-3" => polynomial_model(3)
    "polynomial-4" => polynomial_model(4)
    "polynomial-5" => polynomial_model(5)
    "polynomial-6" => polynomial_model(6)
    _ => Err(InvalidOptions("unknown model: " + name))
  }
}

///|
pub fn model_catalogue() -> Array[String] {
  [
    "linear", "polynomial-2", "polynomial-3", "exponential-decay", "exponential-growth",
    "gaussian", "logistic", "logistic5", "saturation", "hill",
  ]
}
