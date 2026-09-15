///|
pub(all) struct FitRequest {
  model : String
  data : Array[Observation]
  parameters : Array[Parameter]
  options : Options
} derive(Debug)

///|
priv suberror DecodeError {
  DecodeError(String)
}

///|
fn decode_object(value : Json) -> Map[String, Json] raise DecodeError {
  match value {
    Object(o) => o
    _ => raise DecodeError("expected JSON object")
  }
}

///|
fn decode_keys(
  o : Map[String, Json],
  allowed : Array[String],
) -> Unit raise DecodeError {
  for key, _ in o {
    if !allowed.contains(key) {
      raise DecodeError("unknown field: " + key)
    }
  }
}

///|
fn decode_number(
  o : Map[String, Json],
  key : String,
  fallback? : Double,
) -> Double raise DecodeError {
  match o.get(key) {
    Some(Number(v, ..)) =>
      if finite(v) {
        v
      } else {
        raise DecodeError("nonfinite " + key)
      }
    None =>
      match fallback {
        Some(v) => v
        None => raise DecodeError("missing " + key)
      }
    _ => raise DecodeError("expected number: " + key)
  }
}

///|
fn decode_bound(
  o : Map[String, Json],
  key : String,
) -> Double? raise DecodeError {
  match o.get(key) {
    None | Some(Null) => None
    Some(Number(v, ..)) =>
      if finite(v) {
        Some(v)
      } else {
        raise DecodeError("nonfinite bound")
      }
    _ => raise DecodeError("expected number or null: " + key)
  }
}

///|
fn decode_bool(
  o : Map[String, Json],
  key : String,
  fallback : Bool,
) -> Bool raise DecodeError {
  match o.get(key) {
    None => fallback
    Some(True) => true
    Some(False) => false
    _ => raise DecodeError("expected boolean: " + key)
  }
}

///|
fn decode_string(
  o : Map[String, Json],
  key : String,
) -> String raise DecodeError {
  match o.get(key) {
    Some(String(v)) => v
    _ => raise DecodeError("expected string: " + key)
  }
}

///|
fn decode_int(
  o : Map[String, Json],
  key : String,
  fallback : Int,
) -> Int raise DecodeError {
  let value = decode_number(o, key, fallback=fallback.to_double())
  if value < 1.0 || value > 2147483647.0 || @math.floor(value) != value {
    raise DecodeError("expected positive integer: " + key)
  }
  value.to_int()
}

///|
fn decode_options(o : Map[String, Json]) -> Options raise DecodeError {
  decode_keys(o, [
    "max_iterations", "max_evaluations", "gradient_tolerance", "step_tolerance",
    "cost_tolerance", "difference_step", "initial_damping", "rank_tolerance", "loss",
    "loss_scale", "trace",
  ])
  let d = default_options()
  let scale = decode_number(o, "loss_scale", fallback=1.0)
  let loss = match o.get("loss") {
    None | Some(String("linear")) => Loss::Linear
    Some(String("huber")) => Huber(scale)
    Some(String("soft-l1")) => SoftL1(scale)
    Some(String("cauchy")) => Cauchy(scale)
    _ => raise DecodeError("unknown loss; use linear, huber, soft-l1 or cauchy")
  }
  {
    max_iterations: decode_int(o, "max_iterations", d.max_iterations),
    max_evaluations: decode_int(o, "max_evaluations", d.max_evaluations),
    gradient_tolerance: decode_number(
      o,
      "gradient_tolerance",
      fallback=d.gradient_tolerance,
    ),
    step_tolerance: decode_number(
      o,
      "step_tolerance",
      fallback=d.step_tolerance,
    ),
    cost_tolerance: decode_number(
      o,
      "cost_tolerance",
      fallback=d.cost_tolerance,
    ),
    difference_step: decode_number(
      o,
      "difference_step",
      fallback=d.difference_step,
    ),
    initial_damping: decode_number(
      o,
      "initial_damping",
      fallback=d.initial_damping,
    ),
    rank_tolerance: decode_number(
      o,
      "rank_tolerance",
      fallback=d.rank_tolerance,
    ),
    loss,
    trace: decode_bool(o, "trace", false),
  }
}

///|
/// Version 1 request. Unknown fields fail to expose misspelled settings.
pub fn parse_request(text : String) -> Result[FitRequest, FitError] {
  if text.length() > 32000000 {
    return Err(InvalidData("JSON exceeds 32 million code units"))
  }
  try {
    let root = decode_object(@json.parse(text))
    decode_keys(root, ["version", "model", "data", "parameters", "options"])
    if decode_int(root, "version", 1) != 1 {
      raise DecodeError("unsupported request version")
    }
    let model_name = decode_string(root, "model")
    let model = match named_model(model_name) {
      Ok(v) => v
      Err(_) => raise DecodeError("unknown model")
    }
    let raw_data = match root.get("data") {
      Some(Array(v)) => v
      _ => raise DecodeError("data must be an array")
    }
    let data : Array[Observation] = []
    for raw in raw_data {
      let row = decode_object(raw)
      decode_keys(row, ["x", "y", "weight"])
      data.push(
        observation(
          decode_number(row, "x"),
          decode_number(row, "y"),
          weight=decode_number(row, "weight", fallback=1.0),
        ),
      )
    }
    match validate_observations(data) {
      Err(_) => raise DecodeError("invalid observations")
      Ok(_) => ()
    }
    let parameters : Array[Parameter] = match root.get("parameters") {
      None =>
        match initial_parameters(model, data) {
          Ok(p) => p
          Err(_) => raise DecodeError("cannot infer seeds; provide parameters")
        }
      Some(Array(entries)) => {
        let ps : Array[Parameter] = []
        for raw in entries {
          let p = decode_object(raw)
          decode_keys(p, ["name", "initial", "lower", "upper", "fixed", "scale"])
          ps.push(
            parameter(
              decode_string(p, "name"),
              decode_number(p, "initial"),
              lower?=decode_bound(p, "lower"),
              upper?=decode_bound(p, "upper"),
              fixed=decode_bool(p, "fixed", false),
              scale=decode_number(p, "scale", fallback=1.0),
            ),
          )
        }
        ps
      }
      _ => raise DecodeError("parameters must be an array")
    }
    let options = match root.get("options") {
      None => default_options()
      Some(raw) => decode_options(decode_object(raw))
    }
    match validate_parameters(parameters) {
      Err(_) => raise DecodeError("invalid parameter configuration")
      Ok(_) => ()
    }
    match validate_options(options) {
      Err(_) => raise DecodeError("invalid solver options")
      Ok(_) => ()
    }
    if parameters.length() != model.parameter_names.length() {
      raise DecodeError("model parameter count differs")
    }
    for i = 0; i < parameters.length(); i = i + 1 {
      if parameters[i].name != model.parameter_names[i] {
        raise DecodeError("model parameter names/order differ")
      }
    }
    Ok({ model: model_name, data, parameters, options, })
  } catch {
    e => Err(InvalidData(e.to_string()))
  }
}

///|
pub fn run_request(request : FitRequest) -> Result[CurveResult, FitError] {
  let model = match named_model(request.model) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  fit_curve(model, request.data, request.parameters, options=request.options)
}

///|
pub fn result_json(result : CurveResult, pretty? : Bool = true) -> String {
  let object = Json::object(
    Map([
      ("version", Json::number(1.0)),
      ("result", ToJson::to_json(result)),
      ("converged", Json::boolean(result.fit.termination.converged())),
      (
        "statistics_assumption",
        Json::string(
          "descriptive statistics are unweighted; information criteria assume iid Gaussian errors",
        ),
      ),
    ]),
  )
  if pretty {
    object.stringify(indent=2)
  } else {
    object.stringify()
  }
}
