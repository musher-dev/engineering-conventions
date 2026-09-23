"""What can go wrong with the image-baked toolchain, and why each rule exists."""

from __future__ import annotations

from governance.reporting import Violation

DOCS = "CONFIGURATION.md#runtimes--tools"

DOCKERFILE = ".devcontainer/Dockerfile"
DEVCONTAINER = ".devcontainer/devcontainer.json"

#: The short form; the full diagnosis is in CONFIGURATION.md, which `docs` below
#: points at.
_WHY_NOT_A_FEATURE = (
    "The devcontainers-extra Features for bun, uv and go-task resolve release "
    "assets through an unauthenticated api.github.com call. Codespaces and CI "
    "share egress IPs, so that call is rate-limited, and one failed Feature "
    "fails the entire image build. Pinning the version does not avoid the call."
)


def feature_reintroduced(feature: str, tool: str) -> Violation:
    return Violation(
        code="TC-01",
        summary=f"{tool} is declared as a Feature; it must be baked by the Dockerfile",
        reason=_WHY_NOT_A_FEATURE,
        fix=(
            f"Remove {feature!r} from the features block and pin {tool} with an "
            f"ARG in {DOCKERFILE} instead."
        ),
        where=DEVCONTAINER,
        docs=DOCS,
    )


def missing_arg(name: str, tool: str) -> Violation:
    return Violation(
        code="TC-02",
        summary=f"no pinned 'ARG {name}=<version>' for {tool}",
        reason=(
            "The ARG defaults are the single source of truth for what the image "
            "bakes. scripts/verify-toolchain.sh reads them back to assert the "
            "built container matches, so an absent or empty pin turns that CI "
            "check into a no-op."
        ),
        fix=f"Add `ARG {name}=<version>` to {DOCKERFILE}.",
        where=DOCKERFILE,
        docs=DOCS,
    )


def floating_arg(name: str, value: str) -> Violation:
    return Violation(
        code="TC-02",
        summary=f"ARG {name} is set to the floating value {value!r}",
        reason=(
            "Every other tool in this template is pinned to an exact version. A "
            "floating tag makes the image irreproducible and silently changes "
            "the toolchain under developers who rebuild on different days."
        ),
        fix=f"Replace {value!r} with an exact version in {DOCKERFILE}.",
        where=DOCKERFILE,
        docs=DOCS,
    )


def task_version_drift(dockerfile_version: str, ci_version: str, ci_path: str) -> Violation:
    return Violation(
        code="TC-03",
        summary=(
            f"task pinned to {dockerfile_version} in the Dockerfile but "
            f"{ci_version} in CI"
        ),
        reason=(
            "CI installs Task with arduino/setup-task rather than the dev "
            "container image, so the two pins are the same decision recorded "
            "twice. When they drift, a Taskfile change can pass locally and "
            "fail in CI (or the reverse) for reasons no diff explains."
        ),
        fix=(
            f"Set the same version in {DOCKERFILE} (ARG TASK_VERSION) and "
            f"{ci_path} (arduino/setup-task `version:`)."
        ),
        where=ci_path,
        docs=DOCS,
    )
