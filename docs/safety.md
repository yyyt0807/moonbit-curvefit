# Safety, boundaries and maintenance

This library is for controlled small dense numerical workloads. It is not a medical device, clinical recommendation engine, regulated analysis package or universal optimization service.

## Boundaries

High-level parameter, residual, observation and request validation rejects nonfinite data, invalid weights/scales/bounds, shape mismatches and invalid budgets. Dense Jacobian capacity is one million entries; at most 64 parameters. The cap prevents a 64-million-entry Jacobian but is not a measured RAM guarantee: arrays, copies, callbacks, reports and garbage collectors add overhead.

Callbacks can panic, allocate arbitrarily or never return. Those behaviors cannot be contained by ordinary numerical validation. Use trusted callbacks; sandbox external code separately. Large local CLI files are read before parser text limits. Treat report generation as O(m) memory, and limit caller workloads further for browser devices.

Bounds are inclusive. Equal lower/upper bounds are rejected: use fixed=true. A finite initial value must already be feasible; initial values are never silently projected. Residual ordering/count must remain stable across evaluations.

QR and result structs expose arrays for inspection. Do not hand-construct inconsistent factors or mutate returned results before passing them to diagnostics/reports. Lower-level building blocks have documented trusted-shape preconditions.

## Correctness findings addressed during implementation

- Nonfinite norm input could otherwise masquerade as zero: explicitly propagate NaN/Infinity and reject nonfinite gradients before convergence.
- Unweighted SSE doubling and derived R² could overflow: reject overflowing statistics and leave nonrepresentable R² absent.
- Normal equations amplify conditioning problems: solve LM and covariance factors through pivoted Householder QR instead.
- Tiny rejected steps are not evidence of progress: only accepted-step/cost criteria count as convergence.
- Rank-deficient/robust/bound-constrained fits cannot justify ordinary covariance: suppress it with warnings.
- A custom model borrowing a built-in name could have the wrong seed arity: check before indexing.
- Reports containing custom names require escaping: Markdown/HTML/SVG escaping is tested.

## Tests and future work

Regression tests include column permutations, physical scaling, tiny/large units, singular matrices, finite differences at bounds, fixed parameters, evaluation exhaustion, callback isolation, robust influence and malformed CSV/JSON. Independent SciPy comparisons cover representative—not exhaustive—problems. Backend parity is checked with all-target tests.

Future improvements should prioritize independent noisy/near-singular datasets, profiling allocation hot spots and better constrained-step strategies. Sparse/global/clinical features are outside the 0.1 scope. Do not add unchecked normal-equation shortcuts to chase speed.

Report issues after the public repository exists. Include toolchain/target, minimal synthetic reproducer, explicit initial values/options, expected mathematical behavior and termination/warnings. Do not upload private or patient data. There is no guaranteed security response SLA in this initial release.
