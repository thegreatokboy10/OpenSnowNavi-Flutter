#!/usr/bin/env python3
"""
将 QGIS 编辑后的 GeoJSON 导入回 SQLite

用法:
    python import_geojson.py edited_edges.geojson -o ski_graph_edited.sqlite --original ski_graph.sqlite

功能:
    - 从编辑后的 GeoJSON 更新 edges 表
    - 保持原有的图结构
    - 支持增量更新
"""

import sqlite3
import json
import argparse
import shutil
from typing import List


def coords_to_wkt(coords: List[List[float]]) -> str:
    """坐标转 WKT"""
    points = ', '.join(f'{c[0]} {c[1]}' for c in coords)
    return f'LINESTRING({points})'


def import_edges(geojson_path: str, db_path: str) -> dict:
    """从 GeoJSON 更新边"""
    with open(geojson_path, 'r', encoding='utf-8') as f:
        geojson = json.load(f)
    
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    
    stats = {'updated': 0, 'skipped': 0, 'errors': 0}
    
    for feature in geojson.get('features', []):
        props = feature.get('properties', {})
        geom = feature.get('geometry', {})
        
        edge_id = props.get('edge_id')
        if edge_id is None:
            stats['skipped'] += 1
            continue
        
        try:
            # 更新边属性
            wkt = coords_to_wkt(geom.get('coordinates', []))
            
            cur.execute('''
                UPDATE edges SET
                    name = ?,
                    difficulty = ?,
                    status = ?,
                    oneway = ?,
                    is_enabled = ?,
                    cost = ?,
                    note = ?,
                    geom = ?
                WHERE edge_id = ?
            ''', (
                props.get('name', ''),
                props.get('difficulty', ''),
                props.get('status', ''),
                1 if props.get('oneway') else 0,
                1 if props.get('is_enabled', True) else 0,
                props.get('cost', 0),
                props.get('note', ''),
                wkt,
                edge_id
            ))
            
            if cur.rowcount > 0:
                stats['updated'] += 1
            else:
                stats['skipped'] += 1
                
        except Exception as e:
            print(f"  Edge {edge_id} 更新失败: {e}")
            stats['errors'] += 1
    
    conn.commit()
    conn.close()
    
    return stats


def import_nodes(geojson_path: str, db_path: str) -> dict:
    """从 GeoJSON 更新节点"""
    with open(geojson_path, 'r', encoding='utf-8') as f:
        geojson = json.load(f)
    
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    
    stats = {'updated': 0, 'added': 0, 'errors': 0}
    
    for feature in geojson.get('features', []):
        props = feature.get('properties', {})
        geom = feature.get('geometry', {})
        
        node_id = props.get('node_id')
        coords = geom.get('coordinates', [])
        
        if node_id is None or len(coords) < 2:
            continue
        
        try:
            # 尝试更新
            cur.execute('''
                UPDATE nodes SET
                    lon = ?,
                    lat = ?,
                    kind = ?,
                    comment = ?
                WHERE node_id = ?
            ''', (coords[0], coords[1], props.get('kind', ''), 
                  props.get('comment', ''), node_id))
            
            if cur.rowcount > 0:
                stats['updated'] += 1
            else:
                # 如果不存在则插入
                cur.execute('''
                    INSERT INTO nodes (node_id, lon, lat, kind, comment)
                    VALUES (?, ?, ?, ?, ?)
                ''', (node_id, coords[0], coords[1], 
                      props.get('kind', ''), props.get('comment', '')))
                stats['added'] += 1
                
        except Exception as e:
            print(f"  Node {node_id} 处理失败: {e}")
            stats['errors'] += 1
    
    conn.commit()
    conn.close()
    
    return stats


def main():
    parser = argparse.ArgumentParser(description='导入 GeoJSON 到 SQLite')
    parser.add_argument('geojson', help='编辑后的 GeoJSON 文件')
    parser.add_argument('-o', '--output', help='输出 SQLite 文件')
    parser.add_argument('--original', required=True, help='原始 SQLite 文件（作为基础）')
    parser.add_argument('--type', choices=['edges', 'nodes', 'auto'], default='auto',
                        help='数据类型（默认自动检测）')
    
    args = parser.parse_args()
    
    # 复制原始文件作为基础
    output_path = args.output or args.original.replace('.sqlite', '_edited.sqlite')
    if output_path != args.original:
        print(f"复制 {args.original} -> {output_path}")
        shutil.copy(args.original, output_path)
    
    # 检测数据类型
    with open(args.geojson, 'r', encoding='utf-8') as f:
        geojson = json.load(f)
    
    first_feature = geojson.get('features', [{}])[0]
    geom_type = first_feature.get('geometry', {}).get('type', '')
    
    if args.type == 'auto':
        data_type = 'edges' if geom_type == 'LineString' else 'nodes'
    else:
        data_type = args.type
    
    print(f"导入 {data_type} 从 {args.geojson}...")
    
    if data_type == 'edges':
        stats = import_edges(args.geojson, output_path)
    else:
        stats = import_nodes(args.geojson, output_path)
    
    print("\n完成!")
    for key, value in stats.items():
        print(f"  - {key}: {value}")
    print(f"  - 输出: {output_path}")


if __name__ == '__main__':
    main()
