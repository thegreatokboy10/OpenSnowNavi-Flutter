#!/usr/bin/env python3
"""
SnowNavi 导航服务器
提供 HTTP API 用于路径规划

用法:
    python navigation_server.py beidahu/ski_graph.sqlite --port 8080
"""

import json
import argparse
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import os
import sys

# 添加当前目录到路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from navigation_engine import (
    SkiGraph, plan_route, plan_route_coords, route_result_to_json,
    find_nearest_node, find_connected_components, snap_to_graph,
    explore_routes, explore_routes_coords, explore_result_to_json,
    route_result_to_osrm, explore_result_to_osrm
)


class NavigationHandler(SimpleHTTPRequestHandler):
    """导航 API 处理器"""
    
    graph: SkiGraph = None
    
    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        
        if path == '/api/route':
            self.handle_route(parsed.query)
        elif path == '/api/graph':
            self.handle_graph()
        elif path == '/api/nearest':
            self.handle_nearest(parsed.query)
        elif path == '/api/components':
            self.handle_components()
        elif path == '/' or path == '/index.html':
            self.serve_navigation_html()
        else:
            super().do_GET()
    
    def send_json(self, data, status=200):
        """发送 JSON 响应"""
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode('utf-8'))
    
    def handle_route(self, query_string):
        """处理路由请求

        支持两种输入模式:
        1. 节点ID模式: start=16&end=40
        2. 坐标模式: start_lon=126.6&start_lat=43.4&end_lon=126.7&end_lat=43.5

        支持两种路由模式:
        - mode=normal (默认): 普通路由，返回多条备选路线
        - mode=explore: 探索模式，为起点每条可通行的边分别计算一条路线

        支持两种输出格式:
        - format=snownavi (默认): SnowNavi 原生格式
        - format=osrm: OSRM 兼容格式，包含导航指令
        """
        params = parse_qs(query_string)

        # 路由模式
        mode = params.get('mode', ['normal'])[0]

        # 输出格式
        output_format = params.get('format', ['snownavi'])[0].lower()
        overview = params.get('overview', ['simplified'])[0]  # OSRM geometry detail

        # 通用参数
        num_alt = int(params.get('alternatives', ['3'])[0])
        max_diff = params.get('max_difficulty', ['expert'])[0]
        prefer_lifts = params.get('prefer_lifts', ['false'])[0].lower() == 'true'
        max_overlap = float(params.get('max_overlap', ['0.8'])[0])
        max_snap_distance = float(params.get('max_snap_distance', ['500'])[0])
        # 多样性路由参数（新增）
        use_diverse = params.get('diverse', ['true'])[0].lower() == 'true'
        detour_ratio = float(params.get('detour_ratio', ['0.6'])[0])

        preferences = {
            'max_difficulty': max_diff,
            'prefer_lifts': prefer_lifts
        }

        # 检查是否使用坐标模式
        start_lon = params.get('start_lon', [None])[0]
        start_lat = params.get('start_lat', [None])[0]
        end_lon = params.get('end_lon', [None])[0]
        end_lat = params.get('end_lat', [None])[0]

        if start_lon and start_lat and end_lon and end_lat:
            # 坐标模式
            try:
                start_lon = float(start_lon)
                start_lat = float(start_lat)
                end_lon = float(end_lon)
                end_lat = float(end_lat)
            except ValueError:
                self.send_json({'error': '坐标格式错误'}, 400)
                return

            if mode == 'explore':
                # 探索模式（坐标）
                result = explore_routes_coords(
                    self.graph,
                    start_lon, start_lat,
                    end_lon, end_lat,
                    preferences=preferences,
                    max_overlap=max_overlap,
                    max_snap_distance_m=max_snap_distance
                )
                if output_format == 'osrm':
                    self.send_json(explore_result_to_osrm(self.graph, result, overview=overview))
                else:
                    self.send_json(explore_result_to_json(self.graph, result))
            else:
                # 普通模式（坐标）
                # 解析途经点坐标 (格式: lon1,lat1;lon2,lat2)
                waypoints_coords = []
                waypoints_str = params.get('waypoints_coords', [''])[0]
                if waypoints_str:
                    try:
                        for pt in waypoints_str.split(';'):
                            lon, lat = pt.split(',')
                            waypoints_coords.append((float(lon), float(lat)))
                    except ValueError:
                        pass

                result = plan_route_coords(
                    self.graph,
                    start_lon, start_lat,
                    end_lon, end_lat,
                    waypoints_coords=waypoints_coords,
                    num_alternatives=num_alt,
                    preferences=preferences,
                    max_overlap=max_overlap,
                    max_snap_distance_m=max_snap_distance,
                    use_diverse_routing=use_diverse,
                    detour_ratio=detour_ratio
                )
                if output_format == 'osrm':
                    self.send_json(route_result_to_osrm(self.graph, result, overview=overview))
                else:
                    self.send_json(route_result_to_json(self.graph, result))
        else:
            # 节点ID模式
            try:
                start = int(params.get('start', [None])[0])
                end = int(params.get('end', [None])[0])
            except (TypeError, ValueError):
                self.send_json({'error': '缺少 start/end 参数或 start_lon/start_lat/end_lon/end_lat 坐标参数'}, 400)
                return

            if mode == 'explore':
                # 探索模式（节点）
                result = explore_routes(self.graph, start, end, preferences, max_overlap)
                if output_format == 'osrm':
                    self.send_json(explore_result_to_osrm(self.graph, result, overview=overview))
                else:
                    self.send_json(explore_result_to_json(self.graph, result))
            else:
                # 普通模式（节点）
                # 可选参数
                waypoints_str = params.get('waypoints', [''])[0]
                waypoints = []
                if waypoints_str:
                    try:
                        waypoints = [int(x) for x in waypoints_str.split(',')]
                    except ValueError:
                        pass

                result = plan_route(
                    self.graph, start, end,
                    waypoints=waypoints,
                    num_alternatives=num_alt,
                    preferences=preferences,
                    max_overlap=max_overlap,
                    use_diverse_routing=use_diverse,
                    detour_ratio=detour_ratio
                )
                if output_format == 'osrm':
                    self.send_json(route_result_to_osrm(self.graph, result, overview=overview))
                else:
                    self.send_json(route_result_to_json(self.graph, result))
    
    def handle_graph(self):
        """返回完整图数据"""
        nodes = self.graph.get_all_nodes_json()
        edges = self.graph.get_all_edges_json()
        
        # 计算中心点
        if nodes:
            center_lon = sum(n['lon'] for n in nodes) / len(nodes)
            center_lat = sum(n['lat'] for n in nodes) / len(nodes)
        else:
            center_lon, center_lat = 0, 0
        
        self.send_json({
            'nodes': nodes,
            'edges': edges,
            'center': {'lon': center_lon, 'lat': center_lat},
            'node_count': len(nodes),
            'edge_count': len(edges)
        })
    
    def handle_nearest(self, query_string):
        """查找最近节点"""
        params = parse_qs(query_string)
        
        try:
            lon = float(params.get('lon', [None])[0])
            lat = float(params.get('lat', [None])[0])
        except (TypeError, ValueError):
            self.send_json({'error': '缺少 lon 或 lat 参数'}, 400)
            return
        
        node_id, distance = find_nearest_node(self.graph, lon, lat)
        node = self.graph.nodes.get(node_id)
        
        self.send_json({
            'node_id': node_id,
            'distance_m': distance,
            'lon': node.lon if node else None,
            'lat': node.lat if node else None
        })
    
    def handle_components(self):
        """返回连通分量信息"""
        components = find_connected_components(self.graph)
        
        result = []
        for i, comp in enumerate(components[:10]):
            result.append({
                'index': i,
                'size': len(comp),
                'nodes': comp[:20]  # 只返回前20个节点
            })
        
        self.send_json({
            'total_components': len(components),
            'components': result
        })
    
    def serve_navigation_html(self):
        """提供导航 HTML 页面"""
        html_path = os.path.join(os.path.dirname(__file__), 'navigation.html')
        if os.path.exists(html_path):
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            with open(html_path, 'rb') as f:
                self.wfile.write(f.read())
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'navigation.html not found')


def main():
    parser = argparse.ArgumentParser(description='SnowNavi 导航服务器')
    parser.add_argument('db', help='ski_graph.sqlite 文件路径')
    parser.add_argument('--port', type=int, default=8080, help='服务端口 (默认: 8080)')
    parser.add_argument('--host', default='localhost', help='绑定地址 (默认: localhost)')

    args = parser.parse_args()

    print(f"加载图数据: {args.db}")
    NavigationHandler.graph = SkiGraph(args.db)
    print(f"  节点数: {len(NavigationHandler.graph.nodes)}")
    print(f"  边数: {len(NavigationHandler.graph.edges)}")

    server = HTTPServer((args.host, args.port), NavigationHandler)
    print(f"\n导航服务器启动: http://{args.host}:{args.port}")
    print("按 Ctrl+C 停止服务器")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n服务器已停止")


if __name__ == '__main__':
    main()

