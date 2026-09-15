///|
test "heuristic initialization is order independent for unique x" {
  let data = [
    observation(0.0, 2.0),
    observation(1.0, 5.0),
    observation(2.0, 8.0),
  ]
  let p = initial_parameters(linear_model(), data).unwrap()
  assert_true((p[0].initial - 2.0).abs() < 1.0e-12)
  assert_true((p[1].initial - 3.0).abs() < 1.0e-12)
  assert_true(
    initial_parameters(gaussian_model(), [
      observation(0.0, 1.0),
      observation(0.0, 2.0),
    ])
    is Err(_),
  )
  for name in model_catalogue() {
    assert_true(initial_parameters(named_model(name).unwrap(), data) is Ok(_))
  }
}

///|
test "seed estimation rejects a custom model impersonating a built-in arity" {
  let model = custom_model("linear", ["only"], fn(x, p) { x * p[0] }).unwrap()
  assert_true(
    initial_parameters(model, [observation(0.0, 1.0), observation(1.0, 2.0)])
    is Err(_),
  )
}
