///|
test "JSON request runs with explicit or heuristic parameters" {
  let request = parse_request(
    "{\"version\":1,\"model\":\"linear\",\"data\":[{\"x\":0,\"y\":2},{\"x\":1,\"y\":5},{\"x\":2,\"y\":8}],\"options\":{\"trace\":true}}",
  ).unwrap()
  let result = run_request(request).unwrap()
  assert_true(result.fit.termination.converged())
  assert_true(@json.valid(result_json(result)))
}

///|
test "JSON rejects unknown options and unsupported schema" {
  assert_true(
    parse_request("{\"model\":\"linear\",\"data\":[],\"optinos\":{}}") is Err(_),
  )
  assert_true(
    parse_request("{\"version\":2,\"model\":\"linear\",\"data\":[]}") is Err(_),
  )
}
