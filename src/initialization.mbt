///|
/// Heuristic seeds are convenience, never evidence of identifiability.
pub fn initial_parameters(
  model : Model,
  data : Array[Observation],
) -> Result[Array[Parameter], FitError] {
  match validate_observations(data) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let mut xmin = data[0].x
  let mut xmax = data[0].x
  let mut ymin = data[0].y
  let mut ymax = data[0].y
  let mut peak = data[0].x
  let mut left_y = data[0].y
  let mut right_y = data[0].y
  for row in data {
    if row.x < xmin {
      xmin = row.x
      left_y = row.y
    }
    if row.x > xmax {
      xmax = row.x
      right_y = row.y
    }
    if row.y < ymin {
      ymin = row.y
    }
    if row.y > ymax {
      ymax = row.y
      peak = row.x
    }
  }
  let dx = xmax - xmin
  if !finite(dx) || dx <= 0.0 {
    return Err(
      InvalidData("seed estimation requires distinct finite input range"),
    )
  }
  let midpoint = xmin / 2.0 + xmax / 2.0
  let range = ymax - ymin
  let rate = 1.0 / dx
  let positive = 1.0e-12
  let width = if dx / 4.0 > positive { dx / 4.0 } else { positive * 10.0 }
  let half = if midpoint > positive { midpoint } else { 1.0 }
  let values = match model.name {
    "linear" => {
      let design = data.map(fn(o) { [1.0, o.x] })
      let q = match qr_factor(design, data.map(fn(o) { o.y })) {
        Ok(q) => q
        Err(e) => return Err(e)
      }
      match q.solve() {
        Ok(v) => v
        Err(e) => return Err(e)
      }
    }
    "exponential-decay" => [range * @math.exp(rate * xmin), rate, ymin]
    "exponential-growth" => [range * @math.exp(-rate * xmax), rate, ymin]
    "gaussian" => [range, peak, width, ymin]
    "logistic" =>
      if right_y >= left_y {
        [ymin, ymax, midpoint, width]
      } else {
        [ymax, ymin, midpoint, width]
      }
    "logistic5" =>
      if right_y >= left_y {
        [ymin, ymax, midpoint, width, 1.0]
      } else {
        [ymax, ymin, midpoint, width, 1.0]
      }
    "saturation" => [range, half, ymin]
    "hill" => [range, half, 1.0, ymin]
    _ =>
      if model.name.has_prefix("polynomial-") {
        let out = Array::make(model.parameter_names.length(), 0.0)
        out[0] = ymin / 2.0 + ymax / 2.0
        out
      } else {
        return Err(
          InvalidOptions("custom model requires explicit initial parameters"),
        )
      }
  }
  let parameters = Array::makei(values.length(), fn(i) {
    let name = model.parameter_names[i]
    if name == "width" ||
      name == "half" ||
      name == "exponent" ||
      name == "asymmetry" {
      parameter(name, values[i], lower=positive)
    } else {
      parameter(name, values[i])
    }
  })
  match validate_parameters(parameters) {
    Ok(_) => Ok(parameters)
    Err(e) => Err(e)
  }
}
