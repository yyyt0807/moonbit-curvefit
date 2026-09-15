///|
test "numeric CSV handles reorder quotes CRLF and precision weights" {
  let rows = parse_csv("weight,y,x\r\n2,\"5\",1\r\n1,8,2\r\n").unwrap()
  assert_eq(rows[0].x, 1.0)
  assert_eq(rows[0].weight, 2.0)
  let again = parse_csv(observations_csv(rows).unwrap()).unwrap()
  assert_eq(again[1].y, 8.0)
}

///|
test "CSV rejects missing malformed and nonfinite fields" {
  for
    text in [
      "x,x\n1,2", "x,y\n,2", "x,y\n1,NaN", "x,y\n1,2,3", "x,y\n\"1,2", "x,y,weight\n1,2,0",
      "x,y\n1,\"2\"oops",
    ] {
    assert_true(parse_csv(text) is Err(_))
  }
}
