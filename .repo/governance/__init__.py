"""Structural policy checks for this repository.

Policies live in `governance.policies.<name>` and follow one shape:
`violations.py` declares what can go wrong and why it matters, `check.py`
decides whether it has gone wrong. See `.repo/README.md`.
"""

__all__ = ["__version__"]

__version__ = "0.1.0"
