///|
test "basic models match closed forms" {
  assert_eq(linear_model().predict([0.0, 1.0, 2.0], [2.0, 3.0]).unwrap(), [
    2.0, 5.0, 8.0,
  ])
  assert_eq(
    polynomial_model(2)
    .unwrap()
    .predict([0.0, 1.0, 2.0], [1.0, 2.0, 3.0])
    .unwrap(),
    [1.0, 6.0, 17.0],
  )
  assert_eq(
    exponential_decay_model().predict([0.0], [5.0, 2.0, 1.0]).unwrap(),
    [6.0],
  )
  assert_true(polynomial_model(13) is Err(_))
  assert_true(linear_model().predict([1.0], [1.0]) is Err(_))
}
