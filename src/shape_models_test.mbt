///|
test "shape models preserve asymptotes and peak" {
  assert_eq(sigmoid(1000.0), 1.0)
  assert_eq(sigmoid(-1000.0), 0.0)
  assert_eq(gaussian_model().predict([3.0], [5.0, 3.0, 2.0, 1.0]).unwrap(), [
    6.0,
  ])
  assert_eq(logistic_model().predict([2.0], [0.0, 100.0, 2.0, 1.0]).unwrap(), [
    50.0,
  ])
  assert_eq(
    logistic5_model().predict([2.0], [0.0, 100.0, 2.0, 1.0, 2.0]).unwrap(),
    [25.0],
  )
  assert_true(gaussian_model().predict([1.0], [1.0, 0.0, 0.0, 0.0]) is Err(_))
}
