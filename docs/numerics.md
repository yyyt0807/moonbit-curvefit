# Numerical contract

## Objective and solver

Unweighted residual e_i = f(x_i,p) − y_i; solver residual r_i = sqrt(w_i)e_i, with precision w_i > 0. Linear objective is sum r_i²/2. Robust objectives are separable in this **weighted** residual space. A robust threshold therefore uses weighted residual units.

For u = r/s: Huber = r²/2 inside |r|≤s, otherwise s|r|−s²/2; SoftL1 = s²(sqrt(1+u²)−1); Cauchy = s² ln(1+u²)/2. Their IRLS weights are 1 or s/|r|, 1/sqrt(1+u²), and 1/(1+u²), respectively.

Free variables use physical scale p_j = scale_j z_j. Analytic derivatives are checked then weighted/scaled. Finite differences use scale-aware steps, bound-clipped central differences (unequal-step quadratic formula) or feasible one-sided differences. Fixed parameters have no solver column.

Each LM step solves an augmented dense system using column-pivoted Householder QR. Damping scales with column norms. Feasible projected steps are evaluated against actual robust cost and the linearized prediction; rejected steps increase damping, accepted steps adapt it. Outward directions at active bounds are blocked.

This is not a faithful implementation of MINPACK, SciPy TRF or Ceres. No equivalence of stopping rules is claimed. Numerical overflow is rejected or surfaced in warnings; invalid trials may be rejected, but changing residual vector size is an error.

## Termination

Gradient, Step, Cost and AllFixed count as convergence. MaxIterations, MaxEvaluations, Stalled and NumericalFailure do not. Step/cost termination is based on accepted progress, not an arbitrarily small rejected step. Gradient is projected in scaled coordinates. Tolerances are numerical/user-domain choices, not universal scientific accuracy guarantees.

Evaluation counts include the initial residual and numerical final-diagnostic Jacobian when budget permits. Analytic Jacobian calls have their own counter. The solver conservatively reserves up to 2n+1 residual calls before a numerical iteration, so it can stop before exhausting every last allowed call. A trial-only invalid residual consumes its evaluation. Trace is optional and bounded by iteration budget.

## Models

| Name | Parameters in order | Formula |
| --- | --- | --- |
| linear | intercept, slope | a + bx |
| polynomial-d | c0 … cd | sum c_j x^j; Horner evaluation |
| exponential-decay | amplitude, rate, offset | A exp(−kx)+b |
| exponential-growth | amplitude, rate, offset | A exp(kx)+b |
| gaussian | height, center, width, offset | A exp(−(x−c)²/(2s²))+b; s>0 |
| logistic | bottom, top, center, width | b+(t−b) sigmoid((x−c)/s); s>0 |
| logistic5 | bottom, top, center, width, asymmetry | b+(t−b) sigmoid((x−c)/s)^a; s,a>0 |
| saturation | maximum, half, offset | M x/(h+x)+b; x≥0,h>0 |
| hill | maximum, half, exponent, offset | M sigmoid(a(ln x−ln h))+b; x≥0,h,a>0; x=0 gives b |

No automatic logarithmic transformation of observations. Units are caller-defined. Negative amplitudes and falling logistic curves are allowed. Positive-domain constraints should be explicit when supplying starts; auto seeds include positive width/half/exponent/asymmetry bounds. Exponential rate is not universally restricted to positive by the generic API.

## Rank and uncertainty

Rank is estimated from pivoted QR diagonals relative to the first. The diagonal ratio is a **conditioning proxy**, not an SVD condition number. Near-dependence can be tolerance-sensitive.

Eligible covariance is sigma² (JᵀWJ)⁻¹, sigma² = sum r_i²/(m−n_free), transformed back to physical coordinates. Fixed coordinates are zero. It assumes residual weights proportional to relative precision with an estimated common variance, not externally known absolute variances. Eligibility requires convergence, full local rank, positive degrees of freedom, linear loss and no active free-parameter bound.

Normal intervals and delta-method mean bands are local approximations, not profile likelihood or future-observation prediction intervals. Leverage uses gᵀCov g w/sigma²; internally studentized residuals divide by sigma sqrt(1−h); Cook distance uses free-parameter count. Zero variance or leverage near one prevents meaningful standardized influence. Robust covariance/influence is intentionally unavailable.

SSE/RMSE/R² are unweighted descriptive quantities, even for robust/weighted fits. AIC/BIC assume iid Gaussian errors, count estimated variance as one parameter and are absent for perfect zero-SSE data; AICc also requires its denominator positive. They do not establish model validity.

## Complexity

For m observations and n free parameters: dense QR O(mn²), storage O(mn+n²), per iteration. Numerical Jacobian adds up to 2n residual evaluations; model cost is caller-dependent. Final diagnostics add one QR and potentially another Jacobian. Multistart multiplies work by start count. SVG sorting O(m log m), report storage O(m). No sparse shortcut is implied.
