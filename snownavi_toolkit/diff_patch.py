#!/usr/bin/env python3
"""
对比两个 ski_graph.sqlite，生成 patch.json

用法:
    python diff_patch.py original.sqlite edited.sqlite -o patch.json

功能:
    - 检测 edges 表的修改（属性变更、启用/禁用）
    - 检测新增的手动节点和边
    - 生成符合 patch 规范的 JSON 文件
"""

import sqlite3
import json
import argparse
from datetime import datetime
from typing import Dict, List, Any, Optional


def load_edges(db_path: str) -> Dict[str, dict]:
    """加载所有边，按 (src_feat_id, src_sub_id) 索引"""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    
    edges = {}
    for row in cur.execute('SELECT * FROM edges'):
        edge = dict(row)
        key = f"{edge['src_feat_id']}:{edge['src_sub_id']}"
        edges[key] = edge
    
    conn.close()
    return edges


def load_nodes(db_path: str) -> Dict[int, dict]:
    """加载所有节点"""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    
    nodes = {}
    for row in cur.execute('SELECT * FROM nodes'):
        node = dict(row)
        nodes[node['node_id']] = node
    
    conn.close()
    return nodes


def load_meta(db_path: str) -> Dict[str, str]:
    """加载 meta 信息"""
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    
    meta = {}
    for row in cur.execute('SELECT key, value FROM meta'):
        meta[row[0]] = row[1]
    
    conn.close()
    return meta


def diff_edges(orig_edges: Dict[str, dict], edited_edges: Dict[str, dict]) -> List[dict]:
    """对比边的差异，生成 patch 操作"""
    operations = []
    
    # 需要对比的字段
    compare_fields = ['name', 'difficulty', 'status', 'oneway', 'is_enabled', 'cost', 'note']
    
    for key, edited in edited_edges.items():
        if key not in orig_edges:
            # 新增的手动边（src_feat_type 可能是 'manual'）
            if edited.get('src_feat_type') == 'manual':
                operations.append({
                    'op': 'add_manual_edge',
                    'edge_id': edited['edge_id'],
                    'from_node': edited['from_node'],
                    'to_node': edited['to_node'],
                    'name': edited['name'],
                    'difficulty': edited['difficulty'],
                    'oneway': bool(edited['oneway']),
                    'geom': edited['geom']
                })
            continue
        
        orig = orig_edges[key]
        changes = {}
        
        for field in compare_fields:
            orig_val = orig.get(field)
            edited_val = edited.get(field)
            
            # 处理 bool 类型
            if field in ('oneway', 'is_enabled'):
                orig_val = bool(orig_val)
                edited_val = bool(edited_val)
            
            if orig_val != edited_val:
                changes[field] = edited_val
        
        if changes:
            # 检查是否是简单的 flip
            if list(changes.keys()) == ['oneway'] or \
               (set(changes.keys()) <= {'from_node', 'to_node'} and 
                orig['from_node'] == edited['to_node'] and 
                orig['to_node'] == edited['from_node']):
                operations.append({
                    'op': 'flip_edge',
                    'src_feat_id': edited['src_feat_id'],
                    'src_sub_id': edited['src_sub_id']
                })
            # 检查是否只是启用/禁用
            elif list(changes.keys()) == ['is_enabled']:
                operations.append({
                    'op': 'set_edge_enabled',
                    'src_feat_id': edited['src_feat_id'],
                    'src_sub_id': edited['src_sub_id'],
                    'is_enabled': changes['is_enabled']
                })
            else:
                # 通用更新
                operations.append({
                    'op': 'update_edge',
                    'src_feat_id': edited['src_feat_id'],
                    'src_sub_id': edited['src_sub_id'],
                    'changes': changes
                })
    
    return operations


def diff_nodes(orig_nodes: Dict[int, dict], edited_nodes: Dict[int, dict], 
               max_orig_id: int) -> List[dict]:
    """对比节点差异，找出手动添加的节点"""
    operations = []
    
    for node_id, node in edited_nodes.items():
        if node_id > max_orig_id and node_id not in orig_nodes:
            # 新增的手动节点
            operations.append({
                'op': 'add_manual_node',
                'node_id': node_id,
                'lon': node['lon'],
                'lat': node['lat'],
                'kind': node['kind'],
                'comment': node.get('comment', '')
            })
    
    return operations


def main():
    parser = argparse.ArgumentParser(description='对比 SQLite 生成 patch')
    parser.add_argument('original', help='原始 SQLite 文件')
    parser.add_argument('edited', help='编辑后的 SQLite 文件')
    parser.add_argument('-o', '--output', default='patch.json', help='输出 patch 文件')
    
    args = parser.parse_args()
    
    print(f"加载原始数据: {args.original}")
    orig_edges = load_edges(args.original)
    orig_nodes = load_nodes(args.original)
    orig_meta = load_meta(args.original)
    
    print(f"加载编辑后数据: {args.edited}")
    edited_edges = load_edges(args.edited)
    edited_nodes = load_nodes(args.edited)
    
    print("对比差异...")
    edge_ops = diff_edges(orig_edges, edited_edges)
    node_ops = diff_nodes(orig_nodes, edited_nodes, max(orig_nodes.keys()) if orig_nodes else 0)
    
    all_ops = node_ops + edge_ops
    
    # 构建 patch 文档
    patch = {
        'version': '1.0',
        'created_at': datetime.now().isoformat(),
        'source_hashes': {
            'runs': orig_meta.get('runs_hash', ''),
            'lifts': orig_meta.get('lifts_hash', '')
        },
        'operations': all_ops,
        'stats': {
            'total_operations': len(all_ops),
            'update_edge': len([o for o in all_ops if o['op'] == 'update_edge']),
            'flip_edge': len([o for o in all_ops if o['op'] == 'flip_edge']),
            'set_edge_enabled': len([o for o in all_ops if o['op'] == 'set_edge_enabled']),
            'add_manual_node': len([o for o in all_ops if o['op'] == 'add_manual_node']),
            'add_manual_edge': len([o for o in all_ops if o['op'] == 'add_manual_edge'])
        }
    }
    
    print(f"保存 patch: {args.output}")
    with open(args.output, 'w', encoding='utf-8') as f:
        json.dump(patch, f, ensure_ascii=False, indent=2)
    
    print("\n完成!")
    print(f"  - 总操作数: {patch['stats']['total_operations']}")
    for op_type, count in patch['stats'].items():
        if op_type != 'total_operations' and count > 0:
            print(f"  - {op_type}: {count}")


if __name__ == '__main__':
    main()
