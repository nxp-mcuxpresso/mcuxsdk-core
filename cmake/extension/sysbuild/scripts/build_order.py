# Copyright 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import sys
import os
import argparse
import yaml
import re

'''
This file is used to analysis build order specified by add_dependencies().
The input are targets and its dependeny, we can get build order from these info.
For example,
A depends on B, C
B depends on C
The build order will be [C, B, A].
'''

def topo_sort(dependencies):
    from collections import defaultdict, deque

    # create graph
    graph = defaultdict(list)
    indegree = defaultdict(int)
    nodes = set()

    for node, deps in dependencies.items():
        nodes.add(node)
        for dep in deps:
            graph[dep].append(node)
            indegree[node] += 1
            nodes.add(dep)

    # node with indegree 0 enter the queue
    queue = deque([n for n in nodes if indegree[n] == 0])
    result = []
    while queue:
        curr = queue.popleft()
        result.append(curr)
        for neighbor in graph[curr]:
            indegree[neighbor] -= 1
            if indegree[neighbor] == 0:
                queue.append(neighbor)

    if len(result) != len(nodes):
        print("There is a circular dependency, and sorting is not possible.")
        sys.exit(1)
    return result

def parse_dependency_args(args):
    result = {}
    for arg in args:
        temp = re.split(r'\s+', arg.strip())
        for _t in temp:
            if ':' in _t:
                key, values = _t.split(':', 1)
                key = key.strip()
                value_list = [v.strip() for v in values.split(';') if v.strip()]
                result[key] = value_list
    return result

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Analysis target build order.')
    parser.add_argument('params', nargs='*', help='dependency info')
    parser.add_argument('-o', '--output', help='output file path')
    args = parser.parse_args()

    dependencies = parse_dependency_args(args.params)

    with open(args.output, 'w', encoding='utf-8') as f:
        yaml.dump({'build_order': topo_sort(dependencies)}, f, allow_unicode=True)
