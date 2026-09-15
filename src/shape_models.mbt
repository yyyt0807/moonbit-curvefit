///|
/// Overflow-resistant logistic sigmoid.
pub fn sigmoid(value : Double) -> Double {
  if value >= 0.0 {
    1.0 / (1.0 + @math.exp(-value))
  } else {
    let e = @math.exp(value)
    e / (1.0 + e)
  }
}

///|
/// height * exp(-0.5*((x-center)/width)^2) + offset, width > 0.
pub fn gaussian_model() -> Model {
  {
    name: "gaussian",
    parameter_names: ["height", "center", "width", "offset"],
    prediction: fn(x, p) {
      if p[2] <= 0.0 {
        return 0.0 / 0.0
      }
      let z = (x - p[1]) / p[2]
      p[0] * @math.exp(-0.5 * z * z) + p[3]
    },
    gradient: Some(fn(x, p) {
      let z = (x - p[1]) / p[2]
      let e = @math.exp(-0.5 * z * z)
      [e, p[0] * e * z / p[2], p[0] * e * z * z / p[2], 1.0]
    }),
  }
}

///|
/// Four-parameter logistic in input units (not implicit log concentration).
pub fn logistic_model() -> Model {
  {
    name: "logistic",
    parameter_names: ["bottom", "top", "center", "width"],
    prediction: fn(x, p) {
      if p[3] <= 0.0 {
        return 0.0 / 0.0
      }
      p[0] + (p[1] - p[0]) * sigmoid((x - p[2]) / p[3])
    },
    gradient: Some(fn(x, p) {
      let z = (x - p[2]) / p[3]
      let s = sigmoid(z)
      let d = (p[1] - p[0]) * s * (1.0 - s)
      [1.0 - s, s, -d / p[3], -d * z / p[3]]
    }),
  }
}

///|
/// Generalized logistic, positive width and asymmetry. Center is not EC50.
pub fn logistic5_model() -> Model {
  {
    name: "logistic5",
    parameter_names: ["bottom", "top", "center", "width", "asymmetry"],
    prediction: fn(x, p) {
      if p[3] <= 0.0 || p[4] <= 0.0 {
        return 0.0 / 0.0
      }
      let s = sigmoid((x - p[2]) / p[3])
      p[0] + (p[1] - p[0]) * @math.pow(s, p[4])
    },
    gradient: Some(fn(x, p) {
      let z = (x - p[2]) / p[3]
      let s = sigmoid(z)
      let power = @math.pow(s, p[4])
      let d = (p[1] - p[0]) * p[4] * power * (1.0 - s)
      let log_s = if z >= 0.0 {
        -@math.ln_1p(@math.exp(-z))
      } else {
        z - @math.ln_1p(@math.exp(z))
      }
      [
        1.0 - power,
        power,
        -d / p[3],
        -d * z / p[3],
        (p[1] - p[0]) * power * log_s,
      ]
    }),
  }
}
