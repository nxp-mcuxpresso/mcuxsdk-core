# Copyright (c) 2022 Nordic Semiconductor ASA
# Copyright 2025-2026 NXP
#
# SPDX-License-Identifier: Apache-2.0
#
# Adapted for the MCUXpresso SDK from Zephyr's
# zephyr/scripts/west_commands/fetchers/core.py. Only the exception name was
# changed (ZephyrBlobException -> McuxBlobException); the fetcher contract is
# unchanged so existing http/file fetchers port over directly.

from abc import ABC, abstractmethod
from pathlib import Path
from typing import List, Type

from west.commands import WestCommand


class McuxBlobException(Exception):
    pass


class McuxBlobFetcher(ABC):

    @staticmethod
    def get_fetchers() -> List[Type['McuxBlobFetcher']]:
        '''Get a list of all currently defined fetcher classes.'''
        return McuxBlobFetcher.__subclasses__()

    @classmethod
    @abstractmethod
    def schemes(cls) -> List[str]:
        '''Return this fetcher's schemes.'''

    @abstractmethod
    def fetch(self, west_command: WestCommand, blob: dict, path: Path):
        ''' Fetch a blob and store it '''

    def fetch_many(self, west_command: WestCommand, blobs_and_paths: list) -> list:
        '''Fetch multiple blobs that share the same repo/revision in one go.

        blobs_and_paths is a list of (blob_dict, dest_path) where every blob
        has the same 'url' and 'revision'. The default implementation loops
        over fetch(); subclasses may override for a batched single-clone
        optimisation (see fetchers/git.py).

        Contract: a per-blob failure must NOT abort the rest of the batch.
        Returns the list of (blob_dict, dest_path) entries that failed (empty
        if everything succeeded); the caller (blobs.py) retries only those
        individually. Raising out of fetch_many is reserved for failures that
        invalidate the whole batch (e.g. the shared clone itself fails).
        '''
        failed = []
        for blob, path in blobs_and_paths:
            try:
                self.fetch(west_command, blob, path)
            except McuxBlobException as e:
                west_command.dbg(f'fetch_many: {path} failed: {e}')
                failed.append((blob, path))
        return failed
