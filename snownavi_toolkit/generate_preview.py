#!/usr/bin/env python3
"""
生成 ski_graph.sqlite 的 HTML 可视化报告
使用 Leaflet 展示节点和边

用法:
    python generate_preview.py ski_graph.sqlite -o preview.html
"""

import sqlite3
import json
import argparse
from pathlib import Path


HTML_TEMPLATE = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>SnowNavi 图数据预览</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        #container { display: flex; height: 100vh; }
        #map { flex: 1; }
        #sidebar {
            width: 350px;
            background: #f5f5f5;
            overflow-y: auto;
            border-left: 1px solid #ddd;
        }
        .panel { padding: 15px; border-bottom: 1px solid #ddd; }
        .panel h3 { margin-bottom: 10px; font-size: 14px; color: #333; }
        .stat { display: flex; justify-content: space-between; padding: 5px 0; }
        .stat-label { color: #666; }
        .stat-value { font-weight: 600; }
        .legend { margin-top: 10px; }
        .legend-item { display: flex; align-items: center; padding: 3px 0; font-size: 12px; }
        .legend-color { width: 20px; height: 4px; margin-right: 8px; border-radius: 2px; }
        .filter-group { margin: 10px 0; }
        .filter-group label { display: block; margin: 5px 0; font-size: 12px; cursor: pointer; }
        .filter-group input { margin-right: 5px; }
        #info-panel { display: none; }
        #info-panel.active { display: block; }
        .info-row { padding: 8px 0; border-bottom: 1px solid #eee; }
        .info-label { font-size: 11px; color: #999; text-transform: uppercase; }
        .info-value { font-size: 13px; margin-top: 2px; }
        .task-list { max-height: 300px; overflow-y: auto; }
        .task-item {
            padding: 8px;
            margin: 5px 0;
            background: white;
            border-radius: 4px;
            font-size: 12px;
            cursor: pointer;
            border-left: 3px solid #ccc;
        }
        .task-item:hover { background: #e8f4fc; }
        .task-item.high { border-left-color: #e74c3c; }
        .task-item.medium { border-left-color: #f39c12; }
        .task-item.low { border-left-color: #3498db; }
        .btn {
            padding: 6px 12px;
            background: #3498db;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 12px;
        }
        .btn:hover { background: #2980b9; }
        .btn-group { margin-top: 10px; }
        .source-list { margin-top: 8px; }
        .source-item {
            display: flex;
            align-items: center;
            padding: 6px 8px;
            margin: 4px 0;
            background: white;
            border-radius: 4px;
            font-size: 12px;
            border-left: 3px solid #f59e0b;
        }
        .source-icon { margin-right: 8px; font-size: 14px; }
        .source-name { flex: 1; font-weight: 500; }
        .source-type { 
            font-size: 10px; 
            color: #666; 
            background: #eee; 
            padding: 2px 6px; 
            border-radius: 3px; 
        }
        .merged-badge {
            display: inline-block;
            background: #f59e0b;
            color: white;
            font-size: 10px;
            padding: 1px 5px;
            border-radius: 8px;
            margin-left: 5px;
        }
    </style>
</head>
<body>
    <div id="container">
        <div id="map"></div>
        <div id="sidebar">
            <div class="panel">
                <h3>📊 数据统计</h3>
                <div class="stat"><span class="stat-label">节点数</span><span class="stat-value" id="node-count">0</span></div>
                <div class="stat"><span class="stat-label">聚合节点</span><span class="stat-value" id="merged-count">0</span></div>
                <div class="stat"><span class="stat-label">边数</span><span class="stat-value" id="edge-count">0</span></div>
                <div class="stat"><span class="stat-label">雪道</span><span class="stat-value" id="run-count">0</span></div>
                <div class="stat"><span class="stat-label">缆车</span><span class="stat-value" id="lift-count">0</span></div>
            </div>
            
            <div class="panel">
                <h3>🎿 难度图例</h3>
                <div class="legend">
                    <div class="legend-item"><div class="legend-color" style="background:#22c55e"></div>Novice (初学)</div>
                    <div class="legend-item"><div class="legend-color" style="background:#3b82f6"></div>Easy (简单)</div>
                    <div class="legend-item"><div class="legend-color" style="background:#ef4444"></div>Intermediate (中级)</div>
                    <div class="legend-item"><div class="legend-color" style="background:#111827"></div>Advanced (高级)</div>
                    <div class="legend-item"><div class="legend-color" style="background:#9ca3af"></div>Unknown (未知)</div>
                    <div class="legend-item"><div class="legend-color" style="background:#8b5cf6"></div>Lift (缆车)</div>
                </div>
                <h3 style="margin-top:15px">📍 节点图例</h3>
                <div class="legend">
                    <div class="legend-item"><div class="legend-color" style="background:#374151; width:10px; height:10px; border-radius:50%"></div>普通节点</div>
                    <div class="legend-item"><div class="legend-color" style="background:#8b5cf6; width:12px; height:12px; border-radius:50%"></div>缆车站</div>
                    <div class="legend-item"><div class="legend-color" style="background:#f59e0b; width:14px; height:14px; border-radius:50%"></div>聚合节点 (点击查看详情)</div>
                </div>
            </div>
            
            <div class="panel">
                <h3>🔍 显示筛选</h3>
                <div class="filter-group">
                    <label><input type="checkbox" id="show-runs" checked> 显示雪道</label>
                    <label><input type="checkbox" id="show-lifts" checked> 显示缆车</label>
                    <label><input type="checkbox" id="show-nodes" checked> 显示节点</label>
                    <label><input type="checkbox" id="show-direction" checked> 显示方向</label>
                </div>
            </div>
            
            <div class="panel">
                <h3>⚠️ 待审核任务 (<span id="task-count">0</span>)</h3>
                <div class="filter-group">
                    <label><input type="checkbox" class="task-filter" value="check_direction" checked> 方向确认</label>
                    <label><input type="checkbox" class="task-filter" value="missing_difficulty" checked> 缺少难度</label>
                    <label><input type="checkbox" class="task-filter" value="missing_name" checked> 缺少名称</label>
                    <label><input type="checkbox" class="task-filter" value="isolated_node" checked> 孤立节点</label>
                </div>
                <div class="task-list" id="task-list"></div>
            </div>
            
            <div class="panel" id="info-panel">
                <h3>📝 选中信息</h3>
                <div id="info-content"></div>
            </div>
        </div>
    </div>

    <script>
        // 等待 DOM 和 Leaflet 加载完成
        document.addEventListener('DOMContentLoaded', function() {
        
        // 数据
        const graphData = __GRAPH_DATA__;
        const reviewTasks = __REVIEW_TASKS__;
        
        // 难度颜色
        const difficultyColors = {
            'novice': '#22c55e',
            'easy': '#3b82f6',
            'intermediate': '#ef4444',
            'advanced': '#111827',
            'expert': '#111827',
            'unknown': '#9ca3af',
            '': '#9ca3af'
        };
        
        // 初始化地图
        const center = [graphData.center.lat, graphData.center.lon];
        const map = L.map('map').setView(center, 14);
        
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap'
        }).addTo(map);
        
        // 图层
        const runLayers = L.layerGroup().addTo(map);
        const liftLayers = L.layerGroup().addTo(map);
        const nodeLayers = L.layerGroup().addTo(map);
        const arrowLayers = L.layerGroup().addTo(map);
        
        // 边 -> Polyline 映射
        const edgePolylines = {};
        const nodeMarkers = {};
        
        // 绘制边
        graphData.edges.forEach(edge => {
            const coords = parseWKT(edge.geom);
            const color = edge.src_feat_type === 'lift' ? '#8b5cf6' : (difficultyColors[edge.difficulty] || '#9ca3af');
            const weight = edge.src_feat_type === 'lift' ? 4 : 3;
            
            const polyline = L.polyline(coords, {
                color: color,
                weight: weight,
                opacity: 0.8
            });
            
            polyline.bindPopup(createEdgePopup(edge));
            polyline.on('click', () => showEdgeInfo(edge));
            
            if (edge.src_feat_type === 'lift') {
                polyline.addTo(liftLayers);
            } else {
                polyline.addTo(runLayers);
            }
            
            edgePolylines[edge.edge_id] = polyline;
            
            // 添加方向箭头
            if (edge.oneway && coords.length >= 2) {
                // 在 40% 和 70% 位置各放一个箭头
                [0.4, 0.7].forEach(pos => {
                    const idx = Math.floor((coords.length - 1) * pos);
                    const p1 = coords[idx];
                    const p2 = coords[Math.min(idx + 1, coords.length - 1)];
                    addArrow(p1, p2, color);
                });
            }
        });
        
        // 原始点图层（用于显示聚合来源）
        const sourcePointsLayer = L.layerGroup();
        
        // 绘制节点
        graphData.nodes.forEach(node => {
            const isMerged = node.merged_count > 1;
            const isLiftStation = node.kind === 'lift_station';
            
            // 聚合节点用不同样式
            let color, radius, weight;
            if (isMerged) {
                color = '#f59e0b';  // 橙色表示聚合
                radius = Math.min(4 + node.merged_count, 10);  // 根据聚合数量调整大小
                weight = 3;
            } else if (isLiftStation) {
                color = '#8b5cf6';
                radius = 6;
                weight = 2;
            } else {
                color = '#374151';
                radius = 4;
                weight = 2;
            }
            
            const marker = L.circleMarker([node.lat, node.lon], {
                radius: radius,
                fillColor: color,
                color: '#fff',
                weight: weight,
                fillOpacity: 0.9
            }).addTo(nodeLayers);
            
            // 点击显示详情
            marker.on('click', () => showNodeInfo(node));
            nodeMarkers[node.node_id] = marker;
        });
        
        // 显示节点详情
        function showNodeInfo(node) {
            const panel = document.getElementById('info-panel');
            const content = document.getElementById('info-content');
            panel.classList.add('active');
            
            // 清除之前的原始点
            sourcePointsLayer.clearLayers();
            
            let html = `
                <div class="info-row"><div class="info-label">Node ID</div><div class="info-value">${node.node_id}</div></div>
                <div class="info-row"><div class="info-label">类型</div><div class="info-value">${node.kind}</div></div>
                <div class="info-row"><div class="info-label">坐标</div><div class="info-value">${node.lon.toFixed(6)}, ${node.lat.toFixed(6)}</div></div>
                <div class="info-row"><div class="info-label">聚合点数</div><div class="info-value">${node.merged_count || 1}</div></div>
            `;
            
            if (node.sources && node.sources.length > 0) {
                html += `<div class="info-row"><div class="info-label">聚合来源</div></div>`;
                html += `<div class="source-list">`;
                
                node.sources.forEach((src, idx) => {
                    const typeIcon = src.type === 'lift' ? '🚡' : '⛷️';
                    html += `
                        <div class="source-item" data-idx="${idx}">
                            <span class="source-icon">${typeIcon}</span>
                            <span class="source-name">${src.feat_name}</span>
                            <span class="source-type">${src.type}</span>
                        </div>
                    `;
                    
                    // 在地图上显示原始点
                    const srcMarker = L.circleMarker([src.lat, src.lon], {
                        radius: 6,
                        fillColor: src.type === 'lift' ? '#8b5cf6' : '#22c55e',
                        color: '#fff',
                        weight: 2,
                        fillOpacity: 0.8
                    });
                    srcMarker.bindPopup(`<b>${src.feat_name}</b><br>类型: ${src.type}<br>原始坐标`);
                    srcMarker.addTo(sourcePointsLayer);
                });
                
                html += `</div>`;
                
                // 添加到地图
                sourcePointsLayer.addTo(map);
                
                // 如果是聚合点，画连线到原始点
                if (node.sources.length > 1) {
                    node.sources.forEach(src => {
                        L.polyline([[node.lat, node.lon], [src.lat, src.lon]], {
                            color: '#f59e0b',
                            weight: 1,
                            dashArray: '4,4',
                            opacity: 0.6
                        }).addTo(sourcePointsLayer);
                    });
                }
            }
            
            html += `<div class="btn-group"><button class="btn" onclick="clearSourcePoints()">清除原始点</button></div>`;
            
            content.innerHTML = html;
        }
        
        // 清除原始点显示
        window.clearSourcePoints = function() {
            sourcePointsLayer.clearLayers();
        };
        
        // 解析 WKT
        function parseWKT(wkt) {
            const match = wkt.match(/LINESTRING\\((.+)\\)/);
            if (!match) return [];
            return match[1].split(', ').map(p => {
                const [lon, lat] = p.split(' ').map(Number);
                return [lat, lon];
            });
        }
        
        // 添加箭头
        function addArrow(p1, p2, color) {
            // 计算方向角度
            // coords 格式是 [lat, lon]，屏幕 y 轴向下所以 lat 取负
            const dLat = p2[0] - p1[0];
            const dLon = p2[1] - p1[1];
            const angle = Math.atan2(-dLat, dLon) * 180 / Math.PI;
            
            const midLat = (p1[0] + p2[0]) / 2;
            const midLon = (p1[1] + p2[1]) / 2;
            
            const icon = L.divIcon({
                html: `<div style="transform: rotate(${angle}deg); color: ${color}; font-size: 10px; line-height: 1;">▶</div>`,
                className: 'arrow-icon',
                iconSize: [10, 10],
                iconAnchor: [5, 5]
            });
            
            L.marker([midLat, midLon], { icon: icon }).addTo(arrowLayers);
        }
        
        // 创建边弹窗
        function createEdgePopup(edge) {
            const isLift = edge.src_feat_type === 'lift';
            if (isLift) {
                return `
                    <b>🚡 ${edge.name || '(无名称)'}</b><br>
                    缆车类型: ${edge.lift_type || '未知'}<br>
                    ${edge.oneway ? '单向' : '双向'}通行<br>
                    长度: ${(edge.length_m / 1000).toFixed(2)} km
                    ${edge.duration ? `<br>运行时长: ${Math.floor(edge.duration/60)}分钟` : ''}
                    ${edge.occupancy ? `<br>载客量: ${edge.occupancy}人` : ''}
                `;
            } else {
                return `
                    <b>⛷️ ${edge.name || '(无名称)'}</b><br>
                    难度: ${edge.difficulty || '未知'}<br>
                    长度: ${(edge.length_m / 1000).toFixed(2)} km
                `;
            }
        }
        
        // 显示边详情
        function showEdgeInfo(edge) {
            const panel = document.getElementById('info-panel');
            const content = document.getElementById('info-content');
            panel.classList.add('active');
            
            const isLift = edge.src_feat_type === 'lift';
            let html = `
                <div class="info-row"><div class="info-label">Edge ID</div><div class="info-value">${edge.edge_id}</div></div>
                <div class="info-row"><div class="info-label">名称</div><div class="info-value">${edge.name || '(空)'}</div></div>
                <div class="info-row"><div class="info-label">类型</div><div class="info-value">${isLift ? '🚡 缆车' : '⛷️ 雪道'}</div></div>
            `;
            
            if (isLift) {
                html += `
                    <div class="info-row"><div class="info-label">缆车类型</div><div class="info-value">${edge.lift_type || '未知'}</div></div>
                    <div class="info-row"><div class="info-label">通行方向</div><div class="info-value">${edge.oneway ? '单向' : '双向'}</div></div>
                    ${edge.duration ? `<div class="info-row"><div class="info-label">运行时长</div><div class="info-value">${Math.floor(edge.duration/60)}分${edge.duration%60}秒</div></div>` : ''}
                    ${edge.occupancy ? `<div class="info-row"><div class="info-label">载客量</div><div class="info-value">${edge.occupancy}人</div></div>` : ''}
                `;
            } else {
                html += `
                    <div class="info-row"><div class="info-label">难度</div><div class="info-value">${edge.difficulty || '未知'}</div></div>
                    <div class="info-row"><div class="info-label">通行方向</div><div class="info-value">${edge.oneway ? '单向（下山）' : '双向'}</div></div>
                `;
            }
            
            html += `
                <div class="info-row"><div class="info-label">长度</div><div class="info-value">${(edge.length_m / 1000).toFixed(2)} km</div></div>
                <div class="info-row"><div class="info-label">起点</div><div class="info-value">Node ${edge.from_node}</div></div>
                <div class="info-row"><div class="info-label">终点</div><div class="info-value">Node ${edge.to_node}</div></div>
                <div class="info-row"><div class="info-label">源 ID</div><div class="info-value">${edge.src_feat_id.substring(0, 12)}...</div></div>
            `;
            
            content.innerHTML = html;
        }
        
        // 更新统计
        document.getElementById('node-count').textContent = graphData.nodes.length;
        document.getElementById('merged-count').textContent = graphData.nodes.filter(n => n.merged_count > 1).length;
        document.getElementById('edge-count').textContent = graphData.edges.length;
        document.getElementById('run-count').textContent = graphData.edges.filter(e => e.src_feat_type === 'run').length;
        document.getElementById('lift-count').textContent = graphData.edges.filter(e => e.src_feat_type === 'lift').length;
        document.getElementById('task-count').textContent = reviewTasks.length;
        
        // 筛选控制
        document.getElementById('show-runs').addEventListener('change', e => {
            e.target.checked ? map.addLayer(runLayers) : map.removeLayer(runLayers);
        });
        document.getElementById('show-lifts').addEventListener('change', e => {
            e.target.checked ? map.addLayer(liftLayers) : map.removeLayer(liftLayers);
        });
        document.getElementById('show-nodes').addEventListener('change', e => {
            e.target.checked ? map.addLayer(nodeLayers) : map.removeLayer(nodeLayers);
        });
        document.getElementById('show-direction').addEventListener('change', e => {
            e.target.checked ? map.addLayer(arrowLayers) : map.removeLayer(arrowLayers);
        });
        
        // 渲染任务列表
        function renderTasks() {
            const checkedTypes = [...document.querySelectorAll('.task-filter:checked')].map(el => el.value);
            const filtered = reviewTasks.filter(t => checkedTypes.includes(t.task_type));
            
            const list = document.getElementById('task-list');
            list.innerHTML = filtered.slice(0, 50).map(task => `
                <div class="task-item ${task.priority}" data-edge="${task.edge_id}" data-node="${task.node_id}">
                    <strong>${task.task_type}</strong><br>
                    ${task.description}
                </div>
            `).join('');
            
            // 点击任务定位
            list.querySelectorAll('.task-item').forEach(el => {
                el.addEventListener('click', () => {
                    const edgeId = el.dataset.edge;
                    const nodeId = el.dataset.node;
                    
                    if (edgeId && edgeId !== 'null') {
                        const edge = graphData.edges.find(e => e.edge_id == edgeId);
                        if (edge) {
                            const coords = parseWKT(edge.geom);
                            if (coords.length > 0) {
                                map.setView(coords[Math.floor(coords.length / 2)], 16);
                                edgePolylines[edgeId].openPopup();
                            }
                        }
                    } else if (nodeId && nodeId !== 'null') {
                        const node = graphData.nodes.find(n => n.node_id == nodeId);
                        if (node) {
                            map.setView([node.lat, node.lon], 17);
                            nodeMarkers[nodeId].openPopup();
                        }
                    }
                });
            });
        }
        
        document.querySelectorAll('.task-filter').forEach(el => {
            el.addEventListener('change', renderTasks);
        });
        
        renderTasks();
        
        }); // end DOMContentLoaded
    </script>
</body>
</html>
'''


def load_graph_data(db_path: str) -> dict:
    """从 SQLite 加载图数据"""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    
    # 加载节点
    nodes = []
    for row in cur.execute('SELECT * FROM nodes'):
        nodes.append(dict(row))
    
    # 加载节点聚合来源
    node_sources = {}
    try:
        for row in cur.execute('SELECT * FROM node_sources'):
            source = dict(row)
            nid = source['node_id']
            if nid not in node_sources:
                node_sources[nid] = []
            node_sources[nid].append({
                'lon': source['lon'],
                'lat': source['lat'],
                'type': source['source_type'],
                'feat_id': source['feat_id'],
                'feat_name': source['feat_name']
            })
    except sqlite3.OperationalError:
        # 旧版本数据库没有这个表
        pass
    
    # 将聚合来源附加到节点
    for node in nodes:
        node['sources'] = node_sources.get(node['node_id'], [])
        node['merged_count'] = len(node['sources'])
    
    # 加载边
    edges = []
    for row in cur.execute('SELECT * FROM edges'):
        edge = dict(row)
        edge['oneway'] = bool(edge['oneway'])
        edge['is_enabled'] = bool(edge['is_enabled'])
        edges.append(edge)
    
    # 计算中心点
    if nodes:
        center_lon = sum(n['lon'] for n in nodes) / len(nodes)
        center_lat = sum(n['lat'] for n in nodes) / len(nodes)
    else:
        center_lon, center_lat = 0, 0
    
    conn.close()
    
    return {
        'nodes': nodes,
        'edges': edges,
        'center': {'lon': center_lon, 'lat': center_lat}
    }


def main():
    parser = argparse.ArgumentParser(description='生成图数据 HTML 预览')
    parser.add_argument('db', help='ski_graph.sqlite 文件')
    parser.add_argument('-o', '--output', default='preview.html', help='输出 HTML 文件')
    parser.add_argument('-t', '--tasks', default='review_tasks.json', help='审核任务 JSON')
    
    args = parser.parse_args()
    
    print(f"加载 {args.db}...")
    graph_data = load_graph_data(args.db)
    
    print(f"加载 {args.tasks}...")
    try:
        with open(args.tasks, 'r', encoding='utf-8') as f:
            review_tasks = json.load(f)
    except FileNotFoundError:
        review_tasks = []
    
    print(f"生成 {args.output}...")
    html = HTML_TEMPLATE.replace('__GRAPH_DATA__', json.dumps(graph_data, ensure_ascii=False))
    html = html.replace('__REVIEW_TASKS__', json.dumps(review_tasks, ensure_ascii=False))
    
    with open(args.output, 'w', encoding='utf-8') as f:
        f.write(html)
    
    print("完成!")
    print(f"  - 节点: {len(graph_data['nodes'])}")
    print(f"  - 边: {len(graph_data['edges'])}")
    print(f"  - 审核任务: {len(review_tasks)}")


if __name__ == '__main__':
    main()
