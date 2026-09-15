///|
test "CSV whitespace scientific notation and roundtrip precision" {
  let csv = " y , x , weight \n 2.5e-3 , -1.25e2 , 2 \n 3.125 , 1e-10 , 1.25 \n"
  let data = parse_csv(csv).unwrap()
  assert_eq(data[0].x, -125.0)
  assert_eq(data[0].y, 0.0025)
  assert_eq(data[1].weight, 1.25)
  let restored = parse_csv(observations_csv(data).unwrap()).unwrap()
  assert_eq(restored[1].x, data[1].x)
  assert_eq(restored[1].y, data[1].y)
}

///|
test "header-only empty and incorrect schema CSV fails" {
  for
    input in [
      "", "\n\r\n", "x,y", "input,response\n1,2", "x,y,z\n1,2,3", "x,y,weight\n1,2,-3",
      "x,y\n1e999,2",
    ] {
    assert_true(parse_csv(input) is Err(_))
  }
}

///|
test "quoted numeric CSV follows strict field boundary rules" {
  assert_eq(parse_csv("\"x\",\"y\"\n \"1\" , \"2\" ").unwrap()[0].y, 2.0)
  for
    input in [
      "x,y\n1\"2,3", "x,y\n\"1\"x,2", "x,y\n\"1\"\"2\",3", "x,y\n1,", "x,y\n1,\"2\n3\"",
    ] {
    assert_true(parse_csv(input) is Err(_))
  }
}

///|
test "request accepts explicit fixed parameters null bounds and loss selection" {
  let text = "{\"model\":\"linear\",\"data\":[{\"x\":0,\"y\":1},{\"x\":1,\"y\":4},{\"x\":2,\"y\":7}],\"parameters\":[{\"name\":\"intercept\",\"initial\":1,\"fixed\":true},{\"name\":\"slope\",\"initial\":1,\"lower\":0,\"upper\":null,\"scale\":2}],\"options\":{\"loss\":\"huber\",\"loss_scale\":1,\"max_iterations\":100}}"
  let request = parse_request(text).unwrap()
  assert_eq(request.parameters[0].fixed, true)
  assert_eq(request.parameters[1].upper, None)
  assert_eq(request.options.loss, Huber(1.0))
  let result = run_request(request).unwrap()
  assert_eq(result.fit.values[0], 1.0)
  assert_true((result.fit.values[1] - 3.0).abs() < 1.0e-6)
}

///|
test "request numeric type confusion missing fields and fractional budgets fail" {
  let inputs = [
    "{\"model\":\"linear\",\"data\":[{\"x\":0,\"y\":\"1\"}]}", "{\"model\":\"linear\",\"data\":[{\"x\":0}]}",
    "{\"model\":\"linear\",\"data\":[{\"x\":0,\"y\":1},{\"x\":1,\"y\":2}],\"options\":{\"max_iterations\":1.5}}",
    "{\"model\":\"linear\",\"data\":[{\"x\":0,\"y\":1},{\"x\":1,\"y\":2}],\"options\":{\"trace\":1}}",
    "{\"model\":\"linear\",\"data\":[{\"x\":0,\"y\":1},{\"x\":1,\"y\":2}],\"options\":{\"loss\":\"made-up\"}}",
    "{\"model\":\"linear\",\"data\":[{\"x\":0,\"y\":1},{\"x\":1,\"y\":2}],\"options\":{\"rank_tolerance\":0}}",
  ]
  for text in inputs {
    assert_true(parse_request(text) is Err(_))
  }
}

///|
test "request rejects unknown observation fields instead of silently losing data" {
  assert_true(
    parse_request(
      "{\"model\":\"linear\",\"data\":[{\"x\":0,\"y\":1,\"weigth\":2}]}",
    )
    is Err(_),
  )
  assert_true(
    parse_request("{\"model\":\"nonexistent\",\"data\":[]}") is Err(_),
  )
  assert_true(parse_request("{\"model\":\"linear\",\"data\":{}}") is Err(_))
}

///|
test "output JSON explicitly separates convergence from parameter estimates" {
  let request = parse_request(
    "{\"model\":\"linear\",\"data\":[{\"x\":0,\"y\":1},{\"x\":1,\"y\":3},{\"x\":2,\"y\":5}],\"parameters\":[{\"name\":\"intercept\",\"initial\":0},{\"name\":\"slope\",\"initial\":0}],\"options\":{\"max_iterations\":1}}",
  ).unwrap()
  let result = run_request(request).unwrap()
  assert_true(!result.fit.termination.converged())
  let parsed = @json.parse(result_json(result))
  match parsed {
    Object(o) => assert_eq(o.get("converged"), Some(Json::boolean(false)))
    _ => fail("expected object report")
  }
}

///|
test "Markdown and SVG escape custom model names" {
  let model = custom_model("<tag>|bad&name", ["a|b"], fn(_, p) { p[0] }, gradient=fn(
    _,
    _,
  ) {
    [1.0]
  }).unwrap()
  let result = fit_curve(
    model,
    [observation(0.0, 1.0), observation(1.0, 2.0), observation(2.0, 1.0)],
    [parameter("a|b", 0.0)],
  ).unwrap()
  assert_true(markdown_report(result).contains("a\\|b"))
  let svg = curve_svg(result).unwrap()
  assert_true(svg.contains("&lt;tag&gt;"))
  assert_true(svg.contains("&amp;name"))
  assert_true(!svg.contains("<tag>"))
}

///|
test "standalone SVG sorts descending observations before connecting predictions" {
  let data = [
    observation(3.0, 7.0),
    observation(2.0, 5.0),
    observation(1.0, 3.0),
    observation(0.0, 1.0),
  ]
  let result = fit_curve(linear_model(), data, [
    parameter("intercept", 0.0),
    parameter("slope", 0.0),
  ]).unwrap()
  assert_true(curve_svg(result).unwrap().contains("points=\"55"))
  assert_true(curve_svg(result, height=5000) is Err(_))
}
