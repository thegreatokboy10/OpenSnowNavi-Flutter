#!/usr/bin/env python3
"""
将 ski_graph.sqlite 导出为 GeoJSON，方便用 QGIS 编辑

用法:
    python export_geojson.py ski_graph.sqlite -o ski_graph_edges.geojson

功能:
    - 导出 edges 为 GeoJSON (LineString)
    - 导出 nodes 为 GeoJSON (Point)
    - 保留所有属性供 QGIS 编辑
"""

import sqlite3
import json
import argparse
from typing import List, Tuple


def parse_wkt_linestring(wkt: str) -> List[List[float]]:
    """解析 WKT LineString 为坐标数组"""
    if not wkt or not wkt.startswith('LINESTRING'):
        return []
    
    # 提取括号内的坐标
    start = wkt.find('(')
    end = wkt.rfind(')')
    if start == -1 or end == -1:
        return []
    
    coords_str = wkt[start+1:end]
    coords = []
    for point_str in coords_str.split(', '):
        parts = point_str.strip().split(' ')
        if len(parts) >= 2:
            coords.append([float(parts[0]), float(parts[1])])
    
    return coords


def export_edges(db_path: str, output_path: str) -> int:
    """导出边为 GeoJSON"""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    
    features = []
    for row in cur.execute('SELECT * FROM edges'):
        edge = dict(row)
        coords = parse_wkt_linestring(edge['geom'])
        
        if not coords:
            continue
        
        feature = {
            'type': 'Feature',
            'geometry': {
                'type': 'LineString',
                'coordinates': coords
            },
            'properties': {
                'edge_id': edge['edge_id'],
                'src_feat_type': edge['src_feat_type'],
                'src_feat_id': edge['src_feat_id'],
                'src_sub_id': edge['src_sub_id'],
                'name': edge['name'] or '',
                'uses': edge['uses'] or '',
                'difficulty': edge['difficulty'] or '',
                'status': edge['status'] or '',
                'oneway': bool(edge['oneway']),
                'from_node': edge['from_node'],
                'to_node': edge['to_node'],
                'length_m': round(edge['length_m'], 2),
                'is_enabled': bool(edge['is_enabled']),
                'cost': edge['cost'],
                'note': edge['note'] or ''
            }
        }
        features.append(feature)
    
    conn.close()
    
    geojson = {
        'type': 'FeatureCollection',
        'features': features
    }
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(geojson, f, ensure_ascii=False, indent=2)
    
    return len(features)


def export_nodes(db_path: str, output_path: str) -> int:
    """导出节点为 GeoJSON"""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    
    features = []
    for row in cur.execute('SELECT * FROM nodes'):
        node = dict(row)
        
        feature = {
            'type': 'Feature',
            'geometry': {
                'type': 'Point',
                'coordinates': [node['lon'], node['lat']]
            },
            'properties': {
                'node_id': node['node_id'],
                'kind': node['kind'] or '',
                'comment': node['comment'] or ''
            }
        }
        features.append(feature)
    
    conn.close()
    
    geojson = {
        'type': 'FeatureCollection',
        'features': features
    }
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(geojson, f, ensure_ascii=False, indent=2)
    
    return len(features)


def main():
    parser = argparse.ArgumentParser(description='导出 SQLite 为 GeoJSON')
    parser.add_argument('db', help='ski_graph.sqlite 文件')
    parser.add_argument('-o', '--output', default='ski_graph_edges.geojson', help='边输出文件')
    parser.add_argument('-n', '--nodes-output', default='ski_graph_nodes.geojson', help='节点输出文件')
    parser.add_argument('--edges-only', action='store_true', help='只导出边')
    parser.add_argument('--nodes-only', action='store_true', help='只导出节点')
    
    args = parser.parse_args()
    
    if not args.nodes_only:
        print(f"导出边到 {args.output}...")
        edge_count = export_edges(args.db, args.output)
        print(f"  - 导出 {edge_count} 条边")
    
    if not args.edges_only:
        print(f"导出节点到 {args.nodes_output}...")
        node_count = export_nodes(args.db, args.nodes_output)
        print(f"  - 导出 {node_count} 个节点")
    
    print("\n完成! 可以用 QGIS 打开编辑")


if __name__ == '__main__':
    main()
