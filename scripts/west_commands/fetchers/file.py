# Copyright 2025-2026 NXP
#
# SPDX-License-Identifier: Apache-2.0
#
# A simple file:// fetcher for the MCUXpresso SDK west blobs command. It copies
# a blob from a local path (typically a mounted release share, an offline KEX
# mirror, or a local clone of a blob repo). This has no Zephyr equivalent; it is
# added so the blob mechanism can be exercised fully offline, without standing
# up an HTTP host, and so air-gapped builds can resolve blobs from a local mount.

import shutil
from pathlib import Path
from urllib.parse import unquote, urlparse

from fetchers.core import McuxBlobException, McuxBlobFetcher


class FileFetcher(McuxBlobFetcher):

    @classmethod
    def schemes(cls):
        return ['file']

    def fetch(self, west_command, blob, path):
        url = blob['url']
        west_command.dbg(f'FileFetcher fetching {url} to {path}')
        parsed = urlparse(url)
        # file:///abs/path -> netloc is empty, path holds the absolute path.
        src = Path(unquote(parsed.path))
        if not src.is_file():
            raise McuxBlobException(f'Source file does not exist: {src}')
        try:
            shutil.copy(src, path)
        except OSError as e:
            raise McuxBlobException(f'Failed to copy {src}: {e}') from e
