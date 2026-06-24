# Copyright 2026 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

"""Central registry and policy definitions for export_app workarounds.

This module defines common workaround policies and maps them to specific
examples through selector-based registrations.

Registry keys are example paths relative to SDK root, for example:

    examples/wifi_examples/wifi_cli
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Optional, TypeAlias


def _matches_selector(value: Optional[str], expected: tuple[str, ...]) -> bool:
    if not expected:
        return True
    return value in expected


@dataclass(frozen=True, kw_only=True)
class WorkaroundSelector:
    boards: tuple[str, ...] = ()
    core_ids: tuple[str, ...] = ()
    app_ids: tuple[str, ...] = ()

    def matches(
        self,
        *,
        board: Optional[str] = None,
        core_id: Optional[str] = None,
        app_id: Optional[str] = None,
    ) -> bool:
        return (
            _matches_selector(board, self.boards)
            and _matches_selector(core_id, self.core_ids)
            and _matches_selector(app_id, self.app_ids)
        )


class WorkaroundPolicy(str, Enum):
    SKIP_OPTIONAL_HEADER_STAGING = "skip_optional_header_staging"
    INJECT_TRACE_KCONFIG_DEFINES = "keep_prjseg_kconfig"
    EXCLUDE_APP_COMPONENTS_FROM_BOARD_PRJ = "exclude_app_components_from_board_prj"
    KEEP_APP_CONFIG_BLOCKS = "keep_app_config_blocks"


@dataclass(frozen=True, kw_only=True)
class WorkaroundRegistration:
    selector: WorkaroundSelector = field(default_factory=WorkaroundSelector)
    policies: tuple[WorkaroundPolicy, ...] = ()
    ticket: Optional[str] = None
    remove_when: Optional[str] = None
    description: Optional[str] = None


WorkaroundRegistry: TypeAlias = dict[str, tuple[WorkaroundRegistration, ...]]


WORKAROUND_POLICY_REGISTRY: WorkaroundRegistry = {
    "examples/wifi_examples/wifi_cli": (
        WorkaroundRegistration(
            selector=WorkaroundSelector(
                boards=("evkmimxrt1160",),
                core_ids=("cm7",),
            ),
            ticket="MCUX-84480",
            policies=(WorkaroundPolicy.SKIP_OPTIONAL_HEADER_STAGING,),
            description='Skip copy all files in mcux_add_include'
        ),
    ),
    "examples/driver_examples/dpu_1/localdimming": (
        WorkaroundRegistration(
            selector=WorkaroundSelector(
                boards=("imx952evk",),
                core_ids=("cm7",),
            ),
            policies=(WorkaroundPolicy.INJECT_TRACE_KCONFIG_DEFINES,),
            remove_when="display_support Kconfig decoupled from PRJSEG cmake guard",
        ),
    ),
    # Key ending with '/' enables prefix matching: applies to all examples
    # under examples/matter_examples/.  Matter examples support multiple
    # build profiles (wifi/thread); feature-specific components must not be
    # hardcoded into <board>/prj.conf so overlays can switch profiles.
    "examples/matter_examples/": (
        WorkaroundRegistration(
            selector=WorkaroundSelector(),
            policies=(WorkaroundPolicy.EXCLUDE_APP_COMPONENTS_FROM_BOARD_PRJ,),
            ticket="SDKGEN-3514",
            description="Keep board prj.conf minimal so Matter profile overlays (wifi/thread) work.",
        ),
        WorkaroundRegistration(
            selector=WorkaroundSelector(),
            policies=(WorkaroundPolicy.KEEP_APP_CONFIG_BLOCKS,),
            ticket="SDKGEN-3556",
            description=(
                "Preserve config-guarded blocks in the application's own CMakeLists "
                "verbatim. Matter apps gate optional features behind app Kconfigs "
                "(e.g. CONFIG_CHIP_APP_BATTERY_MANAGER) that are disabled in the "
                "default build, so the default-config export trace must not drop "
                "those if() blocks or other build profiles fail to compile."
            ),
        ),
    ),
}


def normalize_example_key(source_dir: Path, sdk_root: Path) -> str:
    source_dir = source_dir.resolve()
    sdk_root = sdk_root.resolve()
    try:
        return source_dir.relative_to(sdk_root).as_posix()
    except ValueError as exc:
        raise ValueError(f"{source_dir} is not under SDK root {sdk_root}") from exc


def get_workaround_policies(
    source_dir: Path,
    sdk_root: Path,
    *,
    board: Optional[str] = None,
    core_id: Optional[str] = None,
    app_id: Optional[str] = None,
) -> tuple[WorkaroundPolicy, ...]:
    example_key = normalize_example_key(source_dir, sdk_root)
    matched = []
    for key, registrations in WORKAROUND_POLICY_REGISTRY.items():
        # Exact match, or prefix match when key ends with '/'.
        if key == example_key or (key.endswith("/") and example_key.startswith(key)):
            for registration in registrations:
                if not registration.selector.matches(board=board, core_id=core_id, app_id=app_id):
                    continue
                matched.extend(registration.policies)

    return tuple(dict.fromkeys(matched))


__all__ = [
    "WORKAROUND_POLICY_REGISTRY",
    "WorkaroundPolicy",
    "WorkaroundRegistration",
    "WorkaroundRegistry",
    "WorkaroundSelector",
    "get_workaround_policies",
    "normalize_example_key",
]