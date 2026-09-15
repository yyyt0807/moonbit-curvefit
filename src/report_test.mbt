///|
test "reports expose termination and produce standalone SVG" {
  let request = parse_request(
    "{\"model\":\"linear\",\"data\":[{\"x\":0,\"y\":2},{\"x\":1,\"y\":5},{\"x\":2,\"y\":8}]}",
  ).unwrap()
  let result = run_request(request).unwrap()
  assert_true(markdown_report(result).contains("Standard error"))
  assert_true(
    prediction_csv(result).has_prefix("x,y,weight,predicted,residual"),
  )
  assert_true(curve_svg(result).unwrap().contains("<polyline"))
  assert_true(curve_svg(result, residuals=true).unwrap().contains("residuals"))
  assert_true(curve_svg(result, width=10) is Err(_))
}
