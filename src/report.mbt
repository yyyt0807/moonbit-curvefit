///|
fn markdown_cell(value : String) -> String {
  value
  .replace(old="|", new="\\|")
  .replace(old="\n", new=" ")
  .replace(old="\r", new=" ")
  .replace(old="`", new="'")
}

///|
pub fn markdown_report(result : CurveResult) -> String {
  let out = StringBuilder()
  out.write_string("# CurveFit report\n\n")
  out.write_string("Model: " + markdown_cell(result.model) + "\n\n")
  out.write_string(
    "Termination: \{@debug.to_string(result.fit.termination)}; converged: \{result.fit.termination.converged()}\n\n",
  )
  out.write_string(
    "Observations: \{result.statistics.count}; free parameters: \{result.statistics.free_parameters}; Jacobian rank: \{result.fit.rank}\n\n",
  )
  out.write_string(
    "Objective: \{result.fit.cost}; loss: \{@debug.to_string(result.loss)}; RMSE (unweighted): \{result.statistics.rmse}\n\n",
  )
  out.write_string(
    "Iterations: \{result.fit.iterations}; residual evaluations: \{result.fit.evaluations}; Jacobian evaluations: \{result.fit.jacobian_evaluations}\n\n",
  )
  out.write_string(
    "| Parameter | Estimate | Standard error |\n| --- | ---: | ---: |\n",
  )
  for i = 0; i < result.fit.values.length(); i = i + 1 {
    let se = match result.fit.standard_errors {
      Some(errors) => errors[i].to_string()
      None => "unavailable"
    }
    out.write_string(
      "| " +
      markdown_cell(result.fit.names[i]) +
      " | \{result.fit.values[i]} | " +
      se +
      " |\n",
    )
  }
  out.write_string("\n## Interpretation limits\n\n")
  for warning in result.fit.warnings {
    out.write_string("- " + markdown_cell(warning) + "\n")
  }
  out.write_string(
    "- Standard errors are local linear approximations under independent Gaussian errors and correctly specified relative precision weights.\n",
  )
  out.write_string(
    "- R-squared and information criteria are unweighted descriptive quantities; they do not validate a model or justify clinical decisions.\n",
  )
  out.write_string(
    "- Results are not a diagnosis, dose recommendation, or regulatory validation.\n",
  )
  out.to_string()
}

///|
pub fn prediction_csv(result : CurveResult) -> String {
  let out = StringBuilder()
  out.write_string("x,y,weight,predicted,residual\n")
  for i = 0; i < result.observations.length(); i = i + 1 {
    let o = result.observations[i]
    let predicted = result.predictions[i]
    out.write_string(
      "\{o.x},\{o.y},\{o.weight},\{predicted},\{predicted - o.y}\n",
    )
  }
  out.to_string()
}

///|
fn xml_escape(value : String) -> String {
  value
  .replace(old="&", new="&amp;")
  .replace(old="<", new="&lt;")
  .replace(old=">", new="&gt;")
  .replace(old="\"", new="&quot;")
  .replace(old="'", new="&apos;")
}

///|
/// Static standalone SVG. Predictions connect only measured x, not a continuous model.
pub fn curve_svg(
  result : CurveResult,
  residuals? : Bool = false,
  width? : Int = 800,
  height? : Int = 450,
) -> Result[String, FitError] {
  if width < 200 ||
    height < 200 ||
    width > 4096 ||
    height > 4096 ||
    result.observations.is_empty() ||
    result.observations.length() != result.predictions.length() {
    return Err(InvalidData("invalid SVG dimensions or paired data"))
  }
  let x = result.observations.map(fn(o) { o.x })
  let y = if residuals {
    curve_residuals(result)
  } else {
    result.observations.map(fn(o) { o.y })
  }
  let mut xmin = x[0]
  let mut xmax = x[0]
  let mut ymin = y[0]
  let mut ymax = y[0]
  for i = 0; i < x.length(); i = i + 1 {
    if x[i] < xmin {
      xmin = x[i]
    }
    if x[i] > xmax {
      xmax = x[i]
    }
    if y[i] < ymin {
      ymin = y[i]
    }
    if y[i] > ymax {
      ymax = y[i]
    }
    if !residuals {
      if result.predictions[i] < ymin {
        ymin = result.predictions[i]
      }
      if result.predictions[i] > ymax {
        ymax = result.predictions[i]
      }
    }
  }
  let dx = xmax - xmin
  let dy = ymax - ymin
  if !finite(dx) || !finite(dy) || dx <= 0.0 {
    return Err(InvalidData("SVG needs nondegenerate finite x range"))
  }
  let yscale = if dy == 0.0 { 1.0 } else { dy }
  let px = fn(v) { 55.0 + (v - xmin) / dx * (width - 90).to_double() }
  let py = fn(v) {
    (height - 45).to_double() - (v - ymin) / yscale * (height - 90).to_double()
  }
  let suffix = if residuals { " residuals" } else { " fitted predictions" }
  let title = xml_escape(result.model + suffix)
  let out = StringBuilder()
  out.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \{width} \{height}\" role=\"img\"><title>" +
    title +
    "</title>\n",
  )
  out.write_string(
    "<rect width=\"100%\" height=\"100%\" fill=\"white\"/><text x=\"55\" y=\"25\" font-size=\"16\">" +
    title +
    "</text>\n",
  )
  out.write_string(
    "<path d=\"M55 45 V\{height - 45} H\{width - 35}\" fill=\"none\" stroke=\"#333\"/>\n",
  )
  if !residuals {
    let order = Array::makei(x.length(), fn(i) { i })
    order.sort_by(fn(a, b) { x[a].compare(x[b]) })
    out.write_string(
      "<polyline fill=\"none\" stroke=\"#2563eb\" stroke-width=\"2\" points=\"",
    )
    for i in order {
      out.write_string("\{px(x[i])},\{py(result.predictions[i])} ")
    }
    out.write_string("\"/>\n")
  }
  for i = 0; i < x.length(); i = i + 1 {
    out.write_string(
      "<circle cx=\"\{px(x[i])}\" cy=\"\{py(y[i])}\" r=\"3\" fill=\"#dc2626\"><title>x=\{x[i]}, y=\{y[i]}</title></circle>\n",
    )
  }
  out.write_string(
    "<text x=\"55\" y=\"\{height - 10}\" font-size=\"12\">x range: \{xmin} to \{xmax}; y range: \{ymin} to \{ymax}</text></svg>\n",
  )
  Ok(out.to_string())
}
