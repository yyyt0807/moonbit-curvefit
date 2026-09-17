# API and request schema

The generated `src/pkg.generated.mbti` is the authoritative public signature listing. Import package `yyyt0807/curvefit/src`.

## Recommended entry points

- `fit_curve`: prediction models + observations; name/order must match exactly.
- `residual_term` + `solve_terms`: compose general inverse/equation problems from named weighted scalar discrepancies; returns auditable per-term evidence.
- `solve`: arbitrary unweighted residual vector + optional full physical Jacobian.
- `solve_multistart`: 1–64 explicit starts; budgets apply **per start**, not globally.
- `initial_parameters`: built-in heuristic seeds; explicit starts are preferable for difficult data.
- `numerical_jacobian`, `check_model_gradient`: explicit derivative diagnostics.
- `statistics`, `normal_intervals`, `mean_bands`, `residual_diagnostics`: inspect assumptions before use.
- `parse_csv`, `parse_request`, `run_request`: strict numeric input workflow.
- `result_json`, `markdown_report`, `prediction_csv`, `curve_svg`: output from valid fit results.

All high-level numerical failures use `Result[..., FitError]`. A valid fit can return `Ok` with **nonconverged** termination. Do not equate `Ok` with success.

For `solve_terms`, precision is applied before the configured robust loss. Term names must be unique/nonempty. A gradient must contain all parameters including fixed ones. Analytic mode is all-or-nothing: one missing gradient selects a complete numerical Jacobian. This policy prevents a mixed Jacobian from hiding one low-quality derivative. The returned term objective contributions sum to `fit.cost` for deterministic callbacks.

## JSON version 1

Root fields: `version` (defaults to 1; only 1 supported), `model` (required registered name), `data` (required observation array), `parameters` (optional heuristic defaults), `options` (optional defaults).
Observation: required numeric `x,y`; optional positive finite `weight` defaults 1.
Parameter: required `name,initial`; optional `lower,upper` (null/unset = absent), `fixed` (false), `scale` (positive finite, defaults 1).
Unknown keys at these levels fail. Parameter order/names must match the selected model.

Options keys: `max_iterations,max_evaluations,gradient_tolerance,step_tolerance,cost_tolerance,difference_step,initial_damping,rank_tolerance,loss,loss_scale,trace`. Integer budgets must be positive. Loss names are `linear,huber,soft-l1,cauchy`; positive `loss_scale` defaults 1. See fixtures for a complete request. JSON duplicate-object-key semantics follow the core parser; duplicate keys are not a separate guaranteed rejection.

Output envelope: `version:1`, `result` (CurveResult), `converged` boolean and `statistics_assumption`. Enum JSON representations come from MoonBit derived ToJson; consumers should rely on the explicit converged field, not parse a human-readable report. Nullable uncertainty/statistics remain null when unavailable.

## Ownership and lower-level APIs

Callbacks receive copies of values; callers must not mutate shared input arrays concurrently. No parallel execution is promised. Keep the returned records unmodified when using report/diagnostic helpers.

Low-level allocation/projection/linearization functions expose implementation building blocks, not an independent hostile-input boundary. `zeros` requires nonnegative dimensions. Projection/step/analytic-Jacobian/diagnosis helpers require validated parameters, matching vector/matrix dimensions and valid active indices. QR methods require an unmodified factor returned by `qr_factor`. Hand-constructed or corrupted public records can violate these preconditions. Prefer high-level entry points for untrusted numerical input.
