# Curve fitting

This context concerns estimation of model parameters from observed data and the evidence needed to interpret that estimate.

## Language

**Observation**: A measured response associated with an input and a positive precision weight.
_Avoid_: Sample parameter

**Parameter**: An unknown model quantity, optionally fixed or restricted to a feasible interval.
_Avoid_: Observation

**Residual**: A signed discrepancy between a model prediction and an observation, expressed in the chosen precision scale.
_Avoid_: Absolute error

**Fit**: A local estimate of parameters minimizing a specified residual objective; it is not a guarantee of global optimality.
_Avoid_: Proven optimum

**Identifiability**: The ability of the available observations to distinguish nearby parameter values.
_Avoid_: Convergence

**Termination**: The reason an estimation process stops, which can be success, exhaustion, or numerical failure.
_Avoid_: Accuracy guarantee
