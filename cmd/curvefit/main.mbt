///|
/// Only platform glue: standard C exit. Numerical core has no FFI.
extern "C" fn process_exit(code : Int) = "exit"

///|
fn usage() -> Unit {
  println("curvefit 0.1.0: small dense least-squares")
  println("  models")
  println("  fit-json <request.json> [json|markdown|csv|svg|residual-svg]")
  println(
    "  fit-csv <model> <data.csv> [initial1,initial2,...] [json|markdown|csv|svg|residual-svg]",
  )
  println(
    "Reports go to stdout; redirect explicitly. Exit: 0 converged, 2 input/IO error, 3 nonconverged.",
  )
}

///|
fn emit(result : @fit.CurveResult, format : String) -> Unit {
  match format {
    "json" => println(@fit.result_json(result))
    "markdown" => println(@fit.markdown_report(result))
    "csv" => println(@fit.prediction_csv(result))
    "svg" | "residual-svg" =>
      match @fit.curve_svg(result, residuals=format == "residual-svg") {
        Ok(svg) => println(svg)
        Err(e) => {
          println(@debug.to_string(e))
          process_exit(2)
        }
      }
    _ => {
      println("unknown output format: " + format)
      process_exit(2)
    }
  }
  if !result.fit.termination.converged() {
    process_exit(3)
  }
}

///|
fn main {
  let args = @env.args()
  if args.length() < 2 {
    usage()
    process_exit(2)
    return
  }
  try {
    match args[1] {
      "help" | "--help" => usage()
      "version" | "--version" => println("curvefit 0.1.0")
      "models" =>
        for name in @fit.model_catalogue() {
          println(name)
        }
      "fit-json" => {
        if args.length() < 3 || args.length() > 4 {
          usage()
          process_exit(2)
          return
        }
        let request = @fit.parse_request(@fs.read_file_to_string(args[2]))
        let result = match request {
          Ok(r) => @fit.run_request(r)
          Err(e) => Err(e)
        }
        match result {
          Ok(r) => emit(r, if args.length() == 4 { args[3] } else { "json" })
          Err(e) => {
            println(@debug.to_string(e))
            process_exit(2)
          }
        }
      }
      "fit-csv" => {
        if args.length() < 4 || args.length() > 6 {
          usage()
          process_exit(2)
          return
        }
        let model = match @fit.named_model(args[2]) {
          Ok(m) => m
          Err(e) => {
            println(@debug.to_string(e))
            process_exit(2)
            return
          }
        }
        let data = match @fit.parse_csv(@fs.read_file_to_string(args[3])) {
          Ok(d) => d
          Err(e) => {
            println(@debug.to_string(e))
            process_exit(2)
            return
          }
        }
        let parameters = if args.length() >= 5 && args[4] != "auto" {
          let fields = args[4].split(",").to_array()
          if fields.length() != model.parameter_names.length() {
            println("initial parameter count differs")
            process_exit(2)
            return
          }
          let values : Array[@fit.Parameter] = []
          for i = 0; i < fields.length(); i = i + 1 {
            let number = match @fit.parse_number(fields[i].to_owned()) {
              Ok(v) => v
              Err(e) => {
                println(@debug.to_string(e))
                process_exit(2)
                return
              }
            }
            values.push(@fit.parameter(model.parameter_names[i], number))
          }
          Ok(values)
        } else {
          @fit.initial_parameters(model, data)
        }
        match parameters {
          Ok(p) =>
            match @fit.fit_curve(model, data, p) {
              Ok(r) =>
                emit(r, if args.length() == 6 { args[5] } else { "json" })
              Err(e) => {
                println(@debug.to_string(e))
                process_exit(2)
              }
            }
          Err(e) => {
            println(@debug.to_string(e))
            process_exit(2)
          }
        }
      }
      _ => {
        usage()
        process_exit(2)
      }
    }
  } catch {
    e => {
      println("IO error: " + @debug.to_string(e))
      process_exit(2)
    }
  }
}
