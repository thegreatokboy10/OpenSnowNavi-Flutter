#!/usr/bin/env python3
"""
SnowNavi 滑雪导航离线图包预处理脚本
将 OSM GeoJSON (runs + lifts) 转换为 SQLite 图结构

用法:
    python ski_graph_preprocess.py runs.geojson lifts.geojson -o ski_graph.sqlite

输出:
    - ski_graph.sqlite: 包含 meta, nodes, edges 表
    - review_tasks.json: 需要人工审核的问题列表
"""

import json
import sqlite3
import hashlib
import argparse
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Tuple, Dict, Optional, Any
import math
from collections import defaultdict


# ============================================================
# 几何工具函数
# ============================================================

def haversine_distance(lon1: float, lat1: float, lon2: float, lat2: float) -> float:
    """计算两点间的 Haversine 距离（米）"""
    R = 6371000  # 地球半径（米）
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    
    a = math.sin(delta_phi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    
    return R * c


def line_length(coords: List[List[float]]) -> float:
    """计算折线总长度（米）"""
    total = 0.0
    for i in range(len(coords) - 1):
        total += haversine_distance(coords[i][0], coords[i][1], coords[i+1][0], coords[i+1][1])
    return total


def point_to_segment_distance(px: float, py: float, 
                               x1: float, y1: float, 
                               x2: float, y2: float) -> Tuple[float, float, float, float]:
    """
    计算点到线段的距离，返回 (距离, 最近点x, 最近点y, t参数)
    t 参数表示最近点在线段上的位置 (0=起点, 1=终点)
    使用经纬度近似计算（适用于小范围）
    """
    dx = x2 - x1
    dy = y2 - y1
    
    if dx == 0 and dy == 0:
        # 线段退化为点
        dist = haversine_distance(px, py, x1, y1)
        return dist, x1, y1, 0.0
    
    # 计算投影参数 t
    t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)
    t = max(0, min(1, t))  # 限制在 [0, 1]
    
    # 最近点
    nearest_x = x1 + t * dx
    nearest_y = y1 + t * dy
    
    dist = haversine_distance(px, py, nearest_x, nearest_y)
    return dist, nearest_x, nearest_y, t


def find_line_intersections(coords1: List[List[float]], coords2: List[List[float]], 
                            tolerance: float = 5.0) -> List[Tuple[int, float, float, float]]:
    """
    找出两条折线的交叉点
    返回: [(segment_index_in_coords1, t_param, intersect_lon, intersect_lat), ...]
    tolerance: 距离阈值（米）
    """
    intersections = []
    
    for i in range(len(coords1) - 1):
        x1, y1 = coords1[i]
        x2, y2 = coords1[i + 1]
        
        for j in range(len(coords2) - 1):
            x3, y3 = coords2[j]
            x4, y4 = coords2[j + 1]
            
            # 线段相交检测（使用参数方程）
            denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
            if abs(denom) < 1e-10:
                continue  # 平行
            
            t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
            u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom
            
            # 检查交点是否在两条线段内部（排除端点）
            if 0.01 < t < 0.99 and 0.01 < u < 0.99:
                ix = x1 + t * (x2 - x1)
                iy = y1 + t * (y2 - y1)
                intersections.append((i, t, ix, iy))
    
    return intersections


def point_to_segment_projection(px: float, py: float, 
                                 x1: float, y1: float, 
                                 x2: float, y2: float) -> Tuple[float, float, float]:
    """
    计算点到线段的投影
    返回: (t, proj_x, proj_y) 
    t 是投影点在线段上的参数 [0, 1]，小于0或大于1表示投影点在线段延长线上
    """
    dx = x2 - x1
    dy = y2 - y1
    
    if abs(dx) < 1e-10 and abs(dy) < 1e-10:
        return 0, x1, y1
    
    t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)
    
    proj_x = x1 + t * dx
    proj_y = y1 + t * dy
    
    return t, proj_x, proj_y


def find_endpoint_on_segment(endpoint: List[float], coords: List[List[float]], 
                              tolerance: float = 15.0) -> Optional[Tuple[int, float, float, float]]:
    """
    检查一个端点是否落在折线的某个线段上（不是端点位置）
    返回: (segment_idx, t, lon, lat) 或 None
    """
    px, py = endpoint
    
    for i in range(len(coords) - 1):
        x1, y1 = coords[i]
        x2, y2 = coords[i + 1]
        
        # 跳过端点位置（这些已经通过聚类处理）
        dist_to_start = haversine_distance(px, py, x1, y1)
        dist_to_end = haversine_distance(px, py, x2, y2)
        if dist_to_start < tolerance or dist_to_end < tolerance:
            continue
        
        # 计算投影
        t, proj_x, proj_y = point_to_segment_projection(px, py, x1, y1, x2, y2)
        
        # 检查投影点是否在线段内部
        if 0.01 < t < 0.99:
            dist = haversine_distance(px, py, proj_x, proj_y)
            if dist < tolerance:
                return (i, t, proj_x, proj_y)
    
    return None


def find_vertex_coincidences(coords1: List[List[float]], coords2: List[List[float]],
                             tolerance: float = 15.0) -> List[Tuple[int, float, float, float, int]]:
    """
    查找 coords1 的中间顶点与 coords2 的顶点重合或落在 coords2 线段上的情况
    返回: [(seg_idx_in_coords1, t, lon, lat, vertex_idx_in_coords2 or -1), ...]
    
    注意：只检查 coords1 的中间顶点（排除首尾端点）
    """
    results = []
    
    # 遍历 coords1 的中间顶点
    for v_idx in range(1, len(coords1) - 1):
        vx, vy = coords1[v_idx]
        
        # 检查与 coords2 的所有顶点是否重合
        for j, (cx, cy) in enumerate(coords2):
            dist = haversine_distance(vx, vy, cx, cy)
            if dist < tolerance:
                # 找到重合点，记录在 coords1 中的位置
                # seg_idx = v_idx - 1 (顶点 v_idx 在线段 v_idx-1 和 v_idx 之间)
                # t = 1.0 表示在线段末端
                results.append((v_idx - 1, 1.0, vx, vy, j))
                break  # 找到一个就够了
        else:
            # 没有与顶点重合，检查是否落在线段上
            for j in range(len(coords2) - 1):
                x1, y1 = coords2[j]
                x2, y2 = coords2[j + 1]
                
                t, proj_x, proj_y = point_to_segment_projection(vx, vy, x1, y1, x2, y2)
                
                if 0.01 < t < 0.99:
                    dist = haversine_distance(vx, vy, proj_x, proj_y)
                    if dist < tolerance:
                        results.append((v_idx - 1, 1.0, vx, vy, -1))
                        break
    
    return results


# ============================================================
# 数据结构
# ============================================================

@dataclass
class Node:
    node_id: int
    lon: float
    lat: float
    kind: str  # 'junction', 'lift_station', 'run_end'
    comment: str = ""
    merged_from: List[dict] = field(default_factory=list)  # 聚合来源 [{lon, lat, type, feat_id, feat_name}, ...]


@dataclass
class Edge:
    edge_id: int
    src_feat_type: str  # 'run' or 'lift'
    src_feat_id: str    # 原始 feature id
    src_sub_id: int     # 切分段号
    name: str
    uses: str           # 'downhill', 'nordic', etc.
    difficulty: str     # 'easy', 'intermediate', 'advanced', 'expert', 'novice'
    status: str
    oneway: bool
    from_node: int
    to_node: int
    length_m: float
    geom: str           # WKT LineString
    is_enabled: bool = True
    cost: float = 0.0
    note: str = ""
    lift_type: str = "" # gondola, chair_lift, drag_lift, etc.
    duration: int = 0   # 运行时长（秒）
    occupancy: int = 0  # 载客量
    osm_id: str = ""    # OpenStreetMap ID, e.g. "way/917201338"


@dataclass
class ReviewTask:
    task_type: str
    edge_id: Optional[int]
    node_id: Optional[int]
    description: str
    priority: str  # 'high', 'medium', 'low'
    data: Dict = field(default_factory=dict)


# ============================================================
# DBSCAN 端点聚类
# ============================================================

class SimpleDBSCAN:
    """简化版 DBSCAN，用于端点聚类"""
    
    def __init__(self, eps_meters: float = 5.0, min_samples: int = 1):
        self.eps = eps_meters
        self.min_samples = min_samples
    
    def fit(self, points: List[Tuple[float, float]]) -> List[int]:
        """
        对点进行聚类
        points: [(lon, lat), ...]
        返回: 每个点的 cluster label
        """
        n = len(points)
        labels = [-1] * n
        cluster_id = 0
        
        for i in range(n):
            if labels[i] != -1:
                continue
            
            # 找邻居
            neighbors = self._region_query(points, i)
            
            if len(neighbors) < self.min_samples:
                labels[i] = -2  # noise
                continue
            
            # 扩展聚类
            labels[i] = cluster_id
            seed_set = list(neighbors)
            
            j = 0
            while j < len(seed_set):
                q = seed_set[j]
                if labels[q] == -2:
                    labels[q] = cluster_id
                if labels[q] != -1:
                    j += 1
                    continue
                
                labels[q] = cluster_id
                q_neighbors = self._region_query(points, q)
                if len(q_neighbors) >= self.min_samples:
                    seed_set.extend(q_neighbors)
                j += 1
            
            cluster_id += 1
        
        # 将 noise 点也各自成为一个 cluster
        for i in range(n):
            if labels[i] == -2:
                labels[i] = cluster_id
                cluster_id += 1
        
        return labels
    
    def _region_query(self, points: List[Tuple[float, float]], idx: int) -> List[int]:
        """找出 eps 范围内的所有邻居点索引"""
        neighbors = []
        px, py = points[idx]
        for i, (x, y) in enumerate(points):
            if i != idx and haversine_distance(px, py, x, y) <= self.eps:
                neighbors.append(i)
        return neighbors


# ============================================================
# 预处理主逻辑
# ============================================================

class SkiGraphPreprocessor:
    def __init__(self, eps_meters: float = 5.0):
        self.eps = eps_meters
        self.nodes: List[Node] = []
        self.edges: List[Edge] = []
        self.review_tasks: List[ReviewTask] = []
        
        self._node_id_counter = 0
        self._edge_id_counter = 0
        
        # 点到节点的映射 (lon, lat) -> node_id
        self._point_to_node: Dict[Tuple[float, float], int] = {}
        
    def process(self, runs_geojson: dict, lifts_geojson: dict) -> None:
        """执行完整预处理流程"""
        print("Step 0: 读入并校验 GeoJSON...")
        runs = self._validate_features(runs_geojson, 'run')
        lifts = self._validate_features(lifts_geojson, 'lift')
        print(f"  - 有效雪道: {len(runs)}, 有效缆车: {len(lifts)}")
        
        print("Step 1: 收集所有端点...")
        endpoints = self._collect_endpoints(runs, lifts)
        print(f"  - 端点总数: {len(endpoints)}")
        
        print("Step 2: DBSCAN 聚类生成节点...")
        self._cluster_endpoints(endpoints)
        print(f"  - 生成节点: {len(self.nodes)}")
        
        print("Step 3: 检测 run-run 交叉点...")
        intersection_points = self._find_run_intersections(runs)
        print(f"  - 发现交叉点: {len(intersection_points)}")
        
        print("Step 4: 切分 runs 并构建边...")
        self._build_run_edges(runs, intersection_points)
        
        print("Step 5: 构建 lift 边...")
        self._build_lift_edges(lifts)
        print(f"  - 总边数: {len(self.edges)}")
        
        print("Step 6: 计算边的 cost...")
        self._calculate_costs()
        
        print("Step 7: 生成审核任务...")
        self._generate_review_tasks()
        print(f"  - 审核任务: {len(self.review_tasks)}")
    
    def _validate_features(self, geojson: dict, feat_type: str) -> List[dict]:
        """校验并过滤 GeoJSON features"""
        valid = []
        for feat in geojson.get('features', []):
            geom = feat.get('geometry', {})
            if geom.get('type') != 'LineString':
                continue
            coords = geom.get('coordinates', [])
            if len(coords) < 2:
                continue
            props = feat.get('properties', {})
            if props.get('type') != feat_type:
                # 有些数据 type 可能不完全匹配
                pass
            valid.append(feat)
        return valid
    
    def _collect_endpoints(self, runs: List[dict], lifts: List[dict]) -> List[Tuple[float, float, str, str, str]]:
        """
        收集所有端点
        返回: [(lon, lat, source_type, source_id, source_name), ...]
        """
        endpoints = []
        
        for feat in runs:
            coords = feat['geometry']['coordinates']
            feat_id = feat['properties'].get('id', '')
            feat_name = feat['properties'].get('name', '') or '(未命名)'
            # 起点和终点
            endpoints.append((coords[0][0], coords[0][1], 'run', feat_id, feat_name))
            endpoints.append((coords[-1][0], coords[-1][1], 'run', feat_id, feat_name))
        
        for feat in lifts:
            coords = feat['geometry']['coordinates']
            feat_id = feat['properties'].get('id', '')
            feat_name = feat['properties'].get('name', '') or '(未命名)'
            endpoints.append((coords[0][0], coords[0][1], 'lift', feat_id, feat_name))
            endpoints.append((coords[-1][0], coords[-1][1], 'lift', feat_id, feat_name))
        
        return endpoints
    
    def _cluster_endpoints(self, endpoints: List[Tuple[float, float, str, str, str]]) -> None:
        """对端点进行聚类，生成节点"""
        points = [(e[0], e[1]) for e in endpoints]
        
        dbscan = SimpleDBSCAN(eps_meters=self.eps, min_samples=1)
        labels = dbscan.fit(points)
        
        # 按聚类分组
        clusters: Dict[int, List[Tuple[float, float, str, str, str]]] = defaultdict(list)
        for i, label in enumerate(labels):
            clusters[label].append(endpoints[i])
        
        # 每个聚类生成一个节点
        for cluster_id, cluster_points in clusters.items():
            # 计算聚类中心
            avg_lon = sum(p[0] for p in cluster_points) / len(cluster_points)
            avg_lat = sum(p[1] for p in cluster_points) / len(cluster_points)
            
            # 确定节点类型
            has_lift = any(p[2] == 'lift' for p in cluster_points)
            kind = 'lift_station' if has_lift else 'junction'
            
            # 记录聚合来源
            merged_from = []
            for p in cluster_points:
                merged_from.append({
                    'lon': p[0],
                    'lat': p[1],
                    'type': p[2],
                    'feat_id': p[3],
                    'feat_name': p[4]
                })
            
            node = Node(
                node_id=self._node_id_counter,
                lon=avg_lon,
                lat=avg_lat,
                kind=kind,
                merged_from=merged_from
            )
            self.nodes.append(node)
            
            # 记录原始点到节点的映射
            for p in cluster_points:
                self._point_to_node[(p[0], p[1])] = node.node_id
            
            self._node_id_counter += 1
    
    def _find_nearest_node(self, lon: float, lat: float) -> int:
        """找到距离给定点最近的节点"""
        # 先查精确匹配
        if (lon, lat) in self._point_to_node:
            return self._point_to_node[(lon, lat)]
        
        # 否则找最近的
        min_dist = float('inf')
        nearest = 0
        for node in self.nodes:
            dist = haversine_distance(lon, lat, node.lon, node.lat)
            if dist < min_dist:
                min_dist = dist
                nearest = node.node_id
        return nearest
    
    def _find_run_intersections(self, runs: List[dict]) -> Dict[str, List[Tuple[int, float, float, float]]]:
        """
        找出所有 run-run 交叉点，包括：
        1. 两条线段在中间相交
        2. 一条 run 的端点落在另一条 run 的线段上
        3. 一条 run 的端点与另一条 run 的中间顶点重合
        返回: {run_id: [(segment_idx, t, lon, lat), ...]}
        """
        intersections: Dict[str, List] = defaultdict(list)
        
        # 收集所有 run 的信息
        run_data = []
        for i, run in enumerate(runs):
            run_id = run['properties'].get('id', str(i))
            coords = run['geometry']['coordinates']
            run_data.append((run_id, coords))
        
        for i, (id1, coords1) in enumerate(run_data):
            for j, (id2, coords2) in enumerate(run_data):
                if j <= i:
                    continue
                
                # 1. 查找线段-线段交叉点
                ints = find_line_intersections(coords1, coords2, tolerance=self.eps)
                for seg_idx, t, ix, iy in ints:
                    intersections[id1].append((seg_idx, t, ix, iy))
                
                # 反向也要检查
                ints_rev = find_line_intersections(coords2, coords1, tolerance=self.eps)
                for seg_idx, t, ix, iy in ints_rev:
                    intersections[id2].append((seg_idx, t, ix, iy))
                
                # 2. 检查 run1 的端点是否落在 run2 的线段上
                for endpoint in [coords1[0], coords1[-1]]:
                    result = find_endpoint_on_segment(endpoint, coords2, tolerance=self.eps)
                    if result:
                        seg_idx, t, proj_x, proj_y = result
                        intersections[id2].append((seg_idx, t, proj_x, proj_y))
                
                # 3. 检查 run2 的端点是否落在 run1 的线段上
                for endpoint in [coords2[0], coords2[-1]]:
                    result = find_endpoint_on_segment(endpoint, coords1, tolerance=self.eps)
                    if result:
                        seg_idx, t, proj_x, proj_y = result
                        intersections[id1].append((seg_idx, t, proj_x, proj_y))
                
                # 4. 检查 run1 的端点是否与 run2 的中间顶点重合
                for endpoint in [coords1[0], coords1[-1]]:
                    ex, ey = endpoint
                    for v_idx in range(1, len(coords2) - 1):  # 排除 run2 的首尾端点
                        vx, vy = coords2[v_idx]
                        dist = haversine_distance(ex, ey, vx, vy)
                        if dist < self.eps:
                            # 需要在 run2 的顶点位置切分
                            # 顶点 v_idx 在线段 (v_idx-1, v_idx) 的末端
                            intersections[id2].append((v_idx - 1, 1.0, vx, vy))
                            break
                
                # 5. 检查 run2 的端点是否与 run1 的中间顶点重合
                for endpoint in [coords2[0], coords2[-1]]:
                    ex, ey = endpoint
                    for v_idx in range(1, len(coords1) - 1):  # 排除 run1 的首尾端点
                        vx, vy = coords1[v_idx]
                        dist = haversine_distance(ex, ey, vx, vy)
                        if dist < self.eps:
                            # 需要在 run1 的顶点位置切分
                            intersections[id1].append((v_idx - 1, 1.0, vx, vy))
                            break
        
        # 去重和排序
        for run_id in intersections:
            # 去重（相近的点只保留一个）
            unique_ints = []
            for int_point in intersections[run_id]:
                is_dup = False
                for existing in unique_ints:
                    if (existing[0] == int_point[0] and 
                        abs(existing[1] - int_point[1]) < 0.01):
                        is_dup = True
                        break
                if not is_dup:
                    unique_ints.append(int_point)
            
            # 按 segment_idx 和 t 排序
            unique_ints.sort(key=lambda x: (x[0], x[1]))
            intersections[run_id] = unique_ints
        
        return intersections
    
    def _add_intersection_node(self, lon: float, lat: float) -> int:
        """为交叉点添加节点（如果不存在）"""
        # 检查是否已有足够近的节点
        for node in self.nodes:
            if haversine_distance(lon, lat, node.lon, node.lat) < self.eps:
                return node.node_id
        
        # 创建新节点
        node = Node(
            node_id=self._node_id_counter,
            lon=lon,
            lat=lat,
            kind='junction'
        )
        self.nodes.append(node)
        self._point_to_node[(lon, lat)] = node.node_id
        self._node_id_counter += 1
        return node.node_id
    
    def _build_run_edges(self, runs: List[dict],
                         intersections: Dict[str, List[Tuple[int, float, float, float]]]) -> None:
        """构建 run 的边，在交叉点处切分"""
        # 只处理这些 uses 类型的雪道
        ALLOWED_USES = {'snow_park', 'downhill', 'connection'}

        for feat in runs:
            props = feat['properties']
            feat_id = props.get('id', '')
            coords = feat['geometry']['coordinates']

            # 检查 uses 字段，只处理允许的类型
            uses_list = props.get('uses', [])
            if not any(use in ALLOWED_USES for use in uses_list):
                # 跳过不在允许列表中的雪道（如 nordic 越野道等）
                continue

            # 提取 OSM ID
            sources = props.get('sources', [])
            osm_id = next((s.get('id', '') for s in sources if s.get('type') == 'openstreetmap'), '')

            # 获取该 run 的所有切分点
            split_points = intersections.get(feat_id, [])

            # 构建切分后的段
            segments = self._split_line_at_points(coords, split_points)

            for sub_id, seg_coords in enumerate(segments):
                if len(seg_coords) < 2:
                    continue

                # 找到起点和终点对应的节点
                from_node = self._find_nearest_node(seg_coords[0][0], seg_coords[0][1])
                to_node = self._find_nearest_node(seg_coords[-1][0], seg_coords[-1][1])

                # 如果起点终点是同一个节点，跳过
                if from_node == to_node:
                    continue

                # 构建 WKT
                wkt = self._coords_to_wkt(seg_coords)

                edge = Edge(
                    edge_id=self._edge_id_counter,
                    src_feat_type='run',
                    src_feat_id=feat_id,
                    src_sub_id=sub_id,
                    name=props.get('name', '') or '',
                    uses=','.join(props.get('uses', [])),
                    difficulty=props.get('difficulty', '') or 'unknown',
                    status=props.get('status', 'operating'),
                    oneway=props.get('oneway', True),
                    from_node=from_node,
                    to_node=to_node,
                    length_m=line_length(seg_coords),
                    geom=wkt,
                    osm_id=osm_id
                )
                self.edges.append(edge)
                self._edge_id_counter += 1
    
    def _split_line_at_points(self, coords: List[List[float]], 
                               split_points: List[Tuple[int, float, float, float]]) -> List[List[List[float]]]:
        """
        在指定点处切分线段
        split_points: [(segment_idx, t, lon, lat), ...]
        返回: [segment_coords, ...]
        """
        if not split_points:
            return [coords]
        
        segments = []
        current_segment = [coords[0]]
        
        split_idx = 0
        
        for i in range(len(coords) - 1):
            # 处理当前段上的所有切分点
            while split_idx < len(split_points) and split_points[split_idx][0] == i:
                _, t, ix, iy = split_points[split_idx]
                
                # 添加切分点到当前段
                current_segment.append([ix, iy])
                segments.append(current_segment)
                
                # 为切分点创建节点
                self._add_intersection_node(ix, iy)
                
                # 开始新段
                current_segment = [[ix, iy]]
                split_idx += 1
            
            # 添加下一个原始点
            current_segment.append(coords[i + 1])
        
        if len(current_segment) >= 2:
            segments.append(current_segment)
        
        return segments
    
    def _build_lift_edges(self, lifts: List[dict]) -> None:
        """构建 lift 的边（不做中间切分）"""
        # 默认双向的缆车类型
        BIDIRECTIONAL_TYPES = {'gondola', 'cable_car', 'funicular'}
        
        for feat in lifts:
            props = feat['properties']
            feat_id = props.get('id', '')
            coords = feat['geometry']['coordinates']

            # 提取 OSM ID
            sources = props.get('sources', [])
            osm_id = next((s.get('id', '') for s in sources if s.get('type') == 'openstreetmap'), '')

            from_node = self._find_nearest_node(coords[0][0], coords[0][1])
            to_node = self._find_nearest_node(coords[-1][0], coords[-1][1])

            if from_node == to_node:
                continue

            wkt = self._coords_to_wkt(coords)
            lift_type = props.get('liftType', '') or props.get('aerialway', '') or 'unknown'
            
            # 根据缆车类型决定默认是否单向
            # gondola/cable_car/funicular 默认双向，其他（chair_lift/drag_lift/t-bar等）默认单向
            default_oneway = lift_type not in BIDIRECTIONAL_TYPES
            
            # 如果数据中有明确的 oneway 设置，使用数据中的值
            oneway_value = props.get('oneway')
            if oneway_value is not None:
                if isinstance(oneway_value, bool):
                    is_oneway = oneway_value
                elif isinstance(oneway_value, str):
                    is_oneway = oneway_value.lower() in ('yes', 'true', '1')
                else:
                    is_oneway = default_oneway
            else:
                is_oneway = default_oneway
            
            # 获取运行时长（秒）
            duration = props.get('duration')
            if duration:
                # 可能是 "PT5M" 格式或数字
                if isinstance(duration, str) and duration.startswith('PT'):
                    # 解析 ISO 8601 duration
                    import re
                    match = re.match(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?', duration)
                    if match:
                        h, m, s = match.groups()
                        duration = int(h or 0) * 3600 + int(m or 0) * 60 + int(s or 0)
                    else:
                        duration = 0
                elif isinstance(duration, (int, float)):
                    duration = int(duration)
                else:
                    duration = 0
            else:
                duration = 0
            
            # 获取载客量
            occupancy = props.get('occupancy', 0) or 0
            
            edge = Edge(
                edge_id=self._edge_id_counter,
                src_feat_type='lift',
                src_feat_id=feat_id,
                src_sub_id=0,
                name=props.get('name', '') or '',
                uses='lift',
                difficulty='',
                status=props.get('status', 'operating'),
                oneway=is_oneway,
                from_node=from_node,
                to_node=to_node,
                length_m=line_length(coords),
                geom=wkt,
                lift_type=lift_type,
                duration=duration,
                occupancy=occupancy,
                osm_id=osm_id
            )
            self.edges.append(edge)
            self._edge_id_counter += 1

    def _coords_to_wkt(self, coords: List[List[float]]) -> str:
        """坐标转 WKT LineString"""
        points_str = ', '.join(f'{c[0]} {c[1]}' for c in coords)
        return f'LINESTRING({points_str})'
    
    def _calculate_costs(self) -> None:
        """计算边的 cost（默认使用长度）"""
        for edge in self.edges:
            if edge.src_feat_type == 'lift':
                # 缆车 cost 设为 0（鼓励使用）
                edge.cost = 0.0
            else:
                # 雪道 cost = 长度
                edge.cost = edge.length_m
    
    def _generate_review_tasks(self) -> None:
        """生成需要人工审核的任务"""
        # 1. 无名称的边
        for edge in self.edges:
            if not edge.name:
                self.review_tasks.append(ReviewTask(
                    task_type='missing_name',
                    edge_id=edge.edge_id,
                    node_id=None,
                    description=f"Edge {edge.edge_id} ({edge.src_feat_type}) 缺少名称",
                    priority='low'
                ))
        
        # 2. 未知难度的雪道
        for edge in self.edges:
            if edge.src_feat_type == 'run' and edge.difficulty in ('unknown', '', None):
                self.review_tasks.append(ReviewTask(
                    task_type='missing_difficulty',
                    edge_id=edge.edge_id,
                    node_id=None,
                    description=f"Edge {edge.edge_id} ({edge.name or 'unnamed'}) 缺少难度标识",
                    priority='medium'
                ))
        
        # 3. 孤立节点（只连接一条边）
        node_edge_count: Dict[int, int] = defaultdict(int)
        for edge in self.edges:
            node_edge_count[edge.from_node] += 1
            node_edge_count[edge.to_node] += 1
        
        for node in self.nodes:
            if node_edge_count[node.node_id] == 1:
                self.review_tasks.append(ReviewTask(
                    task_type='isolated_node',
                    edge_id=None,
                    node_id=node.node_id,
                    description=f"Node {node.node_id} ({node.kind}) 可能是孤立端点",
                    priority='low',
                    data={'lon': node.lon, 'lat': node.lat}
                ))
        
        # 4. 需要确认方向的边（oneway=True 的雪道）
        for edge in self.edges:
            if edge.src_feat_type == 'run' and edge.oneway:
                self.review_tasks.append(ReviewTask(
                    task_type='check_direction',
                    edge_id=edge.edge_id,
                    node_id=None,
                    description=f"Edge {edge.edge_id} ({edge.name or 'unnamed'}) 需要确认滑行方向",
                    priority='high'
                ))
    
    def save_sqlite(self, output_path: str, runs_hash: str, lifts_hash: str) -> None:
        """保存到 SQLite"""
        conn = sqlite3.connect(output_path)
        cur = conn.cursor()
        
        # 删除已存在的表
        cur.execute('DROP TABLE IF EXISTS node_sources')
        cur.execute('DROP TABLE IF EXISTS edges')
        cur.execute('DROP TABLE IF EXISTS nodes')
        cur.execute('DROP TABLE IF EXISTS meta')
        
        # 创建表
        cur.execute('''
            CREATE TABLE IF NOT EXISTS meta (
                key TEXT PRIMARY KEY,
                value TEXT
            )
        ''')
        
        cur.execute('''
            CREATE TABLE IF NOT EXISTS nodes (
                node_id INTEGER PRIMARY KEY,
                lon REAL NOT NULL,
                lat REAL NOT NULL,
                kind TEXT,
                comment TEXT
            )
        ''')
        
        cur.execute('''
            CREATE TABLE IF NOT EXISTS node_sources (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                node_id INTEGER,
                lon REAL,
                lat REAL,
                source_type TEXT,
                feat_id TEXT,
                feat_name TEXT,
                FOREIGN KEY (node_id) REFERENCES nodes(node_id)
            )
        ''')
        
        cur.execute('''
            CREATE TABLE IF NOT EXISTS edges (
                edge_id INTEGER PRIMARY KEY,
                src_feat_type TEXT,
                src_feat_id TEXT,
                src_sub_id INTEGER,
                name TEXT,
                uses TEXT,
                difficulty TEXT,
                status TEXT,
                oneway INTEGER,
                from_node INTEGER,
                to_node INTEGER,
                length_m REAL,
                geom TEXT,
                is_enabled INTEGER DEFAULT 1,
                cost REAL,
                note TEXT,
                lift_type TEXT,
                duration INTEGER,
                occupancy INTEGER,
                osm_id TEXT,
                FOREIGN KEY (from_node) REFERENCES nodes(node_id),
                FOREIGN KEY (to_node) REFERENCES nodes(node_id)
            )
        ''')
        
        # 写入 meta
        cur.execute('INSERT OR REPLACE INTO meta VALUES (?, ?)', ('version', '1.0'))
        cur.execute('INSERT OR REPLACE INTO meta VALUES (?, ?)', ('runs_hash', runs_hash))
        cur.execute('INSERT OR REPLACE INTO meta VALUES (?, ?)', ('lifts_hash', lifts_hash))
        cur.execute('INSERT OR REPLACE INTO meta VALUES (?, ?)', ('node_count', str(len(self.nodes))))
        cur.execute('INSERT OR REPLACE INTO meta VALUES (?, ?)', ('edge_count', str(len(self.edges))))
        
        # 写入 nodes
        for node in self.nodes:
            cur.execute('''
                INSERT INTO nodes (node_id, lon, lat, kind, comment)
                VALUES (?, ?, ?, ?, ?)
            ''', (node.node_id, node.lon, node.lat, node.kind, node.comment))
            
            # 写入聚合来源
            for source in node.merged_from:
                cur.execute('''
                    INSERT INTO node_sources (node_id, lon, lat, source_type, feat_id, feat_name)
                    VALUES (?, ?, ?, ?, ?, ?)
                ''', (node.node_id, source['lon'], source['lat'], 
                      source['type'], source['feat_id'], source['feat_name']))
        
        # 写入 edges
        for edge in self.edges:
            cur.execute('''
                INSERT INTO edges (edge_id, src_feat_type, src_feat_id, src_sub_id,
                                   name, uses, difficulty, status, oneway,
                                   from_node, to_node, length_m, geom,
                                   is_enabled, cost, note,
                                   lift_type, duration, occupancy, osm_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (edge.edge_id, edge.src_feat_type, edge.src_feat_id, edge.src_sub_id,
                  edge.name, edge.uses, edge.difficulty, edge.status,
                  1 if edge.oneway else 0,
                  edge.from_node, edge.to_node, edge.length_m, edge.geom,
                  1 if edge.is_enabled else 0, edge.cost, edge.note,
                  edge.lift_type, edge.duration, edge.occupancy, edge.osm_id))
        
        # 创建索引
        cur.execute('CREATE INDEX IF NOT EXISTS idx_edges_from ON edges(from_node)')
        cur.execute('CREATE INDEX IF NOT EXISTS idx_edges_to ON edges(to_node)')
        cur.execute('CREATE INDEX IF NOT EXISTS idx_edges_src ON edges(src_feat_id, src_sub_id)')
        cur.execute('CREATE INDEX IF NOT EXISTS idx_node_sources ON node_sources(node_id)')
        
        conn.commit()
        conn.close()
    
    def save_review_tasks(self, output_path: str) -> None:
        """保存审核任务到 JSON"""
        tasks = []
        for task in self.review_tasks:
            tasks.append({
                'task_type': task.task_type,
                'edge_id': task.edge_id,
                'node_id': task.node_id,
                'description': task.description,
                'priority': task.priority,
                'data': task.data
            })
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(tasks, f, ensure_ascii=False, indent=2)


def compute_file_hash(filepath: str) -> str:
    """计算文件 MD5 hash"""
    with open(filepath, 'rb') as f:
        return hashlib.md5(f.read()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description='SnowNavi 滑雪导航图预处理')
    parser.add_argument('runs', help='runs.geojson 文件路径')
    parser.add_argument('lifts', help='lifts.geojson 文件路径')
    parser.add_argument('-o', '--output', default='ski_graph.sqlite', help='输出 SQLite 文件')
    parser.add_argument('-r', '--review', default='review_tasks.json', help='输出审核任务文件')
    parser.add_argument('--eps', type=float, default=5.0, help='端点聚类半径（米）')
    
    args = parser.parse_args()
    
    # 读取 GeoJSON
    print(f"读取 {args.runs}...")
    with open(args.runs, 'r', encoding='utf-8') as f:
        runs_geojson = json.load(f)
    
    print(f"读取 {args.lifts}...")
    with open(args.lifts, 'r', encoding='utf-8') as f:
        lifts_geojson = json.load(f)
    
    # 计算 hash
    runs_hash = compute_file_hash(args.runs)
    lifts_hash = compute_file_hash(args.lifts)
    print(f"源文件 hash: runs={runs_hash[:8]}, lifts={lifts_hash[:8]}")
    
    # 预处理
    processor = SkiGraphPreprocessor(eps_meters=args.eps)
    processor.process(runs_geojson, lifts_geojson)
    
    # 保存结果
    print(f"\n保存到 {args.output}...")
    processor.save_sqlite(args.output, runs_hash, lifts_hash)
    
    print(f"保存审核任务到 {args.review}...")
    processor.save_review_tasks(args.review)
    
    print("\n完成!")
    print(f"  - 节点: {len(processor.nodes)}")
    print(f"  - 边: {len(processor.edges)}")
    print(f"  - 待审核: {len(processor.review_tasks)}")


if __name__ == '__main__':
    main()
