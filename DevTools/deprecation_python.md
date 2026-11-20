# Deprecating a Public Function in Python

Python has two complementary tools: the `@deprecated` decorator (PEP 702,
`warnings.deprecated` in Python 3.13+, `typing_extensions.deprecated` for older
versions), which type checkers and IDEs understand **and** which emits a runtime
warning; and plain `warnings.warn()`, which works on every Python version. In both
cases `function_a` delegates to `function_b`.

## 1. `@deprecated` decorator (Python 3.13+, or `typing_extensions`)

```python
import sys

if sys.version_info >= (3, 13):
    from warnings import deprecated
else:
    from typing_extensions import deprecated


def function_b(x: int) -> int:
    return x * 2


@deprecated("function_a is deprecated and will be removed in v2.0; use function_b instead.")
def function_a(x: int) -> int:
    return function_b(x)
```

+ Static: type checkers (mypy, pyright) and editors (VS Code, PyCharm) flag calls to
  `function_a` before the code runs, typically with strikethrough.
+ Runtime: the decorator itself emits a `DeprecationWarning` with the message on
  every call, pointing at the caller's line. Don't add a `warnings.warn()` inside
  the body as well, or callers get the warning twice.
+ `category=` changes the warning class (e.g. `FutureWarning`); `category=None`
  disables the runtime warning and keeps only the static marker.

## 2. `warnings.warn()` (any Python version)

If you can't use the decorator, emit the warning yourself:

```python
import warnings
from typing import Any


def function_b(arg1: str, arg2: int = 0) -> dict[str, Any]:
    """Preferred function that performs the actual work."""
    return {"arg1": arg1, "arg2": arg2}


def function_a(arg1: str, arg2: int = 0) -> dict[str, Any]:
    """Deprecated alias for :func:`function_b`.

    .. deprecated:: 1.5
       Use :func:`function_b` instead.
    """
    warnings.warn(
        "function_a is deprecated and will be removed in v2.0; use function_b instead.",
        category=DeprecationWarning,
        stacklevel=2,
    )
    return function_b(arg1, arg2)
```

+ Delegation: all real logic stays in `function_b`.
+ `stacklevel=2`: with the default `stacklevel=1` the warning points at the
  `warnings.warn(...)` line inside `function_a`; `2` points at the caller's line.
+ No static marker: editors and type checkers don't see this deprecation.

## 3. Which warning category

| Category | Shown by default? | Intended audience |
|---|---|---|
| `DeprecationWarning` | Only when triggered by code in `__main__` (PEP 565, Python 3.7+); always under `pytest` or `python -W default` | Developers using the API |
| `PendingDeprecationWarning` | No | Early notice before the real deprecation |
| `FutureWarning` | Yes | End users of an application |

## 4. Signature differences

If `function_b` has different parameters, translate them explicitly in the wrapper:

```python
from warnings import deprecated  # or typing_extensions


def function_b(user_id: int, *, include_inactive: bool = False) -> dict:
    return {"user_id": user_id, "include_inactive": include_inactive}


@deprecated(
    "function_a(uid, active_only=...) is deprecated; "
    "use function_b(user_id, include_inactive=...) instead."
)
def function_a(uid: int, active_only: bool = True) -> dict:
    return function_b(user_id=uid, include_inactive=not active_only)
```

+ Map old parameters and semantics (`active_only`) to the new ones
  (`include_inactive=not active_only`), and name both in the message.
+ Forward `*args, **kwargs` only for a pure alias with an identical signature; it
  hides the signature from type checkers and IDEs:

```python
@deprecated("function_a is deprecated; use function_b instead.")
def function_a(*args, **kwargs):
    return function_b(*args, **kwargs)
```

## 5. Documentation and testing

+ Docstrings: mention the replacement, and use the Sphinx `.. deprecated:: <version>`
  directive if you generate docs (see section 2).
+ Lock in the warning and the delegation with `pytest.warns` (`match` is a
  case-sensitive regex searched in the message):

```python
import pytest


def test_function_a_warns_and_delegates():
    with pytest.warns(DeprecationWarning, match="use function_b instead"):
        assert function_a(3) == function_b(3)
```

## Related notes

+ [deprecation_kotlin.md](deprecation_kotlin.md): the same task in Kotlin, plus the release rollout lifecycle
+ [deprecation_c_cpp.md](deprecation_c_cpp.md): the same task in C and C++
+ [python_update.md](python_update.md): installing newer Python versions

## Reference

+ `warnings` module (incl. `warnings.deprecated`): https://docs.python.org/3/library/warnings.html
+ PEP 702, marking deprecations using the type system: https://peps.python.org/pep-0702/
+ PEP 565, showing `DeprecationWarning` in `__main__`: https://peps.python.org/pep-0565/
+ pytest, asserting warnings: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
