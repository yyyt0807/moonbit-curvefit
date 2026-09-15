# Provenance and references

- Original implementation, AI-assisted under applicant review; no third-party source code or fixture corpus is copied.
- Algorithm references: standard Householder QR, damped Gauss–Newton, Levenberg–Marquardt, finite differences and M-estimation. Public API descriptions consulted: https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.least_squares.html (SciPy, BSD-3-Clause); https://github.com/ceres-solver/ceres-solver (Apache-2.0).
- Direct runtime dependency: bundled `moonbitlang/core`, Apache-2.0. No external numerical runtime dependency.
- All sample data and tests are independently constructed from stated mathematical formulas, not patient data or proprietary measurements.
- The applicant must review attribution, numerical limitations and license suitability before publication.
- Native CLI dependency: `moonbitlang/x@0.4.49` filesystem, Apache-2.0; bundled `env` and `debug` remain core. Only standard C `exit` is platform glue, not a numerical binding.
- Independent development tests use NumPy 2.4.6 and SciPy 1.17.1 (BSD-3-Clause); neither is linked, bundled or required by the MoonBit runtime. Do not redistribute the ignored virtual environment.
- CI setup follows the MoonBit community's official workflow pattern: https://github.com/moonbit-community/.github/blob/main/workflow-templates/check.yml ; standard GitHub Actions are external CI tooling.
- The full Apache-2.0 legal text is standard license boilerplate, not a copied implementation. Existing MoonOCL material was consulted for proposal organization only; no personal details or project code were reused.
