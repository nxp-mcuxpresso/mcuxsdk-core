# Copyright (c) 2022 Nordic Semiconductor ASA
# Copyright 2025-2026 NXP
#
# SPDX-License-Identifier: Apache-2.0
#
# Adapted for the MCUXpresso SDK from Zephyr's
# zephyr/scripts/west_commands/fetchers/http.py.
#
# NOTE: 'requests' is imported lazily inside fetch(), not at module load. This
# lets the fetcher module import cleanly (so HTTPFetcher always registers and is
# listed) even when 'requests' is absent from the interpreter running west - a
# bare 'west blobs fetch' that only uses the git/file fetchers must not emit a
# spurious "could not be imported (No module named 'requests')" warning. The
# missing dependency is reported with a clear, actionable message only if an
# http(s) blob is actually fetched.

from fetchers.core import McuxBlobException, McuxBlobFetcher


class HTTPFetcher(McuxBlobFetcher):

    @classmethod
    def schemes(cls):
        return ['http', 'https']

    def fetch(self, west_command, blob, path):
        try:
            import requests
        except ImportError as e:
            raise McuxBlobException(
                "the 'http'/'https' fetcher requires the 'requests' package, "
                "which is not available to the interpreter running west. "
                "Install it (it is declared in "
                "mcuxsdk/scripts/requirements-base.txt) or run west from a venv "
                "that has the SDK requirements, e.g. "
                "'.venv/bin/python -m west blobs fetch'.") from e

        url = blob['url']
        west_command.dbg(f'HTTPFetcher fetching {url} to {path}')
        try:
            with requests.get(url, stream=True) as resp:
                resp.raise_for_status()
                with open(path, 'wb') as f:
                    for chunk in resp.iter_content(chunk_size=1 << 20):
                        f.write(chunk)
        except requests.exceptions.HTTPError as e:
            raise McuxBlobException(f'HTTP error occurred: {e}') from e
        except requests.exceptions.RequestException as e:
            raise McuxBlobException(f'An error occurred: {e}') from e
