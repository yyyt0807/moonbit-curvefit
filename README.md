# MoonCurveFit

Pure MoonBit small-dense nonlinear least squares, with parameter bounds, robust losses and honest convergence diagnostics. Module: `yyyt0807/curvefit`; library package: `yyyt0807/curvefit/src`. Apache-2.0. Original AI-assisted implementation, not a SciPy port or wrapper.

Useful for instrument calibration, degradation/kinetics curves, peak fitting, saturation responses and offline analysis embedded in a JavaScript/WASM application. No pharmacology experiment or medical decision-making is required. The core numerical code has no FFI; only the native CLI uses filesystem support and the C `exit` function.

Status: local implementation complete; GitHub creation/push, remote CI verification and mooncakes publication are intentionally deferred. The URL in `moon.mod` is the intended destination, not evidence of a published release.

## Run from this checkout

Install a recent [MoonBit toolchain](https://docs.moonbitlang.com/en/latest/): tested with compiler 0.10.11 (2026-08-28), moon/moonrun 0.1.20260827. Native requires a C toolchain; JavaScript requires Node.js. Run in the project directory:

```sh
moon update
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon run examples/demo --target native
moon run examples/demo --target js
moon run examples/demo --target wasm-gc
moon run examples/benchmark --target native
```

The demo asserts three scenarios: instrument calibration, bounded exponential decay and outlier-resistant offline regression. All observations are synthetic. The benchmark checks accuracy for 100, 1,000 and 10,000 points; it reports evaluation counts, not timing claims. Measure wall time externally, excluding compilation for steady-state comparisons.

## Library use

In your `moon.pkg`, import `"yyyt0807/curvefit/src" @fit`. After publication, add the module with `moon add yyyt0807/curvefit`; before publication use this checkout's examples.

```moonbit
let data = [
  @fit.observation(0.0, 1.0),
  @fit.observation(1.0, 3.0),
  @fit.observation(2.0, 5.0),
]
let result = @fit.fit_curve(@fit.linear_model(), data, [
  @fit.parameter("intercept", 0.0),
  @fit.parameter("slope", 0.0),
]).unwrap()
assert_true(result.fit.termination.converged())
```

For arbitrary residuals, use `solve(parameters, residual, jacobian?, weights?, options?)`. Residual callbacks return unweighted residuals; optional Jacobian rows correspond to observations and columns include **all** parameters, including fixed ones. A custom prediction model can be built with `custom_model`. Use `check_model_gradient` before trusting a custom analytic gradient. Callbacks receive copied parameter arrays; they must still be deterministic, terminate and not panic.

`Parameter` supports lower/upper bounds, fixed values and positive physical scale. `Options` supports Linear, Huber, SoftL1 and Cauchy losses, evaluation/iteration budgets and optional trace. `solve_multistart` uses explicit feasible starts and ranks converged results before unfinished ones; it does not guarantee a global optimum.

## Native command line

```sh
moon run cmd/curvefit --target native -- models
moon run cmd/curvefit --target native -- fit-json examples/data/calibration.json markdown
moon run cmd/curvefit --target native -- fit-json examples/data/bounded.json json
moon run cmd/curvefit --target native -- fit-csv linear examples/data/calibration.csv auto svg
```

Formats: `json`, `markdown`, `csv`, `svg`, `residual-svg`. Reports go to stdout; the program never overwrites input files. Redirect explicitly if desired. Errors also go to stdout in this release. Exit codes: 0 converged, 2 input/IO/report error, 3 valid but nonconverged result (report still emitted). JSON is preferred for bounds, scales, fixed parameters and losses. CSV initials are `auto` or comma-separated numbers in model parameter order.

CSV schema is exactly `x,y` or `x,y,weight` (columns may be reordered). CRLF, blank lines and quoted numeric fields are accepted; no embedded-newline fields, BOM or unknown columns. Weight is **precision**: residual = sqrt(weight) × (prediction − observation), not a standard deviation. JSON request version is 1; unknown fields fail. See fixtures and [API/schema reference](docs/api.md).

## Models and diagnostics

Built-ins: linear, polynomial degree 0–12, exponential decay/growth, Gaussian, four-parameter logistic, asymmetric five-parameter logistic, saturation and Hill. The named CLI API accepts polynomial degrees 0–6 (the short catalog lists degrees 2 and 3). Logistic inputs are used directly, **not automatically log transformed**; logistic5's center is not generally its half-height point. Parameter ordering/formulas are in [the numerical contract](docs/numerics.md).

Results retain termination, budgets used, weighted residuals, objective cost, rank, a QR diagonal conditioning proxy, warnings and trace. Classical covariance/standard errors require an eligible converged linear-loss fit: positive residual degrees of freedom, full rank and no active bounds. Approximate normal intervals, mean-curve delta-method bands, leverage, studentized residuals and Cook distances share these restrictions. Robust fits do not fabricate classical uncertainty. Descriptive statistics are unweighted; Gaussian information criteria have separate assumptions.

## Scope and limitations

A local small-dense solver, not a certified optimizer or full scientific platform. At most 64 total parameters and one million residuals, with at most one million dense Jacobian entries; QR allows 1.1 million entries for damping rows. JSON/CSV text is capped at 32 million UTF-16 code units. The native CLI reads a complete local file before the parser check: do not expose it as an unbounded public upload service.

No sparse matrices, autodiff, complex arithmetic, GPU, ODE solving, global optimization, clinical inference, profile likelihood or robust sandwich covariance. Bounds use projection rather than SciPy's reflective trust-region algorithm. Rank deficiency is reported, not repaired with scientific assumptions. Poor starts, flat/saturated responses and bad scaling can fail. Check convergence **and** rank/diagnostics; success is not proof of an appropriate model. See [safety and maintenance](docs/safety.md).

## Validation and ecosystem positioning

Tests cover model/gradient parity, fixed/bounded/scaled parameters, robust losses, rank deficiency, budgets, overflow, malformed IO and report escaping. Independent black-box comparison:

```sh
python -m venv .venv
# Activate the environment using your shell's normal activation command.
python -m pip install numpy==2.4.6 scipy==1.17.1
python tools/differential.py
```

Python tools are development-only. Thirteen synthetic SciPy cases compare convergence, cost, parameters and eligible covariance. This is evidence for tested cases, not universal numerical certification. [Local review](docs/local-review.md) records actual results. CI covers three operating systems/all backends; its remote result remains unverified until push.

Existing scientific/linear fitting packages share underlying mathematics. MoonCurveFit contributes an integrated bounded nonlinear residual solver, robust objectives, careful uncertainty eligibility and portable IO/report workflow. We do not claim absence of all similar algorithms. See [comparison](docs/landscape.md) and [third-party notes](docs/third-party.md).

## Contest delivery

The applicant's September schedule supersedes older guide dates: application/development and acceptance deadline September 24, 24:00. History preserves meaningful development commits. [Proposal writing guide](docs/proposal-outline.md) supplies facts, **not a human-authored final application**; the applicant must write/review the final one-page proposal with at least three scenarios and confirm account/applicant identity. No remote publish automation is configured.

Before final submission: create public `yyyt0807/moonbit-curvefit`, push this history, verify CI on its actual default branch, publish `yyyt0807/curvefit` to mooncakes and re-run acceptance review. Local readiness is not final competition acceptance.
