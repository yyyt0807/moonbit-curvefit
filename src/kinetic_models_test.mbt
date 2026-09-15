///|
test "saturation and Hill half response at half parameter" {
  assert_eq(saturation_model().predict([0.0, 2.0], [10.0, 2.0, 1.0]).unwrap(), [
    1.0, 6.0,
  ])
  assert_eq(hill_model().predict([0.0, 2.0], [10.0, 2.0, 3.0, 1.0]).unwrap(), [
    1.0, 6.0,
  ])
  assert_true(hill_model().predict([-1.0], [10.0, 2.0, 3.0, 1.0]) is Err(_))
  assert_true(named_model("misspelled") is Err(_))
  for name in model_catalogue() {
    assert_true(named_model(name) is Ok(_))
  }
}
