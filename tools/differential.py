"""Independent black-box comparison against SciPy; only synthetic data.

Run after: python -m pip install numpy scipy
This is development validation, not a runtime dependency or copied fixture corpus.
"""
import json
import math
import pathlib
import subprocess
import tempfile

import numpy as np
import scipy
from scipy.optimize import least_squares
from scipy.special import expit

ROOT = pathlib.Path(__file__).resolve().parents[1]


def evaluate(name, x, p):
    if name == "linear":
        return p[0] + p[1] * x
    if name == "exponential-decay":
        return p[0] * np.exp(-p[1] * x) + p[2]
    if name == "exponential-growth":
        return p[0] * np.exp(p[1] * x) + p[2]
    if name == "gaussian":
        return p[0] * np.exp(-0.5 * ((x - p[1]) / p[2]) ** 2) + p[3]
    if name == "logistic":
        return p[0] + (p[1] - p[0]) * expit((x - p[2]) / p[3])
    if name == "logistic5":
        return p[0] + (p[1] - p[0]) * expit((x - p[2]) / p[3]) ** p[4]
    if name == "saturation":
        return p[0] * x / (p[1] + x) + p[2]
    if name == "hill":
        return p[0] * x ** p[2] / (p[1] ** p[2] + x ** p[2]) + p[3]
    raise ValueError(name)


NAMES = {
    "linear": ["intercept", "slope"],
    "exponential-decay": ["amplitude", "rate", "offset"],
    "exponential-growth": ["amplitude", "rate", "offset"],
    "gaussian": ["height", "center", "width", "offset"],
    "logistic": ["bottom", "top", "center", "width"],
    "logistic5": ["bottom", "top", "center", "width", "asymmetry"],
    "saturation": ["maximum", "half", "offset"],
    "hill": ["maximum", "half", "exponent", "offset"],
}


def run_case(label, name, truth, seed, x, loss="linear", weighted=False,
             fixed=(), bound_slope=False, contaminated=False):
    y = evaluate(name, x, truth) + 0.002 * np.sin(np.arange(len(x)) * 1.7)
    if contaminated:
        y[7] += 20.0
    weights = np.linspace(0.5, 2.0, len(x)) if weighted else np.ones(len(x))
    parameters = []
    for i, field in enumerate(NAMES[name]):
        p = {"name": field, "initial": seed[i], "fixed": i in fixed}
        if field in {"width", "half", "exponent", "asymmetry", "rate"}:
            p["lower"] = 1e-6
        if bound_slope and field == "slope":
            p.update(lower=0.0, upper=2.0)
        parameters.append(p)
    active = [i for i in range(len(seed)) if i not in fixed]
    initial = np.array(seed, dtype=float)

    def residual(q):
        full = initial.copy()
        full[active] = q
        return (evaluate(name, x, full) - y) * np.sqrt(weights)

    lower = [parameters[i].get("lower", -np.inf) for i in active]
    upper = [parameters[i].get("upper", np.inf) for i in active]
    ref = least_squares(residual, initial[active], bounds=(lower, upper),
                        loss={"soft-l1": "soft_l1"}.get(loss, loss),
                        f_scale=0.5, xtol=1e-12, ftol=1e-12, gtol=1e-12,
                        max_nfev=20000)
    expected = initial.copy()
    expected[active] = ref.x
    request = {
        "version": 1, "model": name,
        "data": [{"x": float(a), "y": float(b), "weight": float(w)}
                 for a, b, w in zip(x, y, weights)],
        "parameters": parameters,
        "options": {"loss": loss, "loss_scale": 0.5,
                    "gradient_tolerance": 1e-6, "max_iterations": 1000},
    }
    with tempfile.TemporaryDirectory(prefix="curvefit-reference-") as temp:
        path = pathlib.Path(temp) / "request.json"
        path.write_text(json.dumps(request, allow_nan=False), encoding="utf-8")
        call = subprocess.run(["moon", "run", "cmd/curvefit", "--target", "native",
                               "--", "fit-json", str(path)], cwd=ROOT,
                              text=True, capture_output=True, timeout=60)
    if call.returncode != 0:
        raise AssertionError(f"{label}: CLI exit {call.returncode}: {call.stdout[-2000:]} {call.stderr}")
    report = json.loads(call.stdout[call.stdout.index("{"):])
    fit = report["result"]["fit"]
    actual = np.array(fit["values"])
    error = float(np.max(np.abs(actual - expected) / (1 + np.abs(expected))))
    cost_error = abs(fit["cost"] - ref.cost) / (1 + abs(ref.cost))
    assert report["converged"], label
    assert ref.success, label
    assert error < 2e-4, (label, error, actual, expected)
    assert cost_error < 1e-8, (label, cost_error)
    if loss == "linear" and not bound_slope:
        inverse = np.linalg.inv(ref.jac.T @ ref.jac)
        covariance = inverse * (2 * ref.cost / (len(x) - len(active)))
        mine = np.array(fit["covariance"])[np.ix_(active, active)]
        assert np.allclose(mine, covariance, rtol=0.01, atol=1e-9), label
    print(f"PASS {label}: parameter_error={error:.3g}, cost_error={cost_error:.3g}, termination={fit['termination']}")


def main():
    print(f"SciPy {scipy.__version__}; NumPy {np.__version__}")
    xp = np.linspace(0, 8, 40)
    xs = np.linspace(-6, 6, 50)
    run_case("weighted calibration", "linear", [1.5, 2.2], [0, 0], xp, weighted=True)
    run_case("bounded calibration", "linear", [1, 3], [1, 0.5], xp, fixed=(0,), bound_slope=True)
    run_case("decay", "exponential-decay", [8, 0.7, 0.4], [5, 0.3, 0], xp)
    run_case("fixed-offset decay", "exponential-decay", [8, 0.7, 0.4], [5, 0.3, 0.4], xp, fixed=(2,))
    run_case("growth", "exponential-growth", [2, 0.4, 1], [1.8, 0.35, 0.8], xp / 3)
    run_case("peak", "gaussian", [5, 0.5, 0.9, 1], [4, 0.2, 1.1, 0.8], xs)
    run_case("logistic", "logistic", [1, 5, 0.5, 0.8], [0.8, 4.8, 0.4, 1], xs)
    run_case("asymmetric logistic", "logistic5", [1, 5, 0.5, 0.8, 1.3], [0.9, 4.9, 0.4, 0.9, 1.1], xs)
    run_case("saturation", "saturation", [8, 2, 0.5], [7, 1.5, 0.3], xp)
    run_case("Hill", "hill", [8, 2, 1.4, 0.5], [7, 1.8, 1.1, 0.3], xp)
    for loss in ("huber", "soft-l1", "cauchy"):
        run_case(f"robust {loss}", "linear", [2, 3], [0, 0], xp, loss=loss, contaminated=True)
    print("13 independent black-box comparisons passed; not a universal accuracy guarantee.")


if __name__ == "__main__":
    main()
