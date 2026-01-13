#!/usr/bin/env python3
"""
将 patch.json 应用到 ski_graph.sqlite

用法:
    python apply_patch.py ski_graph.sqlite patch.json -o ski_graph_final.sqlite

功能:
    - 验证源数据 hash 匹配
    - 应用所有 patch 操作
    - 输出最终的 SQLite 文件
"""

import sqlite3
import json
import argparse
import shutil
from pathlib import Path


def load_patch(patch_path: str) -> dict:
    """加载 patch 文件"""
    with open(patch_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def verify_hashes(db_path: str, patch: dict) -> bool:
    """验证源数据 hash 是否匹配"""
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    
    cur.execute("SELECT value FROM meta WHERE key = 'runs_hash'")
    row = cur.fetchone()
    runs_hash = row[0] if row else ''
    
    cur.execute("SELECT value FROM meta WHERE key = 'lifts_hash'")
    row = cur.fetchone()
    lifts_hash = row[0] if row else ''
    
    conn.close()
    
    expected = patch.get('source_hashes', {})
    
    if expected.get('runs') and expected['runs'] != runs_hash:
        print(f"警告: runs hash 不匹配!")
        print(f"  期望: {expected['runs']}")
        print(f"  实际: {runs_hash}")
        return False
    
    if expected.get('lifts') and expected['lifts'] != lifts_hash:
        print(f"警告: lifts hash 不匹配!")
        print(f"  期望: {expected['lifts']}")
        print(f"  实际: {lifts_hash}")
        return False
    
    return True


def apply_operation(cur: sqlite3.Cursor, op: dict) -> bool:
    """应用单个操作"""
    op_type = op.get('op')
    
    if op_type == 'update_edge':
        return apply_update_edge(cur, op)
    elif op_type == 'flip_edge':
        return apply_flip_edge(cur, op)
    elif op_type == 'set_edge_enabled':
        return apply_set_edge_enabled(cur, op)
    elif op_type == 'add_manual_node':
        return apply_add_manual_node(cur, op)
    elif op_type == 'add_manual_edge':
        return apply_add_manual_edge(cur, op)
    else:
        print(f"  未知操作类型: {op_type}")
        return False


def apply_update_edge(cur: sqlite3.Cursor, op: dict) -> bool:
    """更新边属性"""
    src_feat_id = op['src_feat_id']
    src_sub_id = op['src_sub_id']
    changes = op['changes']
    
    if not changes:
        return True
    
    set_clauses = []
    values = []
    for field, value in changes.items():
        set_clauses.append(f"{field} = ?")
        # 处理 bool
        if isinstance(value, bool):
            value = 1 if value else 0
        values.append(value)
    
    values.extend([src_feat_id, src_sub_id])
    
    sql = f"UPDATE edges SET {', '.join(set_clauses)} WHERE src_feat_id = ? AND src_sub_id = ?"
    cur.execute(sql, values)
    
    return cur.rowcount > 0


def apply_flip_edge(cur: sqlite3.Cursor, op: dict) -> bool:
    """翻转边方向"""
    src_feat_id = op['src_feat_id']
    src_sub_id = op['src_sub_id']
    
    # 先获取当前的 geom
    cur.execute('''
        SELECT from_node, to_node, geom 
        FROM edges 
        WHERE src_feat_id = ? AND src_sub_id = ?
    ''', (src_feat_id, src_sub_id))
    
    row = cur.fetchone()
    if not row:
        return False
    
    from_node, to_node, geom = row
    
    # 反转 geom
    reversed_geom = reverse_linestring(geom)
    
    # 更新：交换 from_node 和 to_node，反转 geom
    cur.execute('''
        UPDATE edges 
        SET from_node = ?, 
            to_node = ?,
            geom = ?
        WHERE src_feat_id = ? AND src_sub_id = ?
    ''', (to_node, from_node, reversed_geom, src_feat_id, src_sub_id))
    
    return cur.rowcount > 0


def reverse_linestring(wkt: str) -> str:
    """反转 LINESTRING 的坐标顺序"""
    if not wkt or not wkt.startswith('LINESTRING('):
        return wkt
    
    # 提取坐标部分
    inner = wkt[11:-1]  # 去掉 "LINESTRING(" 和 ")"
    coords = [c.strip() for c in inner.split(',')]
    coords.reverse()
    
    return 'LINESTRING(' + ', '.join(coords) + ')'


def apply_set_edge_enabled(cur: sqlite3.Cursor, op: dict) -> bool:
    """设置边启用状态"""
    src_feat_id = op['src_feat_id']
    src_sub_id = op['src_sub_id']
    is_enabled = 1 if op['is_enabled'] else 0
    
    cur.execute('''
        UPDATE edges SET is_enabled = ?
        WHERE src_feat_id = ? AND src_sub_id = ?
    ''', (is_enabled, src_feat_id, src_sub_id))
    
    return cur.rowcount > 0


def apply_add_manual_node(cur: sqlite3.Cursor, op: dict) -> bool:
    """添加手动节点"""
    cur.execute('''
        INSERT OR REPLACE INTO nodes (node_id, lon, lat, kind, comment)
        VALUES (?, ?, ?, ?, ?)
    ''', (op['node_id'], op['lon'], op['lat'], op['kind'], op.get('comment', '')))
    
    return True


def calculate_line_length(wkt: str) -> float:
    """计算 WKT LINESTRING 的长度（米）"""
    import math

    if not wkt or not wkt.startswith('LINESTRING('):
        return 0.0

    # 提取坐标
    inner = wkt[11:-1]  # 去掉 "LINESTRING(" 和 ")"
    coords = []
    for point in inner.split(','):
        parts = point.strip().split()
        if len(parts) >= 2:
            coords.append((float(parts[0]), float(parts[1])))

    if len(coords) < 2:
        return 0.0

    # 计算 Haversine 距离
    R = 6371000  # 地球半径（米）
    total = 0.0

    for i in range(len(coords) - 1):
        lon1, lat1 = coords[i]
        lon2, lat2 = coords[i + 1]

        phi1 = math.radians(lat1)
        phi2 = math.radians(lat2)
        delta_phi = math.radians(lat2 - lat1)
        delta_lambda = math.radians(lon2 - lon1)

        a = math.sin(delta_phi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda/2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

        total += R * c

    return total


def apply_add_manual_edge(cur: sqlite3.Cursor, op: dict) -> bool:
    """添加手动边 - 支持持久 ID 和幂等性"""
    # 使用 patch 中提供的 src_feat_id（持久）
    src_feat_id = op.get('src_feat_id')
    if not src_feat_id:
        # 向后兼容：如果没有提供，生成一个
        import hashlib
        geom = op.get('geom', '')
        src_feat_id = hashlib.sha256(f"manual:{geom}".encode()).hexdigest()[:40]

    src_sub_id = op.get('src_sub_id', 0)

    # 幂等性检查：检查是否已存在
    cur.execute('''
        SELECT edge_id FROM edges
        WHERE src_feat_id = ? AND src_sub_id = ?
    ''', (src_feat_id, src_sub_id))

    existing = cur.fetchone()

    # 获取字段值
    src_feat_type = op.get('src_feat_type', 'run')
    name = op.get('name', '')
    uses = op.get('uses', 'downhill' if src_feat_type == 'run' else 'lift')
    difficulty = op.get('difficulty', '')
    status = op.get('status', 'operating')
    oneway = 1 if op.get('oneway', True) else 0
    from_node = op['from_node']
    to_node = op['to_node']
    geom = op.get('geom', '')
    osm_id = op.get('osm_id', '')
    lift_type = op.get('lift_type', '')
    duration = op.get('duration', 0) or 0
    occupancy = op.get('occupancy', 0) or 0

    # 计算长度
    length_m = calculate_line_length(geom)
    cost = length_m  # 默认 cost = 长度

    if existing:
        # 已存在 → UPDATE（幂等）
        cur.execute('''
            UPDATE edges SET
                src_feat_type = ?, name = ?, uses = ?, difficulty = ?,
                status = ?, oneway = ?, from_node = ?, to_node = ?,
                length_m = ?, geom = ?, cost = ?, osm_id = ?,
                lift_type = ?, duration = ?, occupancy = ?
            WHERE src_feat_id = ? AND src_sub_id = ?
        ''', (src_feat_type, name, uses, difficulty,
              status, oneway, from_node, to_node,
              length_m, geom, cost, osm_id,
              lift_type, duration, occupancy,
              src_feat_id, src_sub_id))
    else:
        # 不存在 → INSERT
        cur.execute('SELECT MAX(edge_id) FROM edges')
        max_id = cur.fetchone()[0] or 0
        new_id = max_id + 1

        cur.execute('''
            INSERT INTO edges (edge_id, src_feat_type, src_feat_id, src_sub_id,
                              name, uses, difficulty, status, oneway,
                              from_node, to_node, length_m, geom,
                              is_enabled, cost, note, osm_id,
                              lift_type, duration, occupancy)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, '', ?, ?, ?, ?)
        ''', (new_id, src_feat_type, src_feat_id, src_sub_id,
              name, uses, difficulty, status, oneway,
              from_node, to_node, length_m, geom,
              cost, osm_id, lift_type, duration, occupancy))

    return True


def main():
    parser = argparse.ArgumentParser(description='应用 patch 到 SQLite')
    parser.add_argument('db', help='原始 SQLite 文件')
    parser.add_argument('patch', help='patch.json 文件')
    parser.add_argument('-o', '--output', help='输出文件（默认覆盖原文件）')
    parser.add_argument('--force', action='store_true', help='忽略 hash 不匹配警告')
    
    args = parser.parse_args()
    
    print(f"加载 patch: {args.patch}")
    patch = load_patch(args.patch)
    
    print(f"验证源数据...")
    if not verify_hashes(args.db, patch):
        if not args.force:
            print("错误: 源数据 hash 不匹配，使用 --force 强制应用")
            return
        print("强制继续...")
    
    # 复制到输出文件
    output_path = args.output or args.db
    if output_path != args.db:
        print(f"复制到 {output_path}...")
        shutil.copy(args.db, output_path)
    
    print(f"应用 patch...")
    conn = sqlite3.connect(output_path)
    cur = conn.cursor()
    
    success_count = 0
    fail_count = 0
    
    for i, op in enumerate(patch.get('operations', [])):
        try:
            if apply_operation(cur, op):
                success_count += 1
            else:
                print(f"  操作 {i} 未匹配任何记录: {op.get('op')}")
                fail_count += 1
        except Exception as e:
            print(f"  操作 {i} 失败: {e}")
            fail_count += 1
    
    # 更新 meta
    cur.execute("INSERT OR REPLACE INTO meta VALUES ('patch_applied', ?)", 
                (patch.get('created_at', ''),))
    
    conn.commit()
    conn.close()
    
    print("\n完成!")
    print(f"  - 成功: {success_count}")
    print(f"  - 失败: {fail_count}")
    print(f"  - 输出: {output_path}")


if __name__ == '__main__':
    main()
