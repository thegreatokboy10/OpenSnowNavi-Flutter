#!/usr/bin/env python3
"""
SnowNavi 滑雪导航引擎
支持多途经点和多备选路线的路径规划

主要功能:
1. 从 SQLite 加载图数据
2. Dijkstra 最短路径算法
3. 多途经点路由
4. K 条备选路线 (Yen's algorithm)
"""

import sqlite3
import heapq
import math
from typing import List, Dict, Tuple, Optional, Any, Set
from dataclasses import dataclass, field
from collections import defaultdict, deque


# ============================================================
# 数据结构
# ============================================================

@dataclass
class Node:
    node_id: int
    lon: float
    lat: float
    kind: str

@dataclass
class Edge:
    """原始边（来自 SQLite）"""
    edge_id: int
    from_node: int
    to_node: int
    length_m: float
    cost: float
    src_feat_type: str  # 'run' or 'lift'
    name: str
    difficulty: str
    oneway: bool
    is_enabled: bool
    lift_type: str = ""
    duration: int = 0
    geom: str = ""

@dataclass
class DirectedEdge:
    """
    有向边（内存中使用）

    每条 SQLite 边生成 1-2 条有向边：
    - 正向边: directed_id = base_edge_id * 2
    - 反向边: directed_id = base_edge_id * 2 + 1
    """
    directed_id: int       # 有向边唯一ID
    base_edge_id: int      # 原始边ID（用于获取几何、名称等属性）
    from_node: int         # 有向边起点
    to_node: int           # 有向边终点
    is_reversed: bool      # 是否是反向边
    length_m: float
    cost: float
    src_feat_type: str
    name: str
    difficulty: str
    lift_type: str = ""
    duration: int = 0

@dataclass
class RoutePath:
    """单条路径结果"""
    edges: List[int]           # 边ID列表（有向边ID）
    nodes: List[int]           # 节点ID列表
    total_cost: float          # 总代价
    total_length: float        # 总长度(米)
    segments: List[dict] = field(default_factory=list)  # 分段详情

@dataclass
class SnappedPoint:
    """坐标匹配结果"""
    original_lon: float        # 原始经度
    original_lat: float        # 原始纬度
    snapped_lon: float         # 匹配后经度
    snapped_lat: float         # 匹配后纬度
    node_id: int               # 匹配到的节点ID（用于路由）
    edge_id: Optional[int]     # 匹配到的边ID（如果匹配到边上）
    distance_m: float          # 原始点到匹配点的距离（米）
    is_on_node: bool           # 是否直接匹配到节点

@dataclass
class RouteResult:
    """路由结果，包含多条备选路线"""
    routes: List[RoutePath]    # 按代价排序的路线列表
    waypoints: List[int]       # 途经点节点ID
    start_node: int
    end_node: int
    success: bool
    error: str = ""
    # 坐标匹配信息（可选）
    start_snapped: Optional[SnappedPoint] = None
    end_snapped: Optional[SnappedPoint] = None
    waypoints_snapped: List[SnappedPoint] = field(default_factory=list)


# ============================================================
# 图加载器
# ============================================================

class SkiGraph:
    """滑雪场图结构 - 使用显式有向边"""

    def __init__(self, db_path: str):
        self.db_path = db_path
        self.nodes: Dict[int, Node] = {}
        self.edges: Dict[int, Edge] = {}  # 原始边（用于获取几何、名称等）

        # 有向边存储
        self.directed_edges: Dict[int, DirectedEdge] = {}  # directed_id -> DirectedEdge

        # 邻接表 - 只存有向边
        # node_id -> [(directed_edge_id, to_node), ...]
        self.adjacency: Dict[int, List[Tuple[int, int]]] = defaultdict(list)
        # 反向邻接表（用于从终点反向搜索）
        self.reverse_adj: Dict[int, List[Tuple[int, int]]] = defaultdict(list)

        self._load_graph()

    def _make_directed_id(self, base_edge_id: int, is_reversed: bool) -> int:
        """生成有向边ID: 正向=base*2, 反向=base*2+1"""
        return base_edge_id * 2 + (1 if is_reversed else 0)

    def _get_base_edge_id(self, directed_id: int) -> int:
        """从有向边ID获取原始边ID"""
        return directed_id // 2

    def _is_reversed_edge(self, directed_id: int) -> bool:
        """判断有向边是否是反向边"""
        return directed_id % 2 == 1

    def get_base_edge(self, directed_id: int) -> Optional[Edge]:
        """从有向边ID获取原始边对象"""
        base_id = self._get_base_edge_id(directed_id)
        return self.edges.get(base_id)

    def _load_graph(self) -> None:
        """从 SQLite 加载图数据，生成显式有向边"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()

        # 加载节点
        for row in cur.execute('SELECT node_id, lon, lat, kind FROM nodes'):
            self.nodes[row['node_id']] = Node(
                node_id=row['node_id'],
                lon=row['lon'],
                lat=row['lat'],
                kind=row['kind'] or 'junction'
            )

        # 加载边并生成有向边
        for row in cur.execute('''
            SELECT edge_id, from_node, to_node, length_m, cost,
                   src_feat_type, name, difficulty, oneway, is_enabled,
                   lift_type, duration, geom
            FROM edges WHERE is_enabled = 1
        '''):
            # 保存原始边
            edge = Edge(
                edge_id=row['edge_id'],
                from_node=row['from_node'],
                to_node=row['to_node'],
                length_m=row['length_m'] or 0,
                cost=row['cost'] or row['length_m'] or 0,
                src_feat_type=row['src_feat_type'] or 'run',
                name=row['name'] or '',
                difficulty=row['difficulty'] or 'unknown',
                oneway=bool(row['oneway']),
                is_enabled=bool(row['is_enabled']),
                lift_type=row['lift_type'] or '',
                duration=row['duration'] or 0,
                geom=row['geom'] or ''
            )
            self.edges[edge.edge_id] = edge

            # 生成正向有向边
            fwd_id = self._make_directed_id(edge.edge_id, False)
            fwd_edge = DirectedEdge(
                directed_id=fwd_id,
                base_edge_id=edge.edge_id,
                from_node=edge.from_node,
                to_node=edge.to_node,
                is_reversed=False,
                length_m=edge.length_m,
                cost=edge.cost,
                src_feat_type=edge.src_feat_type,
                name=edge.name,
                difficulty=edge.difficulty,
                lift_type=edge.lift_type,
                duration=edge.duration
            )
            self.directed_edges[fwd_id] = fwd_edge
            self.adjacency[edge.from_node].append((fwd_id, edge.to_node))
            self.reverse_adj[edge.to_node].append((fwd_id, edge.from_node))

            # 如果不是单向边，生成反向有向边
            if not edge.oneway:
                rev_id = self._make_directed_id(edge.edge_id, True)
                rev_edge = DirectedEdge(
                    directed_id=rev_id,
                    base_edge_id=edge.edge_id,
                    from_node=edge.to_node,
                    to_node=edge.from_node,
                    is_reversed=True,
                    length_m=edge.length_m,
                    cost=edge.cost,
                    src_feat_type=edge.src_feat_type,
                    name=edge.name,
                    difficulty=edge.difficulty,
                    lift_type=edge.lift_type,
                    duration=edge.duration
                )
                self.directed_edges[rev_id] = rev_edge
                self.adjacency[edge.to_node].append((rev_id, edge.from_node))
                self.reverse_adj[edge.from_node].append((rev_id, edge.to_node))

        conn.close()

    def get_all_edges_json(self) -> List[dict]:
        """获取所有边的 JSON 格式（用于前端渲染）"""
        result = []
        for edge in self.edges.values():
            result.append({
                'edge_id': edge.edge_id,
                'from_node': edge.from_node,
                'to_node': edge.to_node,
                'length_m': edge.length_m,
                'name': edge.name,
                'difficulty': edge.difficulty,
                'src_feat_type': edge.src_feat_type,
                'lift_type': edge.lift_type,
                'oneway': edge.oneway,
                'geom': edge.geom
            })
        return result

    def get_all_nodes_json(self) -> List[dict]:
        """获取所有节点的 JSON 格式"""
        result = []
        for node in self.nodes.values():
            result.append({
                'node_id': node.node_id,
                'lon': node.lon,
                'lat': node.lat,
                'kind': node.kind
            })
        return result


# ============================================================
# 代价函数
# ============================================================

DIFFICULTY_LEVELS = {
    'novice': 1,
    'easy': 2,
    'intermediate': 3,
    'advanced': 4,
    'expert': 5,
    'unknown': 3,
    '': 3
}

def get_difficulty_level(difficulty: str) -> int:
    """获取难度等级数值"""
    return DIFFICULTY_LEVELS.get(difficulty, 3)

def calculate_edge_cost(edge: Edge, preferences: dict = None) -> float:
    """计算边的路由代价（原始 Edge 版本）"""
    if preferences is None:
        preferences = {}

    max_diff = preferences.get('max_difficulty', 'expert')
    max_diff_level = get_difficulty_level(max_diff)

    if edge.src_feat_type == 'run':
        edge_diff_level = get_difficulty_level(edge.difficulty)
        if edge_diff_level > max_diff_level:
            return float('inf')

    if edge.src_feat_type == 'lift':
        if edge.duration > 0:
            base_cost = edge.duration
        else:
            base_cost = edge.length_m / 5.0
        if preferences.get('prefer_lifts', False):
            base_cost *= 0.5
    else:
        diff_level = get_difficulty_level(edge.difficulty)
        speed = 18 - diff_level * 2
        base_cost = edge.length_m / speed

    return base_cost

def calculate_directed_edge_cost(directed_edge: DirectedEdge, preferences: dict = None) -> float:
    """计算有向边的路由代价"""
    if preferences is None:
        preferences = {}

    max_diff = preferences.get('max_difficulty', 'expert')
    max_diff_level = get_difficulty_level(max_diff)

    if directed_edge.src_feat_type == 'run':
        edge_diff_level = get_difficulty_level(directed_edge.difficulty)
        if edge_diff_level > max_diff_level:
            return float('inf')

    if directed_edge.src_feat_type == 'lift':
        if directed_edge.duration > 0:
            base_cost = directed_edge.duration
        else:
            base_cost = directed_edge.length_m / 5.0
        if preferences.get('prefer_lifts', False):
            base_cost *= 0.5
    else:
        diff_level = get_difficulty_level(directed_edge.difficulty)
        speed = 18 - diff_level * 2
        base_cost = directed_edge.length_m / speed

    return base_cost


# ============================================================
# 坐标匹配 (Snap to Graph)
# ============================================================

def haversine_distance(lon1: float, lat1: float, lon2: float, lat2: float) -> float:
    """计算两点间的大圆距离（米）"""
    R = 6371000
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)

    a = math.sin(dphi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

def point_to_segment_distance(px: float, py: float, x1: float, y1: float, x2: float, y2: float) -> Tuple[float, float, float]:
    """点到线段最近点"""
    dx = x2 - x1
    dy = y2 - y1
    if dx == 0 and dy == 0:
        return x1, y1, 0.0
    t = max(0, min(1, ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)))
    return x1 + t * dx, y1 + t * dy, t

def parse_linestring_wkt(wkt: str) -> List[Tuple[float, float]]:
    """解析 WKT LINESTRING 格式"""
    if not wkt:
        return []
    match = wkt.replace('LINESTRING(', '').replace(')', '')
    points = []
    for pt in match.split(','):
        parts = pt.strip().split()
        if len(parts) >= 2:
            try:
                lon, lat = float(parts[0]), float(parts[1])
                points.append((lon, lat))
            except ValueError:
                continue
    return points

def snap_to_graph(graph: 'SkiGraph', lon: float, lat: float, max_distance_m: float = 500.0) -> Optional[SnappedPoint]:
    """将 GPS 坐标匹配到图上最近的点"""
    best_result = None
    best_distance = float('inf')

    for edge_id, edge in graph.edges.items():
        if not edge.geom:
            from_node = graph.nodes.get(edge.from_node)
            to_node = graph.nodes.get(edge.to_node)
            if from_node and to_node:
                points = [(from_node.lon, from_node.lat), (to_node.lon, to_node.lat)]
            else:
                continue
        else:
            points = parse_linestring_wkt(edge.geom)

        if len(points) < 2:
            continue

        for i in range(len(points) - 1):
            x1, y1 = points[i]
            x2, y2 = points[i + 1]

            nearest_x, nearest_y, t = point_to_segment_distance(lon, lat, x1, y1, x2, y2)
            distance = haversine_distance(lon, lat, nearest_x, nearest_y)

            if distance < best_distance:
                best_distance = distance

                if i == 0 and t < 0.1:
                    node_id = edge.from_node
                    node = graph.nodes[node_id]
                    best_result = SnappedPoint(lon, lat, node.lon, node.lat, node_id, edge_id, distance, True)
                elif i == len(points) - 2 and t > 0.9:
                    node_id = edge.to_node
                    node = graph.nodes[node_id]
                    best_result = SnappedPoint(lon, lat, node.lon, node.lat, node_id, edge_id, distance, True)
                else:
                    from_node = graph.nodes[edge.from_node]
                    to_node = graph.nodes[edge.to_node]
                    dist_from = haversine_distance(nearest_x, nearest_y, from_node.lon, from_node.lat)
                    dist_to = haversine_distance(nearest_x, nearest_y, to_node.lon, to_node.lat)
                    node_id = edge.from_node if dist_from <= dist_to else edge.to_node
                    best_result = SnappedPoint(lon, lat, nearest_x, nearest_y, node_id, edge_id, distance, False)

    for node_id, node in graph.nodes.items():
        distance = haversine_distance(lon, lat, node.lon, node.lat)
        if distance < best_distance:
            best_distance = distance
            best_result = SnappedPoint(lon, lat, node.lon, node.lat, node_id, None, distance, True)

    if best_result and best_distance <= max_distance_m:
        return best_result
    return None


# ============================================================
# Dijkstra 最短路径算法
# ============================================================

def dijkstra(
    graph: SkiGraph,
    start: int,
    end: int,
    preferences: dict = None,
    excluded_edges: Set[int] = None,
    excluded_nodes: Set[int] = None
) -> Optional[Tuple[List[int], List[int], float]]:
    """Dijkstra - 基于有向边"""
    if start not in graph.nodes or end not in graph.nodes:
        return None

    if excluded_edges is None:
        excluded_edges = set()
    if excluded_nodes is None:
        excluded_nodes = set()

    dist = {start: 0.0}
    prev = {}
    pq = [(0.0, start)]
    visited = set()

    while pq:
        current_cost, current = heapq.heappop(pq)

        if current in visited:
            continue
        visited.add(current)

        if current == end:
            break

        for directed_id, neighbor in graph.adjacency.get(current, []):
            if neighbor in visited:
                continue
            if directed_id in excluded_edges:
                continue
            if neighbor in excluded_nodes:
                continue

            directed_edge = graph.directed_edges.get(directed_id)
            if not directed_edge:
                continue

            edge_cost = calculate_directed_edge_cost(directed_edge, preferences)
            if edge_cost == float('inf'):
                continue

            new_cost = current_cost + edge_cost

            if neighbor not in dist or new_cost < dist[neighbor]:
                dist[neighbor] = new_cost
                prev[neighbor] = (current, directed_id)
                heapq.heappush(pq, (new_cost, neighbor))

    if end not in prev and start != end:
        return None

    node_path = [end]
    edge_path = []
    current = end

    while current != start:
        if current not in prev:
            return None
        prev_node, directed_id = prev[current]
        edge_path.append(directed_id)
        node_path.append(prev_node)
        current = prev_node

    node_path.reverse()
    edge_path.reverse()

    return edge_path, node_path, dist[end]


# ============================================================
# 多途经点路径规划
# ============================================================

def route_with_waypoints(
    graph: SkiGraph,
    start: int,
    end: int,
    waypoints: List[int] = None,
    preferences: dict = None
) -> Optional[RoutePath]:
    """支持途经点的路径规划"""
    if waypoints is None:
        waypoints = []

    all_points = [start] + waypoints + [end]

    all_edges = []
    all_nodes = [start]
    total_cost = 0.0
    total_length = 0.0
    segments = []

    for i in range(len(all_points) - 1):
        from_node = all_points[i]
        to_node = all_points[i + 1]

        result = dijkstra(graph, from_node, to_node, preferences)
        if result is None:
            return None

        edge_ids, node_ids, cost = result

        all_edges.extend(edge_ids)
        all_nodes.extend(node_ids[1:])
        total_cost += cost

        seg_length = sum(graph.directed_edges[eid].length_m for eid in edge_ids if eid in graph.directed_edges)
        total_length += seg_length

        segments.append({
            'from_node': from_node,
            'to_node': to_node,
            'edge_count': len(edge_ids),
            'length_m': seg_length,
            'cost': cost
        })

    return RoutePath(edges=all_edges, nodes=all_nodes, total_cost=total_cost, total_length=total_length, segments=segments)


# ============================================================
# 反向可达性检查
# ============================================================

def get_reachable_nodes_from_end(graph: SkiGraph, end: int, preferences: dict = None) -> Set[int]:
    """从终点在反向图上做 BFS，找出所有能到达终点的节点"""
    if end not in graph.nodes:
        return set()

    reachable = {end}
    queue = deque([end])

    while queue:
        current = queue.popleft()

        for directed_id, prev_node in graph.reverse_adj.get(current, []):
            if prev_node in reachable:
                continue

            directed_edge = graph.directed_edges.get(directed_id)
            if not directed_edge:
                continue

            if preferences:
                max_diff = preferences.get('max_difficulty', 'expert')
                max_diff_level = get_difficulty_level(max_diff)
                if directed_edge.src_feat_type == 'run':
                    edge_diff_level = get_difficulty_level(directed_edge.difficulty)
                    if edge_diff_level > max_diff_level:
                        continue

            reachable.add(prev_node)
            queue.append(prev_node)

    return reachable


# ============================================================
# Yen's K-Shortest Paths 算法 + 重合度计算
# ============================================================

def calculate_overlap(edges1: List[int], edges2: List[int]) -> float:
    """边集合重合度（较短集合为分母）"""
    if not edges1 or not edges2:
        return 0.0
    set1 = set(edges1)
    set2 = set(edges2)
    intersection = len(set1 & set2)
    min_len = min(len(set1), len(set2))
    return intersection / min_len

def calculate_prefix_overlap(edges1: List[int], edges2: List[int]) -> float:
    """前缀重合比例"""
    if not edges1 or not edges2:
        return 0.0
    min_len = min(len(edges1), len(edges2))
    common_prefix = 0
    for i in range(min_len):
        if edges1[i] == edges2[i]:
            common_prefix += 1
        else:
            break
    return common_prefix / min_len

def calculate_jaccard_overlap(edges1: List[int], edges2: List[int]) -> float:
    """Jaccard 相似度"""
    if not edges1 or not edges2:
        return 0.0
    set1 = set(edges1)
    set2 = set(edges2)
    intersection = len(set1 & set2)
    union = len(set1 | set2)
    return intersection / union if union > 0 else 0.0

def calculate_path_similarity(edges1: List[int], edges2: List[int], prefix_weight: float = 0.6) -> float:
    """综合相似度：prefix + jaccard"""
    prefix = calculate_prefix_overlap(edges1, edges2)
    jaccard = calculate_jaccard_overlap(edges1, edges2)
    return prefix_weight * prefix + (1 - prefix_weight) * jaccard


# ============================================================
# K-Shortest Paths (Yen) with overlap filter
# ============================================================

def k_shortest_paths(
    graph: SkiGraph,
    start: int,
    end: int,
    k: int = 3,
    preferences: dict = None,
    max_overlap: float = 0.8,
    excluded_nodes: Set[int] = None
) -> List[Tuple[List[int], List[int], float]]:
    """Yen's K-最短路径算法，带重合度过滤"""
    first_path = dijkstra(graph, start, end, preferences, excluded_nodes=excluded_nodes)
    if first_path is None:
        return []

    A = [first_path]
    B = []
    rejected_edge_sets = set()
    max_iterations = k * 10
    iteration = 0
    k_idx = 0

    while len(A) < k and iteration < max_iterations:
        iteration += 1

        if k_idx < len(A):
            prev_edges, prev_nodes, _ = A[k_idx]
            k_idx += 1

            for i in range(len(prev_nodes) - 1):
                spur_node = prev_nodes[i]
                root_path_edges = prev_edges[:i]
                root_path_nodes = prev_nodes[:i + 1]

                excluded_edges_local = set()
                for path_edges, path_nodes, _ in A:
                    if len(path_nodes) > i and path_nodes[:i + 1] == root_path_nodes:
                        if i < len(path_edges):
                            excluded_edges_local.add(path_edges[i])

                excluded_nodes_local = set(root_path_nodes[:-1])
                if excluded_nodes:
                    excluded_nodes_local.update(excluded_nodes)

                spur_result = dijkstra(graph, spur_node, end, preferences, excluded_edges_local, excluded_nodes_local)

                if spur_result is not None:
                    spur_edges, spur_nodes, _ = spur_result

                    total_edges = root_path_edges + spur_edges
                    total_nodes = root_path_nodes + spur_nodes[1:]
                    edge_tuple = tuple(total_edges)

                    if edge_tuple in rejected_edge_sets:
                        continue

                    total_cost = sum(
                        calculate_directed_edge_cost(graph.directed_edges[eid], preferences)
                        for eid in total_edges
                        if eid in graph.directed_edges
                    )

                    path_tuple = (edge_tuple, tuple(total_nodes), total_cost)

                    is_duplicate = False
                    for existing in A:
                        if tuple(existing[0]) == edge_tuple:
                            is_duplicate = True
                            break
                    if not is_duplicate:
                        for _, existing in B:
                            if existing[0] == edge_tuple:
                                is_duplicate = True
                                break

                    if not is_duplicate:
                        heapq.heappush(B, (total_cost, path_tuple))

        while B:
            _, best = heapq.heappop(B)
            best_edges = list(best[0])

            overlap_too_high = False
            for existing_edges, _, _ in A:
                overlap = calculate_overlap(best_edges, existing_edges)
                if overlap > max_overlap:
                    overlap_too_high = True
                    rejected_edge_sets.add(best[0])
                    break

            if not overlap_too_high:
                A.append((best_edges, list(best[1]), best[2]))
                break

        if not B and k_idx >= len(A):
            break

    return A


# ============================================================
# 多样性路由（候选生成 + MMR 选取）
# ============================================================

def generate_diverse_candidates(
    graph: SkiGraph,
    start: int,
    end: int,
    preferences: dict = None,
    max_candidates: int = 50,
    k_per_exit: int = 3,
    k_global: int = 15
) -> List[Tuple[List[int], List[int], float]]:
    """生成多样化候选集：按起点出口分桶 + 全局补充"""
    candidates = []
    seen_edge_tuples = set()

    reachable = get_reachable_nodes_from_end(graph, end, preferences)

    adjacent = graph.adjacency.get(start, [])

    for directed_id, next_node in adjacent:
        if next_node not in reachable:
            continue

        directed_edge = graph.directed_edges.get(directed_id)
        if not directed_edge:
            continue

        first_edge_cost = calculate_directed_edge_cost(directed_edge, preferences)
        if first_edge_cost == float('inf'):
            continue

        sub_paths = k_shortest_paths(
            graph, next_node, end, k_per_exit, preferences,
            max_overlap=1.0, excluded_nodes={start}
        )

        for sub_edges, sub_nodes, sub_cost in sub_paths:
            full_edges = [directed_id] + sub_edges
            full_nodes = [start] + sub_nodes
            full_cost = first_edge_cost + sub_cost

            edge_tuple = tuple(full_edges)
            if edge_tuple not in seen_edge_tuples:
                seen_edge_tuples.add(edge_tuple)
                candidates.append((full_edges, full_nodes, full_cost))

        if next_node == end:
            edge_tuple = (directed_id,)
            if edge_tuple not in seen_edge_tuples:
                seen_edge_tuples.add(edge_tuple)
                candidates.append(([directed_id], [start, end], first_edge_cost))

    global_paths = k_shortest_paths(graph, start, end, k_global, preferences, max_overlap=1.0)

    for edges, nodes, cost in global_paths:
        edge_tuple = tuple(edges)
        if edge_tuple not in seen_edge_tuples:
            seen_edge_tuples.add(edge_tuple)
            candidates.append((edges, nodes, cost))

    if len(candidates) > max_candidates:
        candidates.sort(key=lambda x: x[2])
        candidates = candidates[:max_candidates]

    return candidates

def select_diverse_routes(
    candidates: List[Tuple[List[int], List[int], float]],
    n: int = 3,
    detour_ratio: float = 0.6,
    lambda_quality: float = 0.5,
    prefix_weight: float = 0.6
) -> List[Tuple[List[int], List[int], float]]:
    """MMR 选取多样化路径"""
    if not candidates:
        return []
    if len(candidates) <= n:
        return candidates

    sorted_candidates = sorted(candidates, key=lambda x: x[2])
    selected = [sorted_candidates[0]]
    best_cost = sorted_candidates[0][2]
    max_allowed_cost = best_cost * (1 + detour_ratio)

    selected_first_edges = {sorted_candidates[0][0][0]} if sorted_candidates[0][0] else set()
    remaining = sorted_candidates[1:]

    while len(selected) < n and remaining:
        best_score = float('-inf')
        best_idx = -1

        for i, (edges, _, cost) in enumerate(remaining):
            if cost > max_allowed_cost:
                continue

            max_sim = 0.0
            for sel_edges, _, _ in selected:
                sim = calculate_path_similarity(edges, sel_edges, prefix_weight)
                max_sim = max(max_sim, sim)

            relative_detour = (cost - best_cost) / best_cost if best_cost > 0 else 0
            quality = max(0.0, 1.0 - relative_detour / detour_ratio) if detour_ratio > 0 else 0.0

            first_edge = edges[0] if edges else None
            first_edge_bonus = 0.3 if first_edge and first_edge not in selected_first_edges else 0.0

            score = lambda_quality * quality + first_edge_bonus - (1 - lambda_quality) * max_sim

            if score > best_score:
                best_score = score
                best_idx = i

        if best_idx >= 0:
            chosen = remaining.pop(best_idx)
            selected.append(chosen)
            if chosen[0]:
                selected_first_edges.add(chosen[0][0])
        else:
            break

    return selected

def diverse_k_paths(
    graph: SkiGraph,
    start: int,
    end: int,
    k: int = 3,
    preferences: dict = None,
    detour_ratio: float = 0.6,
    prefix_weight: float = 0.6
) -> List[Tuple[List[int], List[int], float]]:
    """多样性优先 K 路径"""
    k_per_exit = max(3, k * 2)
    k_global = max(10, k * 5)
    max_candidates = max(50, k * 20)

    candidates = generate_diverse_candidates(
        graph, start, end, preferences,
        max_candidates=max_candidates,
        k_per_exit=k_per_exit,
        k_global=k_global
    )

    if not candidates:
        return []

    selected = select_diverse_routes(
        candidates, k,
        detour_ratio=detour_ratio,
        prefix_weight=prefix_weight
    )

    return selected


# ============================================================
# 主路由 API
# ============================================================

def route_with_waypoints_excluded(
    graph: SkiGraph,
    start: int,
    end: int,
    waypoints: List[int],
    preferences: dict,
    excluded_edges: Set[int]
) -> Optional[RoutePath]:
    """带排除边的途经点路径规划"""
    if waypoints is None:
        waypoints = []

    all_points = [start] + waypoints + [end]

    all_edges = []
    all_nodes = [start]
    total_cost = 0.0
    total_length = 0.0
    segments = []

    for i in range(len(all_points) - 1):
        from_node = all_points[i]
        to_node = all_points[i + 1]

        result = dijkstra(graph, from_node, to_node, preferences, excluded_edges)
        if result is None:
            result = dijkstra(graph, from_node, to_node, preferences)

        if result is None:
            return None

        edge_ids, node_ids, cost = result
        all_edges.extend(edge_ids)
        all_nodes.extend(node_ids[1:])
        total_cost += cost

        seg_length = sum(graph.directed_edges[eid].length_m for eid in edge_ids if eid in graph.directed_edges)
        total_length += seg_length

        segments.append({
            'from_node': from_node,
            'to_node': to_node,
            'edge_count': len(edge_ids),
            'length_m': seg_length,
            'cost': cost
        })

    return RoutePath(edges=all_edges, nodes=all_nodes, total_cost=total_cost, total_length=total_length, segments=segments)

def plan_route(
    graph: SkiGraph,
    start: int,
    end: int,
    waypoints: List[int] = None,
    num_alternatives: int = 3,
    preferences: dict = None,
    max_overlap: float = 0.8,
    use_diverse_routing: bool = True,
    detour_ratio: float = 2.6
) -> RouteResult:
    """规划路线的主入口"""
    if waypoints is None:
        waypoints = []

    num_alternatives = min(num_alternatives, 3)
    max_overlap = max(0.0, min(1.0, max_overlap))
    detour_ratio = max(0.0, max(1.0, detour_ratio))

    if start not in graph.nodes:
        return RouteResult(routes=[], waypoints=waypoints, start_node=start, end_node=end, success=False, error=f"起点节点 {start} 不存在")
    if end not in graph.nodes:
        return RouteResult(routes=[], waypoints=waypoints, start_node=start, end_node=end, success=False, error=f"终点节点 {end} 不存在")
    for wp in waypoints:
        if wp not in graph.nodes:
            return RouteResult(routes=[], waypoints=waypoints, start_node=start, end_node=end, success=False, error=f"途经点节点 {wp} 不存在")

    routes = []

    if len(waypoints) == 0:
        if use_diverse_routing:
            k_paths = diverse_k_paths(graph, start, end, num_alternatives, preferences, detour_ratio=detour_ratio)
        else:
            k_paths = k_shortest_paths(graph, start, end, num_alternatives, preferences, max_overlap)

        for edge_ids, node_ids, cost in k_paths:
            total_length = sum(graph.directed_edges[eid].length_m for eid in edge_ids if eid in graph.directed_edges)
            routes.append(RoutePath(
                edges=edge_ids,
                nodes=node_ids,
                total_cost=cost,
                total_length=total_length,
                segments=[{
                    'from_node': start,
                    'to_node': end,
                    'edge_count': len(edge_ids),
                    'length_m': total_length,
                    'cost': cost
                }]
            ))
    else:
        main_route = route_with_waypoints(graph, start, end, waypoints, preferences)
        if main_route:
            routes.append(main_route)

        if num_alternatives > 1 and main_route:
            alt_prefs = dict(preferences) if preferences else {}
            excluded = set(main_route.edges)

            alt_route = route_with_waypoints_excluded(graph, start, end, waypoints, alt_prefs, excluded)
            if alt_route and alt_route.edges != main_route.edges:
                overlap = calculate_overlap(alt_route.edges, main_route.edges)
                if overlap <= max_overlap:
                    routes.append(alt_route)

    if not routes:
        return RouteResult(routes=[], waypoints=waypoints, start_node=start, end_node=end, success=False, error="无法找到可行路径")

    return RouteResult(routes=routes, waypoints=waypoints, start_node=start, end_node=end, success=True)

def plan_route_coords(
    graph: SkiGraph,
    start_lon: float,
    start_lat: float,
    end_lon: float,
    end_lat: float,
    waypoints_coords: List[Tuple[float, float]] = None,
    num_alternatives: int = 3,
    preferences: dict = None,
    max_overlap: float = 0.8,
    max_snap_distance_m: float = 500.0,
    use_diverse_routing: bool = True,
    detour_ratio: float = 1.6
) -> RouteResult:
    """使用 GPS 坐标规划路线"""
    if waypoints_coords is None:
        waypoints_coords = []

    start_snapped = snap_to_graph(graph, start_lon, start_lat, max_snap_distance_m)
    if start_snapped is None:
        return RouteResult(routes=[], waypoints=[], start_node=-1, end_node=-1, success=False,
                           error=f"起点坐标 ({start_lon}, {start_lat}) 无法匹配到路网（超出最大距离 {max_snap_distance_m}m）")

    end_snapped = snap_to_graph(graph, end_lon, end_lat, max_snap_distance_m)
    if end_snapped is None:
        return RouteResult(routes=[], waypoints=[], start_node=-1, end_node=-1, success=False,
                           error=f"终点坐标 ({end_lon}, {end_lat}) 无法匹配到路网（超出最大距离 {max_snap_distance_m}m）")

    waypoints_snapped = []
    waypoint_node_ids = []
    for i, (wp_lon, wp_lat) in enumerate(waypoints_coords):
        wp_snapped = snap_to_graph(graph, wp_lon, wp_lat, max_snap_distance_m)
        if wp_snapped is None:
            return RouteResult(routes=[], waypoints=[], start_node=-1, end_node=-1, success=False,
                               error=f"途经点 {i+1} 坐标 ({wp_lon}, {wp_lat}) 无法匹配到路网")
        waypoints_snapped.append(wp_snapped)
        waypoint_node_ids.append(wp_snapped.node_id)

    result = plan_route(
        graph,
        start_snapped.node_id,
        end_snapped.node_id,
        waypoints=waypoint_node_ids,
        num_alternatives=num_alternatives,
        preferences=preferences,
        max_overlap=max_overlap,
        use_diverse_routing=use_diverse_routing,
        detour_ratio=detour_ratio
    )

    result.start_snapped = start_snapped
    result.end_snapped = end_snapped
    result.waypoints_snapped = waypoints_snapped

    return result


# ============================================================
# 探索模式（你关心的部分）
# ============================================================

@dataclass
class ExploreResult:
    """探索模式结果"""
    routes: List[RoutePath]
    first_edges: List[int]
    first_edge_names: List[str]
    start_node: int
    end_node: int
    success: bool
    error: str = ""
    start_snapped: Optional[SnappedPoint] = None
    end_snapped: Optional[SnappedPoint] = None


# ------------------------------
# 新增：Anchor 相关 helper（核心修复）
# ------------------------------

def is_lift_station_node(graph: SkiGraph, node_id: int) -> bool:
    """判断是否缆车站/入口节点：优先看 node.kind，其次看是否存在 lift 边连接"""
    node = graph.nodes.get(node_id)
    if not node:
        return False

    kind = (node.kind or "").lower()
    if "lift" in kind or "station" in kind or "entry" in kind:
        return True

    for eid, _ in graph.adjacency.get(node_id, []):
        de = graph.directed_edges.get(eid)
        if de and de.src_feat_type == "lift":
            return True
    for eid, _ in graph.reverse_adj.get(node_id, []):
        de = graph.directed_edges.get(eid)
        if de and de.src_feat_type == "lift":
            return True

    return False

def _edge_passable(graph: SkiGraph, directed_id: int, preferences: dict, reachable: Optional[Set[int]]) -> Optional[int]:
    """返回该边可通行时的 to_node，否则 None"""
    de = graph.directed_edges.get(directed_id)
    if not de:
        return None

    if reachable is not None and de.to_node not in reachable:
        return None

    if preferences and "max_difficulty" in preferences and de.src_feat_type == "run":
        max_level = get_difficulty_level(preferences["max_difficulty"])
        if get_difficulty_level(de.difficulty) > max_level:
            return None

    if calculate_directed_edge_cost(de, preferences) == float("inf"):
        return None

    return de.to_node

def limited_reach_nodes_from(
    graph: SkiGraph,
    start_node: int,
    preferences: dict,
    reachable: Optional[Set[int]],
    max_dist_m: float,
    start_dist_m: float = 0.0
) -> Dict[int, float]:
    """
    在 length 距离约束下，从 start_node 向前扩展，返回 node -> 最短累计长度(米)
    用于 200m 内的“局部可达”判定（不是最短路 cost）
    """
    best = {start_node: start_dist_m}
    pq = [(start_dist_m, start_node)]

    while pq:
        dist, u = heapq.heappop(pq)
        if dist != best.get(u, float("inf")):
            continue
        if dist > max_dist_m:
            continue

        for eid, _ in graph.adjacency.get(u, []):
            v = _edge_passable(graph, eid, preferences, reachable)
            if v is None:
                continue
            nd = dist + graph.directed_edges[eid].length_m
            if nd > max_dist_m:
                continue
            if nd < best.get(v, float("inf")):
                best[v] = nd
                heapq.heappush(pq, (nd, v))

    return best

def compute_start_merge_nodes(
    graph: SkiGraph,
    start: int,
    preferences: dict,
    reachable: Optional[Set[int]],
    max_prefix_length: float
) -> Set[int]:
    """
    只计算“起点各出口之间”的 merge nodes（更严格版本，解决 25/771/926 这种第一跳就被当 merge 的问题）

    修复点：
    1) node 必须被 >=2 个不同出口可达（exit 去重）
    2) node 必须满足：从 start 出发的“最短可达距离”（跨所有出口）也 >= MIN_MERGE_DIST_M
       ——避免“绕路>=60m”把“其实15m就能到”的节点污染成 merge
    3) 排除 first-hop nodes（起点第一跳 to_node），避免 anchor 永远停在第一步
    """

    adjacent = graph.adjacency.get(start, [])
    if not adjacent:
        print(f"[MERGE] start={start} no outgoing edges")
        return set()

    MIN_MERGE_DIST_M = 60.0  # 你现在用的 60

    # 起点第一跳节点集合：这些节点如果当 merge，会导致“第一跳就停”
    first_hop_nodes: Set[int] = set()
    for first_eid, nxt in adjacent:
        de0 = graph.directed_edges.get(first_eid)
        if not de0:
            continue
        if _edge_passable(graph, first_eid, preferences, reachable) is None:
            continue
        first_hop_nodes.add(de0.to_node)

    # node -> set(exits) （出口去重）
    node_sources: Dict[int, Set[int]] = defaultdict(set)

    # node -> min_dist_from_start_across_all_exits
    # 这个用于避免“绕路>=MIN”污染
    node_min_dist: Dict[int, float] = {}

    usable_exits = 0

    for first_eid, _ in adjacent:
        de0 = graph.directed_edges.get(first_eid)
        if not de0:
            continue

        if _edge_passable(graph, first_eid, preferences, reachable) is None:
            continue

        start_dist = float(de0.length_m or 0.0)
        if start_dist > max_prefix_length:
            continue

        usable_exits += 1

        reach_map = limited_reach_nodes_from(
            graph,
            start_node=de0.to_node,
            preferences=preferences,
            reachable=reachable,
            max_dist_m=max_prefix_length,
            start_dist_m=start_dist
        )

        # reach_map: node -> dist_from_start（长度累计）
        for node_id, dist_m in reach_map.items():
            # 先记录全局最短距离（跨出口取 min）
            prev = node_min_dist.get(node_id)
            if prev is None or dist_m < prev:
                node_min_dist[node_id] = dist_m

            # 这里先不做 MIN 过滤，让 sources 统计“哪些出口能到”
            node_sources[node_id].add(first_eid)

    # ---- 选 merge nodes：严格条件 ----
    merge_nodes = set()
    for nid, exits in node_sources.items():
        if nid == start:
            continue
        if nid in first_hop_nodes:
            continue
        if len(exits) < 2:
            continue

        md = node_min_dist.get(nid, float("inf"))
        if md < MIN_MERGE_DIST_M:
            # 如果“从 start 的最短距离”还很小，就不是我们想要的汇合点
            continue

        merge_nodes.add(nid)

    # ---- debug ----
    print(f"[MERGE] start={start} max_prefix_length={max_prefix_length} usable_exits={usable_exits}")
    print(f"[MERGE] first_hop_nodes={len(first_hop_nodes)} raw_candidate_nodes={len(node_sources)} merge_nodes={len(merge_nodes)} min_merge_dist={MIN_MERGE_DIST_M}")

    # 打印共享度最高的节点（含 min_dist），帮助你确认是否合理
    top = sorted(
        [(nid, len(exits), node_min_dist.get(nid, None)) for nid, exits in node_sources.items()],
        key=lambda x: (-x[1], x[0])
    )[:20]

    if top:
        print("[MERGE] top shared nodes (including min_dist):")
        for nid, c, md in top:
            flag = []
            if nid in first_hop_nodes:
                flag.append("FIRST_HOP")
            if md is not None and md < MIN_MERGE_DIST_M:
                flag.append("TOO_CLOSE")
            fs = ",".join(flag) if flag else ""
            print(f"  node={nid} shared_by_exits={c} min_dist={md:.1f} {fs}")

    return merge_nodes

def find_first_anchor_in_budget(
    graph: SkiGraph,
    from_node: int,
    preferences: dict,
    reachable: Optional[Set[int]],
    merge_nodes: Set[int],
    end: int,
    max_dist_m: float
) -> Optional[int]:
    """
    从 from_node 出发，在 max_dist_m 距离预算内找到最近的 anchor candidate：
    1) end
    2) lift station node
    3) merge_nodes
    找不到返回 None
    """
    best = {from_node: 0.0}
    pq = [(0.0, from_node)]

    while pq:
        dist, u = heapq.heappop(pq)
        if dist != best.get(u, float("inf")):
            continue
        if dist > max_dist_m:
            continue

        if u == end:
            return u
        if is_lift_station_node(graph, u):
            return u
        if u in merge_nodes:
            return u

        for eid, _ in graph.adjacency.get(u, []):
            v = _edge_passable(graph, eid, preferences, reachable)
            if v is None:
                continue
            nd = dist + graph.directed_edges[eid].length_m
            if nd > max_dist_m:
                continue
            if nd < best.get(v, float("inf")):
                best[v] = nd
                heapq.heappush(pq, (nd, v))

    return None


# ------------------------------
# 替换：find_anchor_node（修复重复路线关键）
# ------------------------------
def find_anchor_node(
    graph: SkiGraph,
    start: int,
    first_edge_id: int,
    preferences: dict = None,
    max_prefix_length: float = 300.0,
    reachable: Set[int] = None,
    merge_nodes: Set[int] = None,
    end: int = None
) -> Tuple[int, List[int], List[int], float]:
    """
    从起点沿指定出边向前走，找到第一个"稳定节点"(anchor node)

    关键策略（含你要求的优化 A）：
    - lift station：保持原逻辑，遇到就停（强制 anchor）
    - 不再因为 in_degree>1 立刻停（避免“无关汇合”过早截断）
    - 如果 valid_out_edges==0：做一次 relax（忽略 reachable 再试一次），避免 reachable 误杀导致过早停
    - 分岔(out>1)：lookahead 判断真假分岔
        * 若所有分支在剩余预算内会导向同一个 anchor_candidate => 假分岔，继续压缩
        * 否则 => 真分岔，在当前节点停
    - anchor 条件：
        1) prefix_length >= max_prefix_length
        2) 到达终点
        3) lift station node（强制）
        4) 命中 merge_nodes（如果你传入，用于合并“起点出口之间”的共同汇合点）
    """
    if preferences is None:
        preferences = {}
    if merge_nodes is None:
        merge_nodes = set()
    if end is None:
        end = -1

    first_edge = graph.directed_edges.get(first_edge_id)
    if not first_edge:
        print(f"[ANCHOR] invalid first_edge_id={first_edge_id}, fallback start={start}")
        return start, [], [start], 0.0

    prefix_edges = [first_edge_id]
    prefix_nodes = [start, first_edge.to_node]
    prefix_length = float(first_edge.length_m or 0.0)
    current_node = first_edge.to_node
    visited = {start, current_node}

    print(f"[ANCHOR] start={start} first_edge={first_edge_id} to={current_node} "
          f"len={prefix_length:.1f}/{max_prefix_length:.1f} end={end}")

    def _collect_valid_out_edges(node: int, use_reachable: bool) -> Tuple[List[Tuple[int, int]], int]:
        """
        返回 (valid_out_edges, out_total)
        valid_out_edges: [(eid, next_node), ...]
        out_total: adjacency 中原始出边数量（未过滤）
        """
        out_edges = graph.adjacency.get(node, [])
        valid = []
        for eid, nxt in out_edges:
            # 1) visited 防环
            if nxt in visited:
                continue

            # 2) reachable 过滤（可选）
            if use_reachable and reachable is not None:
                if nxt not in reachable:
                    continue

            # 3) 统一边可通行性过滤（你已有的 _edge_passable）
            #    注意：我们这里把 reachable 交给上面控制，所以传 reachable=None，避免重复过滤
            v = _edge_passable(graph, eid, preferences, None)
            if v is None:
                continue

            # _edge_passable 可能返回实际 next_node（或修正后的 node），所以用 v
            if v in visited:
                continue

            valid.append((eid, v))
        return valid, len(out_edges)

    # 用于 debug：格式化 candidates
    def _fmt_candidates(cands: List[Tuple[int, int, Optional[int]]]) -> str:
        # cands: [(eid, next_node, anchor_candidate), ...]
        parts = []
        for eid, nxt, cand in cands:
            de = graph.directed_edges.get(eid)
            l = de.length_m if de else 0.0
            parts.append(f"(eid={eid},to={nxt},len={l:.1f},cand={cand})")
        return "[" + ", ".join(parts) + "]"

    relaxed_once = False  # 优化A：只 relax 一次，避免失控

    while True:
        # ---- stop conditions (hard) ----
        if prefix_length >= max_prefix_length:
            print(f"[ANCHOR] stop: max_prefix_length node={current_node} len={prefix_length:.1f}")
            break

        if current_node == end:
            print(f"[ANCHOR] stop: reached end node={current_node} len={prefix_length:.1f}")
            break

        if is_lift_station_node(graph, current_node):
            print(f"[ANCHOR] stop: lift station node={current_node} len={prefix_length:.1f}")
            break

        if current_node in merge_nodes:
            print(f"[ANCHOR] stop: hit merge_nodes node={current_node} len={prefix_length:.1f}")
            break

        # ---- collect valid outs (strict) ----
        valid_out_edges, out_total = _collect_valid_out_edges(current_node, use_reachable=True)

        print(f"[ANCHOR] node={current_node} prefix={prefix_length:.1f}m out_total={out_total} "
              f"valid_out={len(valid_out_edges)} relaxed={relaxed_once}")

        # ---- Optimization A: if no valid outs, relax reachable once ----
        if len(valid_out_edges) == 0 and (not relaxed_once) and reachable is not None:
            relaxed_once = True
            relaxed_valid, relaxed_out_total = _collect_valid_out_edges(current_node, use_reachable=False)
            print(f"[ANCHOR] relax: ignore reachable at node={current_node} "
                  f"out_total={relaxed_out_total} relaxed_valid_out={len(relaxed_valid)}")

            # 如果 relax 后有路，继续用 relax 的结果走（但后续仍回到严格 reachable）
            if len(relaxed_valid) > 0:
                valid_out_edges = relaxed_valid
                out_total = relaxed_out_total
            else:
                print(f"[ANCHOR] stop: deadend after relax node={current_node} len={prefix_length:.1f}")
                break

        # 仍然没有路
        if len(valid_out_edges) == 0:
            print(f"[ANCHOR] stop: deadend node={current_node} len={prefix_length:.1f}")
            break

        # ---- single path: keep compressing ----
        if len(valid_out_edges) == 1:
            next_edge_id, next_node = valid_out_edges[0]
            next_edge = graph.directed_edges.get(next_edge_id)
            if not next_edge:
                print(f"[ANCHOR] stop: missing directed_edge eid={next_edge_id} at node={current_node}")
                break

            prefix_edges.append(next_edge_id)
            prefix_nodes.append(next_node)
            prefix_length += float(next_edge.length_m or 0.0)
            visited.add(next_node)
            current_node = next_node
            continue

        # ---- branching: lookahead真假分岔 ----
        remaining = max(0.0, max_prefix_length - prefix_length)
        if remaining <= 0:
            print(f"[ANCHOR] stop: no remaining budget at node={current_node}")
            break

        candidates = []
        for eid, nxt in valid_out_edges:
            cand = find_first_anchor_in_budget(
                graph=graph,
                from_node=nxt,
                preferences=preferences,
                reachable=reachable,
                merge_nodes=merge_nodes,
                end=end,
                max_dist_m=remaining
            )
            candidates.append((eid, nxt, cand))

        print(f"[ANCHOR] branching at node={current_node} remaining={remaining:.1f} "
              f"candidates={_fmt_candidates(candidates)}")

        # 如果剩余预算内全看不到 anchor_candidate：把当前当 anchor，避免压缩失控
        if all(c[2] is None for c in candidates):
            print(f"[ANCHOR] stop: branching but no anchor in budget node={current_node} len={prefix_length:.1f}")
            break

        # 注意：去掉 None 再判断是否“全部相同”
        non_null = [c[2] for c in candidates if c[2] is not None]
        if len(non_null) == 0:
            print(f"[ANCHOR] stop: no non-null candidates node={current_node}")
            break

        cand_set = set(non_null)

        # 假分岔：所有分支都导向同一个 anchor_candidate
        if len(cand_set) == 1:
            # 继续压缩：选一条“最短的下一条边”推进（也可以按 cost/length 规则）
            candidates.sort(key=lambda x: (x[2] is None, (graph.directed_edges.get(x[0]).length_m if graph.directed_edges.get(x[0]) else 1e9)))
            next_edge_id, next_node, same_cand = candidates[0]

            next_edge = graph.directed_edges.get(next_edge_id)
            if not next_edge:
                print(f"[ANCHOR] stop: missing next_edge in fake-branch eid={next_edge_id}")
                break

            print(f"[ANCHOR] fake-branch: all->cand={same_cand}, choose eid={next_edge_id} to={next_node}")
            prefix_edges.append(next_edge_id)
            prefix_nodes.append(next_node)
            prefix_length += float(next_edge.length_m or 0.0)
            visited.add(next_node)
            current_node = next_node
            continue

        # 真分岔：导向不同 anchor_candidate，当前就是决策点 => 停
        print(f"[ANCHOR] stop: true-branch node={current_node} cand_set={sorted(list(cand_set))} len={prefix_length:.1f}")
        break

    return current_node, prefix_edges, prefix_nodes, prefix_length


def explore_routes(
    graph: SkiGraph,
    start: int,
    end: int,
    preferences: dict = None,
    max_overlap: float = 0.8,
    max_prefix_length: float = 200.0
) -> ExploreResult:
    """
    探索模式：按 anchor_node 分桶，展示真正不同的决策分支

    修复点：
    - 只认“起点出口之间”的 merge nodes（避免无关汇合误触发）
    - 分岔点 lookahead（避免“分岔就停”导致重复）
    """
    if preferences is None:
        preferences = {}

    if start not in graph.nodes:
        return ExploreResult(routes=[], first_edges=[], first_edge_names=[],
                            start_node=start, end_node=end, success=False,
                            error=f"起点节点 {start} 不存在")
    if end not in graph.nodes:
        return ExploreResult(routes=[], first_edges=[], first_edge_names=[],
                            start_node=start, end_node=end, success=False,
                            error=f"终点节点 {end} 不存在")

    reachable = get_reachable_nodes_from_end(graph, end, preferences)
    if start not in reachable:
        return ExploreResult(routes=[], first_edges=[], first_edge_names=[],
                            start_node=start, end_node=end, success=False,
                            error=f"从起点 {start} 无法到达终点 {end}")

    adjacent_edges = graph.adjacency.get(start, [])
    if not adjacent_edges:
        return ExploreResult(routes=[], first_edges=[], first_edge_names=[],
                            start_node=start, end_node=end, success=False,
                            error=f"起点节点 {start} 没有可用的出边")

    # ✅ 新增：只计算“起点出口之间”的 merge nodes
    merge_nodes = compute_start_merge_nodes(
        graph=graph,
        start=start,
        preferences=preferences,
        reachable=reachable,
        max_prefix_length=max_prefix_length
    )

    anchor_buckets: Dict[int, List[Tuple[List[int], List[int], float, int, str]]] = {}

    for directed_id, next_node in adjacent_edges:
        directed_edge = graph.directed_edges.get(directed_id)
        if not directed_edge:
            continue

        if next_node not in reachable:
            continue

        if 'max_difficulty' in preferences and directed_edge.src_feat_type == 'run':
            max_level = get_difficulty_level(preferences['max_difficulty'])
            edge_level = get_difficulty_level(directed_edge.difficulty)
            if edge_level > max_level:
                continue

        edge_cost = calculate_directed_edge_cost(directed_edge, preferences)
        if edge_cost == float('inf'):
            continue

        base_edge = graph.get_base_edge(directed_id)
        edge_name = base_edge.name if base_edge and base_edge.name else f"Edge {directed_edge.base_edge_id}"

        anchor_node, prefix_edges, prefix_nodes, prefix_length = find_anchor_node(
            graph=graph,
            start=start,
            first_edge_id=directed_id,
            preferences=preferences,
            max_prefix_length=max_prefix_length,
            reachable=reachable,
            merge_nodes=merge_nodes,
            end=end
        )

        print(
            f"[EXPLORE] first_edge={directed_id} "
            f"to={next_node} "
            f"anchor={anchor_node} "
            f"prefix_len={prefix_length:.1f}m "
            f"prefix_edges={len(prefix_edges)} "
            f"edge_name={edge_name}"
        )


        if anchor_node not in anchor_buckets:
            anchor_buckets[anchor_node] = []
        anchor_buckets[anchor_node].append((prefix_edges, prefix_nodes, prefix_length, directed_id, edge_name))

    if not anchor_buckets:
        return ExploreResult(routes=[], first_edges=[], first_edge_names=[],
                            start_node=start, end_node=end, success=False,
                            error="没有找到任何可达的分支")

    print("\n[EXPLORE] anchor buckets summary:")
    for a, bucket in sorted(anchor_buckets.items(), key=lambda x: -len(x[1])):
        names = [b[4] for b in bucket[:3]]
        print(f"  anchor={a} count={len(bucket)} sample_first_edges={names}")


    all_routes = []

    for anchor_node, bucket in anchor_buckets.items():
        bucket.sort(key=lambda x: x[2])  # prefix_length
        prefix_edges, prefix_nodes, prefix_length, first_edge_id, edge_name = bucket[0]

        prefix_cost = sum(
            calculate_directed_edge_cost(graph.directed_edges[eid], preferences)
            for eid in prefix_edges
            if eid in graph.directed_edges
        )

        if anchor_node == end:
            route = RoutePath(
                edges=prefix_edges,
                nodes=prefix_nodes,
                total_cost=prefix_cost,
                total_length=prefix_length,
                segments=[{
                    'from_node': start,
                    'to_node': end,
                    'edge_count': len(prefix_edges),
                    'length_m': prefix_length,
                    'cost': prefix_cost
                }]
            )
            all_routes.append((route, first_edge_id, edge_name))
        else:
            excluded = set(prefix_nodes[:-1])
            result = dijkstra(graph, anchor_node, end, preferences, excluded_nodes=excluded)
            if result is not None:
                edge_ids, node_ids, cost = result
                full_edges = prefix_edges + edge_ids
                full_nodes = prefix_nodes[:-1] + node_ids
                full_cost = prefix_cost + cost
                full_length = prefix_length + sum(graph.directed_edges[eid].length_m for eid in edge_ids if eid in graph.directed_edges)

                route = RoutePath(
                    edges=full_edges,
                    nodes=full_nodes,
                    total_cost=full_cost,
                    total_length=full_length,
                    segments=[{
                        'from_node': start,
                        'to_node': end,
                        'edge_count': len(full_edges),
                        'length_m': full_length,
                        'cost': full_cost
                    }]
                )
                all_routes.append((route, first_edge_id, edge_name))

    if not all_routes:
        return ExploreResult(routes=[], first_edges=[], first_edge_names=[],
                            start_node=start, end_node=end, success=False,
                            error="没有找到从任何分支到达终点的路线")

    all_routes.sort(key=lambda x: x[0].total_cost)

    filtered_routes = []
    filtered_edges = []
    filtered_names = []

    for route, edge_id, edge_name in all_routes:
        dominated = False
        for existing_route in filtered_routes:
            # 用综合相似度（prefix+jaccard），更能干掉“后面又汇合导致看起来重复”的路线
            sim = calculate_path_similarity(route.edges, existing_route.edges, prefix_weight=0.01)
            if sim > max_overlap:
                dominated = True
                break

        if not dominated:
            filtered_routes.append(route)
            filtered_edges.append(edge_id)
            filtered_names.append(edge_name)

    return ExploreResult(
        routes=filtered_routes,
        first_edges=filtered_edges,
        first_edge_names=filtered_names,
        start_node=start,
        end_node=end,
        success=True
    )


def explore_routes_coords(
    graph: SkiGraph,
    start_lon: float,
    start_lat: float,
    end_lon: float,
    end_lat: float,
    preferences: dict = None,
    max_overlap: float = 0.8,
    max_snap_distance_m: float = 500.0,
    max_prefix_length: float = 200.0
) -> ExploreResult:
    """使用坐标的探索模式"""
    start_snapped = snap_to_graph(graph, start_lon, start_lat, max_snap_distance_m)
    if start_snapped is None:
        return ExploreResult(routes=[], first_edges=[], first_edge_names=[],
                            start_node=-1, end_node=-1, success=False,
                            error="起点坐标无法匹配到路网")

    end_snapped = snap_to_graph(graph, end_lon, end_lat, max_snap_distance_m)
    if end_snapped is None:
        return ExploreResult(routes=[], first_edges=[], first_edge_names=[],
                            start_node=-1, end_node=-1, success=False,
                            error="终点坐标无法匹配到路网")

    result = explore_routes(
        graph,
        start_snapped.node_id,
        end_snapped.node_id,
        preferences=preferences,
        max_overlap=max_overlap,
        max_prefix_length=max_prefix_length
    )

    result.start_snapped = start_snapped
    result.end_snapped = end_snapped
    return result


# ============================================================
# 路径转 GeoJSON（用于前端渲染）
# ============================================================

def parse_wkt_to_coords(wkt: str) -> List[List[float]]:
    """解析 WKT LINESTRING 为坐标数组"""
    import re
    match = re.match(r'LINESTRING\((.+)\)', wkt)
    if not match:
        return []

    coords = []
    for point in match.group(1).split(', '):
        parts = point.strip().split(' ')
        if len(parts) >= 2:
            try:
                lon, lat = float(parts[0]), float(parts[1])
                coords.append([lon, lat])
            except ValueError:
                pass
    return coords

def route_to_geojson(
    graph: SkiGraph,
    route: RoutePath,
    route_index: int = 0,
    start_snapped: Optional[SnappedPoint] = None,
    end_snapped: Optional[SnappedPoint] = None
) -> dict:
    """将路径转换为 GeoJSON FeatureCollection"""
    features = []

    colors = ['#3b82f6', '#22c55e', '#f59e0b']
    color = colors[route_index % len(colors)]

    if start_snapped and start_snapped.distance_m > 1:
        features.append({
            'type': 'Feature',
            'properties': {
                'segment_type': 'start_connection',
                'feat_type': 'walk',
                'name': '前往起点',
                'route_index': route_index,
                'color': color,
                'dash': True
            },
            'geometry': {
                'type': 'LineString',
                'coordinates': [
                    [start_snapped.original_lon, start_snapped.original_lat],
                    [start_snapped.snapped_lon, start_snapped.snapped_lat]
                ]
            }
        })

    for directed_id in route.edges:
        directed_edge = graph.directed_edges.get(directed_id)
        if not directed_edge:
            continue

        base_edge = graph.edges.get(directed_edge.base_edge_id)
        edge_from = directed_edge.from_node
        edge_to = directed_edge.to_node
        is_reversed = directed_edge.is_reversed
        name = directed_edge.name
        difficulty = directed_edge.difficulty
        src_feat_type = directed_edge.src_feat_type
        length_m = directed_edge.length_m
        geom = base_edge.geom if base_edge else ""

        coords = parse_wkt_to_coords(geom) if geom else []
        if not coords:
            from_node = graph.nodes.get(edge_from)
            to_node = graph.nodes.get(edge_to)
            if from_node and to_node:
                coords = [[from_node.lon, from_node.lat], [to_node.lon, to_node.lat]]

        if not coords:
            continue

        if is_reversed:
            coords = list(reversed(coords))

        features.append({
            'type': 'Feature',
            'properties': {
                'edge_id': directed_id,
                'name': name,
                'difficulty': difficulty,
                'feat_type': src_feat_type,
                'length_m': length_m,
                'route_index': route_index,
                'color': color
            },
            'geometry': {
                'type': 'LineString',
                'coordinates': coords
            }
        })

    if end_snapped and end_snapped.distance_m > 1:
        features.append({
            'type': 'Feature',
            'properties': {
                'segment_type': 'end_connection',
                'feat_type': 'walk',
                'name': '到达目的地',
                'route_index': route_index,
                'color': color,
                'dash': True
            },
            'geometry': {
                'type': 'LineString',
                'coordinates': [
                    [end_snapped.snapped_lon, end_snapped.snapped_lat],
                    [end_snapped.original_lon, end_snapped.original_lat]
                ]
            }
        })

    return {
        'type': 'FeatureCollection',
        'features': features,
        'properties': {
            'route_index': route_index,
            'total_cost': route.total_cost,
            'total_length': route.total_length,
            'edge_count': len(route.edges),
            'node_count': len(route.nodes)
        }
    }


def build_route_steps(
    graph: SkiGraph,
    route: RoutePath,
    start_snapped: Optional[SnappedPoint] = None,
    end_snapped: Optional[SnappedPoint] = None
) -> List[dict]:
    """构建路线的详细步骤列表"""
    steps = []
    step_index = 0
    cumulative_distance = 0
    cumulative_time = 0

    if start_snapped and start_snapped.distance_m > 1:
        steps.append({
            'step_index': step_index,
            'instruction': '从当前位置前往路线起点',
            'distance_m': start_snapped.distance_m,
            'duration_s': start_snapped.distance_m / 1.0,
            'feat_type': 'walk',
            'name': '步行',
            'difficulty': '',
            'lift_type': '',
            'geometry': [
                [start_snapped.original_lon, start_snapped.original_lat],
                [start_snapped.snapped_lon, start_snapped.snapped_lat]
            ],
            'from_node': None,
            'to_node': route.nodes[0] if route.nodes else None
        })
        cumulative_distance += start_snapped.distance_m
        cumulative_time += start_snapped.distance_m / 1.0
        step_index += 1

    for directed_id in route.edges:
        directed_edge = graph.directed_edges.get(directed_id)
        if not directed_edge:
            continue

        base_edge = graph.edges.get(directed_edge.base_edge_id)
        edge_from = directed_edge.from_node
        edge_to = directed_edge.to_node
        is_reversed = directed_edge.is_reversed
        length_m = directed_edge.length_m
        src_feat_type = directed_edge.src_feat_type
        name = directed_edge.name
        difficulty = directed_edge.difficulty
        lift_type = directed_edge.lift_type
        duration = directed_edge.duration
        geom = base_edge.geom if base_edge else ""

        coords = parse_wkt_to_coords(geom) if geom else []
        if not coords:
            from_node_obj = graph.nodes.get(edge_from)
            to_node_obj = graph.nodes.get(edge_to)
            if from_node_obj and to_node_obj:
                coords = [[from_node_obj.lon, from_node_obj.lat], [to_node_obj.lon, to_node_obj.lat]]

        if is_reversed and coords:
            coords = list(reversed(coords))

        if src_feat_type == 'lift':
            if duration > 0:
                duration_s = duration
            else:
                duration_s = length_m / 5.0
            instruction = f'乘坐缆车 {name}' if name else '乘坐缆车'
            if lift_type:
                instruction += f' ({lift_type})'
        else:
            diff_level = get_difficulty_level(difficulty)
            speed = 18 - diff_level * 2
            duration_s = length_m / speed

            diff_names = {'novice': '初级', 'easy': '简单', 'intermediate': '中级', 'advanced': '高级', 'expert': '专家'}
            diff_cn = diff_names.get(difficulty, '')
            instruction = f'沿 {name} 滑行' if name else '沿雪道滑行'
            if diff_cn:
                instruction += f' ({diff_cn}道)'

        cumulative_distance += length_m
        cumulative_time += duration_s

        steps.append({
            'step_index': step_index,
            'instruction': instruction,
            'distance_m': length_m,
            'duration_s': duration_s,
            'cumulative_distance_m': cumulative_distance,
            'cumulative_time_s': cumulative_time,
            'feat_type': src_feat_type,
            'name': name,
            'difficulty': difficulty,
            'lift_type': lift_type,
            'geometry': coords,
            'edge_id': directed_id,
            'from_node': edge_from,
            'to_node': edge_to
        })
        step_index += 1

    if end_snapped and end_snapped.distance_m > 1:
        steps.append({
            'step_index': step_index,
            'instruction': '到达目的地',
            'distance_m': end_snapped.distance_m,
            'duration_s': end_snapped.distance_m / 1.0,
            'feat_type': 'walk',
            'name': '步行',
            'difficulty': '',
            'lift_type': '',
            'geometry': [
                [end_snapped.snapped_lon, end_snapped.snapped_lat],
                [end_snapped.original_lon, end_snapped.original_lat]
            ],
            'from_node': route.nodes[-1] if route.nodes else None,
            'to_node': None
        })

    return steps


def explore_result_to_json(graph: SkiGraph, result: ExploreResult) -> dict:
    """将探索结果转换为 JSON 格式"""
    routes_json = []

    for i, route in enumerate(result.routes):
        steps = build_route_steps(graph, route, result.start_snapped, result.end_snapped)

        first_directed_id = result.first_edges[i] if i < len(result.first_edges) else None
        first_directed_edge = graph.directed_edges.get(first_directed_id) if first_directed_id else None

        route_json = {
            'index': i,
            'first_edge_id': first_directed_id,
            'first_edge_base_id': first_directed_edge.base_edge_id if first_directed_edge else None,
            'first_edge_name': result.first_edge_names[i] if i < len(result.first_edge_names) else '',
            'first_edge_difficulty': first_directed_edge.difficulty if first_directed_edge else '',
            'first_edge_type': first_directed_edge.src_feat_type if first_directed_edge else '',
            'first_edge_reversed': first_directed_edge.is_reversed if first_directed_edge else False,
            'edges': route.edges,
            'nodes': route.nodes,
            'total_cost': route.total_cost,
            'total_length': route.total_length,
            'steps': steps,
            'geojson': route_to_geojson(graph, route, i, result.start_snapped, result.end_snapped)
        }
        routes_json.append(route_json)

    response = {
        'success': result.success,
        'error': result.error,
        'mode': 'explore',
        'start_node': result.start_node,
        'end_node': result.end_node,
        'routes': routes_json,
        'route_count': len(result.routes)
    }

    if result.start_snapped:
        response['start_snapped'] = {
            'original_lon': result.start_snapped.original_lon,
            'original_lat': result.start_snapped.original_lat,
            'snapped_lon': result.start_snapped.snapped_lon,
            'snapped_lat': result.start_snapped.snapped_lat,
            'node_id': result.start_snapped.node_id,
            'distance_m': result.start_snapped.distance_m
        }
    if result.end_snapped:
        response['end_snapped'] = {
            'original_lon': result.end_snapped.original_lon,
            'original_lat': result.end_snapped.original_lat,
            'snapped_lon': result.end_snapped.snapped_lon,
            'snapped_lat': result.end_snapped.snapped_lat,
            'node_id': result.end_snapped.node_id,
            'distance_m': result.end_snapped.distance_m
        }

    return response


def route_result_to_json(graph: SkiGraph, result: RouteResult) -> dict:
    """将路由结果转换为 JSON 格式"""
    routes_json = []

    for i, route in enumerate(result.routes):
        steps = build_route_steps(graph, route, result.start_snapped, result.end_snapped)

        route_json = {
            'index': i,
            'edges': route.edges,
            'nodes': route.nodes,
            'total_cost': route.total_cost,
            'total_length': route.total_length,
            'segments': route.segments,
            'steps': steps,
            'geojson': route_to_geojson(graph, route, i, result.start_snapped, result.end_snapped)
        }

        edge_details = []
        for directed_id in route.edges:
            directed_edge = graph.directed_edges.get(directed_id)
            if directed_edge:
                base_edge = graph.edges.get(directed_edge.base_edge_id)
                if base_edge:
                    edge_details.append({
                        'edge_id': directed_id,
                        'base_edge_id': directed_edge.base_edge_id,
                        'name': base_edge.name,
                        'difficulty': base_edge.difficulty,
                        'feat_type': base_edge.src_feat_type,
                        'length_m': base_edge.length_m,
                        'lift_type': base_edge.lift_type,
                        'is_reversed': directed_edge.is_reversed
                    })
        route_json['edge_details'] = edge_details
        routes_json.append(route_json)

    response = {
        'success': result.success,
        'error': result.error,
        'start_node': result.start_node,
        'end_node': result.end_node,
        'waypoints': result.waypoints,
        'routes': routes_json,
        'route_count': len(result.routes)
    }

    if result.start_snapped:
        response['start_snapped'] = {
            'original_lon': result.start_snapped.original_lon,
            'original_lat': result.start_snapped.original_lat,
            'snapped_lon': result.start_snapped.snapped_lon,
            'snapped_lat': result.start_snapped.snapped_lat,
            'node_id': result.start_snapped.node_id,
            'edge_id': result.start_snapped.edge_id,
            'distance_m': result.start_snapped.distance_m,
            'is_on_node': result.start_snapped.is_on_node
        }

    if result.end_snapped:
        response['end_snapped'] = {
            'original_lon': result.end_snapped.original_lon,
            'original_lat': result.end_snapped.original_lat,
            'snapped_lon': result.end_snapped.snapped_lon,
            'snapped_lat': result.end_snapped.snapped_lat,
            'node_id': result.end_snapped.node_id,
            'edge_id': result.end_snapped.edge_id,
            'distance_m': result.end_snapped.distance_m,
            'is_on_node': result.end_snapped.is_on_node
        }

    if result.waypoints_snapped:
        response['waypoints_snapped'] = [
            {
                'original_lon': wp.original_lon,
                'original_lat': wp.original_lat,
                'snapped_lon': wp.snapped_lon,
                'snapped_lat': wp.snapped_lat,
                'node_id': wp.node_id,
                'edge_id': wp.edge_id,
                'distance_m': wp.distance_m,
                'is_on_node': wp.is_on_node
            }
            for wp in result.waypoints_snapped
        ]

    return response


# ============================================================
# 查找最近节点
# ============================================================

def find_nearest_node(graph: SkiGraph, lon: float, lat: float) -> Tuple[int, float]:
    """查找距离给定坐标最近的节点"""
    min_dist = float('inf')
    nearest_id = -1
    for node in graph.nodes.values():
        dist = haversine_distance(lon, lat, node.lon, node.lat)
        if dist < min_dist:
            min_dist = dist
            nearest_id = node.node_id
    return nearest_id, min_dist


# ============================================================
# 测试入口
# ============================================================

def find_connected_components(graph: SkiGraph) -> List[List[int]]:
    """找到图中的所有连通分量"""
    visited = set()
    components = []

    for start in graph.nodes.keys():
        if start in visited:
            continue

        component = []
        queue = deque([start])
        while queue:
            node = queue.popleft()
            if node in visited:
                continue
            visited.add(node)
            component.append(node)
            for _, neighbor in graph.adjacency.get(node, []):
                if neighbor not in visited:
                    queue.append(neighbor)

        if len(component) > 1:
            components.append(component)

    return sorted(components, key=len, reverse=True)


if __name__ == '__main__':
    print("加载图数据...")
    graph = SkiGraph('beidahu/ski_graph.sqlite')
    print(f"  节点数: {len(graph.nodes)}")
    print(f"  边数: {len(graph.edges)}")

    components = find_connected_components(graph)
    print(f"\n发现 {len(components)} 个连通分量")

    if components:
        largest = components[0]
        print(f"最大连通分量: {len(largest)} 个节点")

        start = largest[0]
        end = largest[-1]

        print(f"\n测试路由: Node {start} -> Node {end}")
        result = plan_route(graph, start, end, num_alternatives=3)

        if result.success:
            print(f"✓ 找到 {len(result.routes)} 条路线:")
            for i, route in enumerate(result.routes):
                print(f"  路线 {i+1}: {len(route.edges)} 边, {route.total_length:.0f}m, 代价: {route.total_cost:.1f}s")

                route_desc = []
                for directed_id in route.edges[:5]:
                    directed_edge = graph.directed_edges.get(directed_id)
                    if directed_edge:
                        base_edge = graph.edges.get(directed_edge.base_edge_id)
                        if base_edge:
                            name = base_edge.name or f"(Edge {directed_edge.base_edge_id})"
                            rev_mark = "↩" if directed_edge.is_reversed else ""
                            route_desc.append(f"{name}{rev_mark}[{base_edge.src_feat_type}]")
                if len(route.edges) > 5:
                    route_desc.append(f"...({len(route.edges)-5} more)")
                print(f"     路径: {' → '.join(route_desc)}")
        else:
            print(f"路由失败: {result.error}")

        if len(largest) >= 3:
            print("\n测试带途经点的路由...")
            mid_idx = len(largest) // 2
            waypoint = largest[mid_idx]

            print(f"路线: {start} -> {waypoint} -> {end}")
            result = plan_route(graph, start, end, waypoints=[waypoint], num_alternatives=2)

            if result.success:
                print(f"✓ 找到 {len(result.routes)} 条路线")
                for i, route in enumerate(result.routes):
                    print(f"  路线 {i+1}: {len(route.edges)} 边, {route.total_length:.0f}m")
            else:
                print(f"路由失败: {result.error}")

        # 额外：探索模式快速自测（可选）
        print("\n测试探索模式...")
        ex = explore_routes(graph, start, end, preferences=None, max_overlap=0.8, max_prefix_length=200.0)
        if ex.success:
            print(f"✓ Explore routes: {len(ex.routes)}")
            for i, r in enumerate(ex.routes[:5]):
                print(f"  Explore {i+1}: len={r.total_length:.0f}m cost={r.total_cost:.1f} first_edge={ex.first_edge_names[i]}")
        else:
            print(f"Explore failed: {ex.error}")

    print("\n完成!")


# ============================================================
# OSRM 格式输出支持
# ============================================================

def encode_polyline(coordinates: List[List[float]], precision: int = 5) -> str:
    """
    将坐标数组编码为 Google Polyline 格式

    Args:
        coordinates: [[lon, lat], ...] 坐标数组
        precision: 精度（默认5位小数，OSRM标准）

    Returns:
        编码后的 polyline 字符串
    """
    result = []
    prev_lat = 0
    prev_lon = 0
    factor = 10 ** precision

    for coord in coordinates:
        lon, lat = coord[0], coord[1]
        lat_int = round(lat * factor)
        lon_int = round(lon * factor)

        # 计算差值
        d_lat = lat_int - prev_lat
        d_lon = lon_int - prev_lon

        prev_lat = lat_int
        prev_lon = lon_int

        # 编码纬度和经度差值
        for value in [d_lat, d_lon]:
            # 左移一位，负数取反
            value = ~(value << 1) if value < 0 else (value << 1)
            # 分块编码
            while value >= 0x20:
                result.append(chr((0x20 | (value & 0x1f)) + 63))
                value >>= 5
            result.append(chr(value + 63))

    return ''.join(result)


def calculate_bearing(lon1: float, lat1: float, lon2: float, lat2: float) -> int:
    """
    计算从点1到点2的方位角（0-360度，北为0）
    """
    import math

    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    dlon = math.radians(lon2 - lon1)

    x = math.sin(dlon) * math.cos(lat2_rad)
    y = math.cos(lat1_rad) * math.sin(lat2_rad) - math.sin(lat1_rad) * math.cos(lat2_rad) * math.cos(dlon)

    bearing = math.degrees(math.atan2(x, y))
    return int((bearing + 360) % 360)


def get_turn_modifier(bearing_before: int, bearing_after: int) -> str:
    """
    根据前后方位角计算转向修饰词
    """
    # 计算转向角度（正为右转，负为左转）
    turn_angle = (bearing_after - bearing_before + 360) % 360
    if turn_angle > 180:
        turn_angle -= 360

    if abs(turn_angle) < 15:
        return "straight"
    elif turn_angle >= 15 and turn_angle < 45:
        return "slight right"
    elif turn_angle >= 45 and turn_angle < 120:
        return "right"
    elif turn_angle >= 120:
        return "sharp right"
    elif turn_angle <= -15 and turn_angle > -45:
        return "slight left"
    elif turn_angle <= -45 and turn_angle > -120:
        return "left"
    else:
        return "sharp left"


def generate_instruction(
    graph: SkiGraph,
    directed_edge,
    is_first: bool = False,
    is_last: bool = False,
    prev_edge = None
) -> Tuple[str, str, str]:
    """
    生成导航指令

    Returns:
        (type, modifier, instruction_text)
    """
    base_edge = graph.edges.get(directed_edge.base_edge_id)
    name = directed_edge.name or ""
    feat_type = directed_edge.src_feat_type
    difficulty = directed_edge.difficulty
    lift_type = directed_edge.lift_type

    if is_first:
        maneuver_type = "depart"
        modifier = "straight"
        if feat_type == 'lift':
            instruction = f"乘坐缆车 {name}" if name else "乘坐缆车"
        else:
            instruction = f"从 {name} 出发" if name else "出发"
    elif is_last:
        maneuver_type = "arrive"
        modifier = "straight"
        instruction = "到达目的地"
    else:
        # 计算转向
        if prev_edge:
            # 获取前一条边的终点方向和当前边的起点方向
            prev_to_node = graph.nodes.get(prev_edge.to_node)
            curr_from_node = graph.nodes.get(directed_edge.from_node)
            curr_to_node = graph.nodes.get(directed_edge.to_node)

            if prev_to_node and curr_from_node and curr_to_node:
                # 简化：用节点位置计算大致方向
                bearing_after = calculate_bearing(
                    curr_from_node.lon, curr_from_node.lat,
                    curr_to_node.lon, curr_to_node.lat
                )
                # 获取前一条边的方向
                prev_from_node = graph.nodes.get(prev_edge.from_node)
                if prev_from_node:
                    bearing_before = calculate_bearing(
                        prev_from_node.lon, prev_from_node.lat,
                        prev_to_node.lon, prev_to_node.lat
                    )
                    modifier = get_turn_modifier(bearing_before, bearing_after)
                else:
                    modifier = "straight"
            else:
                modifier = "straight"
        else:
            modifier = "straight"

        # 生成指令文本
        if feat_type == 'lift':
            maneuver_type = "notification"
            instruction = f"乘坐缆车 {name}" if name else "乘坐缆车"
            if lift_type:
                instruction += f" ({lift_type})"
        else:
            # 根据转向生成指令
            turn_words = {
                "straight": "继续",
                "slight right": "稍向右转",
                "right": "右转",
                "sharp right": "急右转",
                "slight left": "稍向左转",
                "left": "左转",
                "sharp left": "急左转"
            }
            turn_word = turn_words.get(modifier, "继续")

            if modifier == "straight":
                maneuver_type = "continue"
                instruction = f"继续沿 {name} 滑行" if name else "继续滑行"
            else:
                maneuver_type = "turn"
                instruction = f"{turn_word}进入 {name}" if name else f"{turn_word}滑行"

            # 添加难度信息
            diff_names = {'novice': '初级', 'easy': '简单', 'intermediate': '中级',
                         'advanced': '高级', 'expert': '专家'}
            if difficulty in diff_names:
                instruction += f" ({diff_names[difficulty]}道)"

    return maneuver_type, modifier, instruction


def build_osrm_step(
    graph: SkiGraph,
    directed_edge,
    step_geometry: List[List[float]],
    is_first: bool = False,
    is_last: bool = False,
    prev_edge = None
) -> dict:
    """
    构建单个 OSRM step
    """
    name = directed_edge.name or ""
    length_m = directed_edge.length_m
    feat_type = directed_edge.src_feat_type
    difficulty = directed_edge.difficulty

    # 计算时间（秒）
    if feat_type == 'lift':
        duration = directed_edge.duration if directed_edge.duration > 0 else length_m / 5.0
    else:
        diff_level = get_difficulty_level(difficulty)
        speed = 18 - diff_level * 2  # m/s
        duration = length_m / speed

    # 获取方位角
    if step_geometry and len(step_geometry) >= 2:
        bearing_after = calculate_bearing(
            step_geometry[0][0], step_geometry[0][1],
            step_geometry[1][0], step_geometry[1][1]
        )
        bearing_before = 0
        if prev_edge and not is_first:
            prev_from = graph.nodes.get(prev_edge.from_node)
            prev_to = graph.nodes.get(prev_edge.to_node)
            if prev_from and prev_to:
                bearing_before = calculate_bearing(
                    prev_from.lon, prev_from.lat,
                    prev_to.lon, prev_to.lat
                )
    else:
        bearing_before = 0
        bearing_after = 0

    # 生成指令
    maneuver_type, modifier, instruction = generate_instruction(
        graph, directed_edge, is_first, is_last, prev_edge
    )

    # 构建 maneuver
    location = step_geometry[0] if step_geometry else [0, 0]
    maneuver = {
        "bearing_after": bearing_after,
        "bearing_before": bearing_before,
        "location": location,
        "type": maneuver_type
    }
    if modifier and modifier != "straight":
        maneuver["modifier"] = modifier

    # 构建 intersections（简化版）
    intersections = [{
        "out": 0,
        "entry": [True],
        "bearings": [bearing_after],
        "location": location
    }]

    # 模式映射
    mode = "ferry" if feat_type == 'lift' else "skiing"

    step = {
        "geometry": encode_polyline(step_geometry) if step_geometry else "",
        "maneuver": maneuver,
        "mode": mode,
        "driving_side": "right",
        "name": name,
        "intersections": intersections,
        "weight": duration,
        "duration": duration,
        "distance": length_m,
        "instruction": instruction  # 额外字段：中文指令
    }

    # 添加难度信息（扩展字段）
    if difficulty:
        step["difficulty"] = difficulty
    if feat_type:
        step["feat_type"] = feat_type

    return step


def route_result_to_osrm(
    graph: SkiGraph,
    result: RouteResult,
    include_geometry: bool = True,
    overview: str = "simplified"  # "full", "simplified", "false"
) -> dict:
    """
    将路由结果转换为 OSRM 兼容的 JSON 格式

    Args:
        graph: 图结构
        result: 路由结果
        include_geometry: 是否包含几何信息
        overview: 概览几何的详细程度

    Returns:
        OSRM 格式的 JSON 字典
    """
    if not result.success:
        return {
            "code": "NoRoute",
            "message": result.error
        }

    routes = []

    for route_idx, route in enumerate(result.routes):
        # 构建 legs（每条路线只有一个 leg，除非有途经点）
        legs = []

        # 当前简化为单 leg
        steps = []
        total_distance = 0
        total_duration = 0
        all_coords = []  # 整条路线的坐标

        prev_edge = None
        for i, directed_id in enumerate(route.edges):
            directed_edge = graph.directed_edges.get(directed_id)
            if not directed_edge:
                continue

            base_edge = graph.edges.get(directed_edge.base_edge_id)
            is_first = (i == 0)
            is_last = (i == len(route.edges) - 1)

            # 获取边的几何
            geom = base_edge.geom if base_edge else ""
            coords = parse_wkt_to_coords(geom) if geom else []

            if not coords:
                from_node = graph.nodes.get(directed_edge.from_node)
                to_node = graph.nodes.get(directed_edge.to_node)
                if from_node and to_node:
                    coords = [[from_node.lon, from_node.lat], [to_node.lon, to_node.lat]]

            # 如果是反向边，翻转坐标
            if directed_edge.is_reversed and coords:
                coords = list(reversed(coords))

            # 构建 step
            step = build_osrm_step(
                graph, directed_edge, coords,
                is_first, is_last, prev_edge
            )
            steps.append(step)

            total_distance += directed_edge.length_m
            total_duration += step["duration"]

            # 收集坐标（避免重复）
            if coords:
                if all_coords:
                    all_coords.extend(coords[1:])  # 跳过第一个点避免重复
                else:
                    all_coords.extend(coords)

            prev_edge = directed_edge

        # 添加到达步骤
        if steps:
            last_coord = all_coords[-1] if all_coords else [0, 0]
            arrive_step = {
                "geometry": "",
                "maneuver": {
                    "bearing_after": 0,
                    "bearing_before": steps[-1]["maneuver"]["bearing_after"] if steps else 0,
                    "location": last_coord,
                    "type": "arrive"
                },
                "mode": "skiing",
                "driving_side": "right",
                "name": steps[-1]["name"] if steps else "",
                "intersections": [{
                    "in": 0,
                    "entry": [True],
                    "bearings": [0],
                    "location": last_coord
                }],
                "weight": 0,
                "duration": 0,
                "distance": 0,
                "instruction": "到达目的地"
            }
            steps.append(arrive_step)

        # 构建 leg
        leg = {
            "steps": steps,
            "summary": "",  # 可以填入主要道路名称
            "weight": total_duration,
            "duration": total_duration,
            "distance": total_distance
        }

        # 生成摘要（取前两个有名字的边）
        named_edges = [s["name"] for s in steps if s.get("name")]
        if named_edges:
            leg["summary"] = ", ".join(named_edges[:2])

        legs.append(leg)

        # 构建路线概览几何
        route_geometry = ""
        if include_geometry and overview != "false" and all_coords:
            if overview == "simplified":
                # 简化：只保留关键点（每隔几个点取一个）
                step_size = max(1, len(all_coords) // 50)
                simplified = all_coords[::step_size]
                if all_coords[-1] not in simplified:
                    simplified.append(all_coords[-1])
                route_geometry = encode_polyline(simplified)
            else:
                route_geometry = encode_polyline(all_coords)

        routes.append({
            "legs": legs,
            "weight_name": "duration",
            "weight": total_duration,
            "duration": total_duration,
            "distance": total_distance,
            "geometry": route_geometry if include_geometry else None
        })

    # 构建 waypoints
    waypoints = []

    # 起点
    start_node = graph.nodes.get(result.start_node)
    if result.start_snapped:
        waypoints.append({
            "hint": "",
            "distance": result.start_snapped.distance_m,
            "name": "",
            "location": [result.start_snapped.snapped_lon, result.start_snapped.snapped_lat]
        })
    elif start_node:
        waypoints.append({
            "hint": "",
            "distance": 0,
            "name": "",
            "location": [start_node.lon, start_node.lat]
        })

    # 终点
    end_node = graph.nodes.get(result.end_node)
    if result.end_snapped:
        waypoints.append({
            "hint": "",
            "distance": result.end_snapped.distance_m,
            "name": "",
            "location": [result.end_snapped.snapped_lon, result.end_snapped.snapped_lat]
        })
    elif end_node:
        waypoints.append({
            "hint": "",
            "distance": 0,
            "name": "",
            "location": [end_node.lon, end_node.lat]
        })

    return {
        "code": "Ok",
        "routes": routes,
        "waypoints": waypoints
    }


def explore_result_to_osrm(
    graph: SkiGraph,
    result: ExploreResult,
    include_geometry: bool = True,
    overview: str = "simplified"
) -> dict:
    """
    将探索模式结果转换为 OSRM 兼容格式
    """
    if not result.success:
        return {
            "code": "NoRoute",
            "message": result.error
        }

    # 构造一个临时的 RouteResult
    temp_result = RouteResult(
        routes=result.routes,
        start_node=result.start_node,
        end_node=result.end_node,
        waypoints=[],
        success=True,
        start_snapped=result.start_snapped,
        end_snapped=result.end_snapped
    )

    osrm_result = route_result_to_osrm(graph, temp_result, include_geometry, overview)

    # 添加探索模式特有的信息
    if osrm_result.get("code") == "Ok":
        for i, route in enumerate(osrm_result.get("routes", [])):
            if i < len(result.first_edges):
                route["first_edge_id"] = result.first_edges[i]
            if i < len(result.first_edge_names):
                route["first_edge_name"] = result.first_edge_names[i]

    return osrm_result
