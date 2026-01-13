#!/usr/bin/env python3
"""
生成 ski_graph.sqlite 的 HTML 可视化编辑器
支持编辑边属性、翻转方向、生成 patch.json

用法:
    python generate_editor.py ski_graph.sqlite -o editor.html
"""

import sqlite3
import json
import argparse
from pathlib import Path


HTML_TEMPLATE = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>SnowNavi 图数据编辑器</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 13px; }
        #container { display: flex; height: 100vh; }
        #map { flex: 1; }
        
        #sidebar {
            width: 380px;
            background: #f5f5f5;
            border-left: 1px solid #ddd;
            overflow-y: auto;
        }
        
        .section {
            padding: 15px;
            border-bottom: 1px solid #ddd;
        }
        .section h3 {
            font-size: 14px;
            margin-bottom: 12px;
            color: #333;
        }
        
        /* 提示框 */
        .info-box {
            background: #e7f3ff;
            border: 1px solid #b3d7ff;
            border-radius: 4px;
            padding: 10px;
            margin-bottom: 12px;
            font-size: 12px;
            color: #0056b3;
        }
        
        /* 表单样式 */
        .form-row {
            margin-bottom: 12px;
        }
        .form-row label {
            display: block;
            font-size: 11px;
            color: #666;
            margin-bottom: 4px;
            text-transform: uppercase;
        }
        .form-row input, .form-row select {
            width: 100%;
            padding: 8px;
            border: 1px solid #ccc;
            border-radius: 4px;
            font-size: 13px;
        }
        .form-row input:disabled {
            background: #eee;
        }
        .form-row select {
            background: white;
        }
        .form-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
        }
        
        /* 按钮 */
        .btn {
            padding: 10px 16px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 13px;
            font-weight: 500;
        }
        .btn-primary { background: #007bff; color: white; }
        .btn-primary:hover { background: #0056b3; }
        .btn-warning { background: #fd7e14; color: white; }
        .btn-warning:hover { background: #e56500; }
        .btn-success { background: #28a745; color: white; }
        .btn-success:hover { background: #1e7e34; }
        .btn-danger { background: #dc3545; color: white; }
        .btn-danger:hover { background: #bd2130; }
        .btn-sm { padding: 6px 10px; font-size: 12px; }
        .btn:disabled { background: #ccc; cursor: not-allowed; }
        
        .btn-group {
            display: flex;
            gap: 10px;
            margin-top: 15px;
        }
        .btn-group .btn {
            flex: 1;
        }
        
        /* 复选框 */
        .checkbox-row {
            display: flex;
            align-items: center;
            margin: 10px 0;
        }
        .checkbox-row input {
            width: auto;
            margin-right: 8px;
        }
        .checkbox-row label {
            margin: 0;
            font-size: 13px;
            color: #333;
        }
        
        /* 变更列表 */
        .change-item {
            padding: 10px;
            margin: 8px 0;
            background: white;
            border-radius: 4px;
            border-left: 3px solid #007bff;
            font-size: 12px;
            cursor: pointer;
        }
        .change-item:hover { background: #f0f7ff; }
        .change-item.flip { border-left-color: #fd7e14; }
        .change-item.disable { border-left-color: #dc3545; }
        .change-type { font-weight: 600; color: #007bff; }
        .change-item.flip .change-type { color: #fd7e14; }
        .change-item.disable .change-type { color: #dc3545; }
        .change-target { color: #333; margin-top: 4px; }
        .change-detail { color: #666; font-size: 11px; margin-top: 4px; }
        
        /* 任务列表 */
        .task-item {
            padding: 8px 10px;
            margin: 5px 0;
            background: white;
            border-radius: 4px;
            border-left: 3px solid #6c757d;
            font-size: 12px;
            cursor: pointer;
        }
        .task-item:hover { background: #e8f4fc; }
        .task-item.high { border-left-color: #dc3545; }
        .task-item.medium { border-left-color: #fd7e14; }
        
        /* 节点信息 */
        .node-info {
            background: white;
            border-radius: 4px;
            padding: 12px;
        }
        .node-info h4 { font-size: 13px; margin-bottom: 10px; }
        .source-item {
            display: flex;
            align-items: center;
            padding: 6px 0;
            border-bottom: 1px solid #eee;
            font-size: 12px;
        }
        .source-item:last-child { border-bottom: none; }
        .source-icon { margin-right: 8px; }
        .source-name { flex: 1; }
        .source-type { 
            font-size: 10px; 
            background: #eee; 
            padding: 2px 6px; 
            border-radius: 3px; 
        }
        
        /* 图例 */
        .legend-row {
            display: flex;
            align-items: center;
            padding: 3px 0;
            font-size: 12px;
        }
        .legend-color {
            width: 20px;
            height: 4px;
            margin-right: 8px;
            border-radius: 2px;
        }
        
        /* 筛选 */
        .filter-row {
            display: flex;
            align-items: center;
            padding: 4px 0;
            font-size: 12px;
        }
        .filter-row input {
            margin-right: 6px;
        }
        
        /* Toast */
        #toast {
            position: fixed;
            bottom: 20px;
            left: 50%;
            transform: translateX(-50%);
            background: #333;
            color: white;
            padding: 12px 24px;
            border-radius: 6px;
            font-size: 13px;
            opacity: 0;
            transition: opacity 0.3s;
            z-index: 10000;
        }
        #toast.show { opacity: 1; }
        
        /* 提示状态 */
        .placeholder {
            text-align: center;
            padding: 30px 15px;
            color: #888;
        }
        .placeholder-icon {
            font-size: 40px;
            margin-bottom: 10px;
        }
    </style>
</head>
<body>
    <div id="container">
        <div id="map"></div>
        <div id="sidebar">
            
            <!-- 编辑区域 -->
            <div class="section">
                <h3>✏️ 编辑</h3>
                
                <div id="placeholder" class="placeholder">
                    <div class="placeholder-icon">👆</div>
                    <div>点击地图上的雪道、缆车或节点</div>
                </div>
                
                <!-- 边编辑表单 -->
                <div id="edge-form" style="display:none">
                    <div class="info-box">
                        💡 修改后自动记录到变更列表，最后点击「导出 Patch」保存到文件
                    </div>
                    
                    <div class="form-row">
                        <label>名称</label>
                        <input type="text" id="edit-name" placeholder="输入名称">
                    </div>
                    
                    <!-- 雪道专用字段 -->
                    <div id="run-fields">
                        <div class="form-grid">
                            <div class="form-row">
                                <label>类型</label>
                                <input type="text" id="edit-type" disabled>
                            </div>
                            <div class="form-row">
                                <label>难度</label>
                                <select id="edit-difficulty">
                                    <option value="">未知</option>
                                    <option value="novice">Novice (初学)</option>
                                    <option value="easy">Easy (简单)</option>
                                    <option value="intermediate">Intermediate (中级)</option>
                                    <option value="advanced">Advanced (高级)</option>
                                    <option value="expert">Expert (专家)</option>
                                </select>
                            </div>
                        </div>
                    </div>
                    
                    <!-- 缆车专用字段 -->
                    <div id="lift-fields" style="display:none">
                        <div class="form-grid">
                            <div class="form-row">
                                <label>缆车类型</label>
                                <select id="edit-lift-type">
                                    <option value="gondola">Gondola (厢式)</option>
                                    <option value="chair_lift">Chair Lift (吊椅)</option>
                                    <option value="drag_lift">Drag Lift (拖牵)</option>
                                    <option value="t-bar">T-Bar</option>
                                    <option value="cable_car">Cable Car (缆车)</option>
                                    <option value="funicular">Funicular (缆索)</option>
                                    <option value="magic_carpet">Magic Carpet (魔毯)</option>
                                    <option value="unknown">未知</option>
                                </select>
                            </div>
                            <div class="form-row">
                                <label>载客量</label>
                                <input type="number" id="edit-occupancy" min="0" max="50">
                            </div>
                        </div>
                        <div class="form-row">
                            <label>运行时长（秒）</label>
                            <input type="number" id="edit-duration" min="0" placeholder="例如: 300">
                        </div>
                    </div>
                    
                    <div class="form-grid">
                        <div class="form-row">
                            <label>起点</label>
                            <input type="text" id="edit-from" disabled>
                        </div>
                        <div class="form-row">
                            <label>终点</label>
                            <input type="text" id="edit-to" disabled>
                        </div>
                    </div>
                    
                    <div class="form-row">
                        <label>长度</label>
                        <input type="text" id="edit-length" disabled>
                    </div>
                    
                    <div class="checkbox-row">
                        <input type="checkbox" id="edit-oneway">
                        <label for="edit-oneway">单向通行（显示方向箭头）</label>
                    </div>
                    
                    <div class="checkbox-row">
                        <input type="checkbox" id="edit-enabled">
                        <label for="edit-enabled">启用（参与路由计算）</label>
                    </div>
                    
                    <button class="btn btn-warning" onclick="flipDirection()" style="width:100%">🔄 翻转方向</button>
                </div>
                
                <!-- 节点信息 -->
                <div id="node-info" style="display:none">
                    <div class="node-info">
                        <h4>📍 节点 <span id="node-id"></span></h4>
                        <div class="form-grid" style="margin: 10px 0">
                            <div><strong>类型:</strong> <span id="node-kind"></span></div>
                            <div><strong>聚合数:</strong> <span id="node-count"></span></div>
                        </div>
                        <div id="node-sources"></div>
                    </div>
                </div>

                <!-- 新增 edge 表单 -->
                <div id="new-edge-form" style="display:none">
                    <div class="info-box">
                        💡 选择起点和终点节点，绘制路径后填写属性
                    </div>

                    <div class="form-row">
                        <label>OSM ID (可选，如 way/123456)</label>
                        <input type="text" id="new-osm-id" placeholder="way/123456">
                    </div>

                    <div class="form-row">
                        <label>名称</label>
                        <input type="text" id="new-name" placeholder="输入名称">
                    </div>

                    <!-- 雪道字段 -->
                    <div id="new-run-fields">
                        <div class="form-row">
                            <label>难度</label>
                            <select id="new-difficulty">
                                <option value="">未知</option>
                                <option value="novice">Novice (初学)</option>
                                <option value="easy">Easy (简单)</option>
                                <option value="intermediate">Intermediate (中级)</option>
                                <option value="advanced">Advanced (高级)</option>
                                <option value="expert">Expert (专家)</option>
                            </select>
                        </div>
                    </div>

                    <!-- 缆车字段 -->
                    <div id="new-lift-fields" style="display:none">
                        <div class="form-grid">
                            <div class="form-row">
                                <label>缆车类型</label>
                                <select id="new-lift-type">
                                    <option value="gondola">Gondola (厢式)</option>
                                    <option value="chair_lift">Chair Lift (吊椅)</option>
                                    <option value="drag_lift">Drag Lift (拖牵)</option>
                                    <option value="t-bar">T-Bar</option>
                                    <option value="magic_carpet">Magic Carpet (魔毯)</option>
                                </select>
                            </div>
                            <div class="form-row">
                                <label>载客量</label>
                                <input type="number" id="new-occupancy" min="0" max="50">
                            </div>
                        </div>
                        <div class="form-row">
                            <label>运行时长（秒）</label>
                            <input type="number" id="new-duration" min="0" placeholder="例如: 300">
                        </div>
                    </div>

                    <div class="form-grid">
                        <div class="form-row">
                            <label>起点节点</label>
                            <input type="text" id="new-from" disabled>
                        </div>
                        <div class="form-row">
                            <label>终点节点</label>
                            <input type="text" id="new-to" disabled>
                        </div>
                    </div>

                    <div class="checkbox-row">
                        <input type="checkbox" id="new-oneway" checked>
                        <label for="new-oneway">单向通行</label>
                    </div>

                    <div class="btn-group">
                        <button class="btn btn-success" onclick="confirmNewEdge()">✓ 确认添加</button>
                        <button class="btn btn-danger" onclick="cancelDrawMode()">✗ 取消</button>
                    </div>
                </div>
            </div>

            <!-- 新增区域 -->
            <div class="section">
                <h3>➕ 新增</h3>
                <div id="draw-mode-hint" style="display:none; margin-bottom:10px;">
                    <div class="info-box" style="background:#d4edda; border-color:#28a745; color:#155724;">
                        <strong id="draw-mode-status">绘制模式</strong><br>
                        <span id="draw-mode-tip">点击地图选择起点节点</span>
                    </div>
                </div>
                <div class="btn-group" style="flex-direction:column; gap:8px;">
                    <button class="btn btn-primary" id="btn-add-run" onclick="startDrawEdge('run')">
                        ⛷️ 新增雪道
                    </button>
                    <button class="btn btn-primary" id="btn-add-lift" onclick="startDrawEdge('lift')">
                        🚡 新增缆车
                    </button>
                </div>
            </div>

            <!-- 变更列表 -->
            <div class="section">
                <h3>📝 变更列表 (<span id="change-count">0</span>)</h3>
                <div class="info-box" style="background:#fff3cd; border-color:#ffc107; color:#856404;">
                    ⚠️ 变更仅保存在浏览器内存中，刷新页面会丢失！<br>请及时导出 Patch 文件。
                </div>
                <div id="changes-list">
                    <div style="color:#888; font-size:12px;">暂无变更</div>
                </div>
                <div class="btn-group" style="margin-top:15px;">
                    <button class="btn btn-success" id="export-btn" onclick="exportPatch()" disabled>
                        📤 导出 Patch 文件
                    </button>
                    <button class="btn btn-danger btn-sm" id="clear-btn" onclick="clearChanges()" disabled style="flex:0.5">
                        清空
                    </button>
                </div>
            </div>
            
            <!-- 待审核任务 -->
            <div class="section">
                <h3>⚠️ 待审核 (<span id="task-count">0</span>)</h3>
                <div class="filter-row">
                    <input type="checkbox" id="filter-direction" checked onchange="renderTasks()">
                    <label>方向确认</label>
                </div>
                <div class="filter-row">
                    <input type="checkbox" id="filter-difficulty" checked onchange="renderTasks()">
                    <label>缺少难度</label>
                </div>
                <div id="task-list" style="max-height:200px; overflow-y:auto;"></div>
            </div>
            
            <!-- 显示控制 -->
            <div class="section">
                <h3>🔍 显示控制</h3>
                <div class="filter-row"><input type="checkbox" id="show-runs" checked> 雪道</div>
                <div class="filter-row"><input type="checkbox" id="show-lifts" checked> 缆车</div>
                <div class="filter-row"><input type="checkbox" id="show-nodes" checked> 节点</div>
                <div class="filter-row"><input type="checkbox" id="show-arrows" checked> 方向箭头</div>
            </div>
            
            <!-- 图例 -->
            <div class="section">
                <h3>🎿 图例</h3>
                <div class="legend-row"><div class="legend-color" style="background:#22c55e"></div>Novice</div>
                <div class="legend-row"><div class="legend-color" style="background:#3b82f6"></div>Easy</div>
                <div class="legend-row"><div class="legend-color" style="background:#ef4444"></div>Intermediate</div>
                <div class="legend-row"><div class="legend-color" style="background:#111"></div>Advanced</div>
                <div class="legend-row"><div class="legend-color" style="background:#9ca3af"></div>Unknown</div>
                <div class="legend-row"><div class="legend-color" style="background:#8b5cf6"></div>Lift (缆车)</div>
            </div>
            
        </div>
    </div>
    
    <div id="toast"></div>

<script>
document.addEventListener('DOMContentLoaded', function() {
    // 数据
    const graphData = __GRAPH_DATA__;
    const reviewTasks = __REVIEW_TASKS__;
    const sourceHashes = __SOURCE_HASHES__;
    
    // 保存原始数据用于对比
    const originalEdges = JSON.parse(JSON.stringify(graphData.edges));
    
    // 当前选中
    let currentEdge = null;
    let currentPolyline = null;
    
    // 变更记录 Map: edgeId -> {edge, original, flipped}
    const pendingChanges = new Map();

    // 新增边记录 Map: tempId -> newEdgeData
    const pendingNewEdges = new Map();

    // 绘制模式相关变量
    let drawMode = null;  // 'run' | 'lift' | null
    let drawnPoints = [];  // [[lat, lon], ...]
    let selectedFromNode = null;
    let selectedToNode = null;
    let drawingLine = null;  // Leaflet polyline for preview
    let newEdgeTempId = 0;

    // 难度颜色
    const colors = {
        'novice': '#22c55e',
        'easy': '#3b82f6', 
        'intermediate': '#ef4444',
        'advanced': '#111',
        'expert': '#111',
        '': '#9ca3af'
    };
    
    // 初始化地图
    const map = L.map('map').setView([graphData.center.lat, graphData.center.lon], 14);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap'
    }).addTo(map);
    
    // 图层
    const runLayer = L.layerGroup().addTo(map);
    const liftLayer = L.layerGroup().addTo(map);
    const nodeLayer = L.layerGroup().addTo(map);
    const arrowLayer = L.layerGroup().addTo(map);
    const sourceLayer = L.layerGroup(); // 用于显示聚合点来源
    const drawLayer = L.layerGroup().addTo(map);  // 绘制模式图层
    const newEdgeLayer = L.layerGroup().addTo(map);  // 新增边图层
    
    // 存储引用
    const polylines = {};
    
    // 解析 WKT
    function parseWKT(wkt) {
        const m = wkt.match(/LINESTRING\\((.+)\\)/);
        if (!m) return [];
        return m[1].split(', ').map(p => {
            const [lon, lat] = p.split(' ').map(Number);
            return [lat, lon];
        });
    }
    
    // 绘制边
    function drawEdges() {
        runLayer.clearLayers();
        liftLayer.clearLayers();
        arrowLayer.clearLayers();
        
        graphData.edges.forEach(edge => {
            const coords = parseWKT(edge.geom);
            if (coords.length < 2) return;
            
            const isLift = edge.src_feat_type === 'lift';
            const color = isLift ? '#8b5cf6' : (colors[edge.difficulty] || '#9ca3af');
            
            const line = L.polyline(coords, {
                color: color,
                weight: isLift ? 4 : 3,
                opacity: edge.is_enabled ? 0.8 : 0.4,
                dashArray: edge.is_enabled ? null : '5,5'
            });
            
            line.on('click', () => selectEdge(edge, line));
            line.addTo(isLift ? liftLayer : runLayer);
            polylines[edge.edge_id] = line;
            
            // 方向箭头 - 指向 from_node → to_node 方向
            if (edge.oneway && coords.length >= 2) {
                // 在线的 1/3 和 2/3 位置各放一个箭头
                const positions = [0.4, 0.7];
                
                positions.forEach(pos => {
                    const idx = Math.floor((coords.length - 1) * pos);
                    const p1 = coords[idx];
                    const p2 = coords[Math.min(idx + 1, coords.length - 1)];
                    
                    // 计算方向角度
                    // coords 格式是 [lat, lon]，屏幕 y 轴向下所以 lat 取负
                    const dLat = p2[0] - p1[0];
                    const dLon = p2[1] - p1[1];
                    // ▶ 默认指向右(东)，CSS rotate 顺时针
                    // 需要计算从东方向到目标方向的顺时针角度
                    const angle = Math.atan2(-dLat, dLon) * 180 / Math.PI;
                    
                    const icon = L.divIcon({
                        html: `<div style="transform:rotate(${angle}deg);color:${color};font-size:10px;line-height:1;">▶</div>`,
                        className: '',
                        iconSize: [10, 10],
                        iconAnchor: [5, 5]
                    });
                    
                    // 箭头放在 p1 和 p2 的中点，确保在线上
                    L.marker([(p1[0]+p2[0])/2, (p1[1]+p2[1])/2], {icon, interactive: false}).addTo(arrowLayer);
                });
            }
        });
    }
    
    // 绘制节点
    function drawNodes() {
        nodeLayer.clearLayers();
        graphData.nodes.forEach(node => {
            const color = node.kind === 'lift_station' ? '#8b5cf6' : 
                         (node.merged_count > 1 ? '#f59e0b' : '#374151');
            const r = node.merged_count > 1 ? Math.min(4 + node.merged_count, 10) : 4;
            
            const marker = L.circleMarker([node.lat, node.lon], {
                radius: r,
                fillColor: color,
                color: '#fff',
                weight: 2,
                fillOpacity: 0.9
            });
            
            marker.on('click', () => selectNode(node));
            marker.addTo(nodeLayer);
        });
    }
    
    // 选中边
    function selectEdge(edge, line) {
        // 清除之前状态
        clearSelection();
        
        currentEdge = edge;
        currentPolyline = line;
        line.setStyle({weight: 6});
        line.bringToFront();
        
        // 显示边编辑表单
        document.getElementById('placeholder').style.display = 'none';
        document.getElementById('edge-form').style.display = 'block';
        document.getElementById('node-info').style.display = 'none';
        
        const isLift = edge.src_feat_type === 'lift';
        
        // 根据类型显示/隐藏对应字段
        document.getElementById('run-fields').style.display = isLift ? 'none' : 'block';
        document.getElementById('lift-fields').style.display = isLift ? 'block' : 'none';
        
        // 填充通用字段
        document.getElementById('edit-name').value = edge.name || '';
        document.getElementById('edit-from').value = 'Node ' + edge.from_node;
        document.getElementById('edit-to').value = 'Node ' + edge.to_node;
        document.getElementById('edit-length').value = (edge.length_m / 1000).toFixed(2) + ' km';
        document.getElementById('edit-oneway').checked = edge.oneway;
        document.getElementById('edit-enabled').checked = edge.is_enabled;
        
        if (isLift) {
            // 填充缆车专用字段
            document.getElementById('edit-lift-type').value = edge.lift_type || 'unknown';
            document.getElementById('edit-occupancy').value = edge.occupancy || '';
            document.getElementById('edit-duration').value = edge.duration || '';
        } else {
            // 填充雪道专用字段
            document.getElementById('edit-type').value = edge.src_feat_type;
            document.getElementById('edit-difficulty').value = edge.difficulty || '';
        }
    }
    
    // 选中节点
    function selectNode(node) {
        // 清除之前状态
        clearSelection();
        sourceLayer.clearLayers();
        
        // 显示节点信息
        document.getElementById('placeholder').style.display = 'none';
        document.getElementById('edge-form').style.display = 'none';
        document.getElementById('node-info').style.display = 'block';
        
        document.getElementById('node-id').textContent = node.node_id;
        document.getElementById('node-kind').textContent = node.kind;
        document.getElementById('node-count').textContent = node.merged_count || 1;
        
        // 显示聚合来源
        const sourcesDiv = document.getElementById('node-sources');
        if (node.sources && node.sources.length > 0) {
            let html = '<div style="margin-top:10px;"><strong>聚合来源:</strong></div>';
            node.sources.forEach(src => {
                const icon = src.type === 'lift' ? '🚡' : '⛷️';
                html += `<div class="source-item">
                    <span class="source-icon">${icon}</span>
                    <span class="source-name">${src.feat_name}</span>
                    <span class="source-type">${src.type}</span>
                </div>`;
                
                // 在地图上显示原始点
                L.circleMarker([src.lat, src.lon], {
                    radius: 5,
                    fillColor: src.type === 'lift' ? '#8b5cf6' : '#22c55e',
                    color: '#fff',
                    weight: 1,
                    fillOpacity: 0.8
                }).addTo(sourceLayer);
                
                // 连线
                L.polyline([[node.lat, node.lon], [src.lat, src.lon]], {
                    color: '#f59e0b',
                    weight: 1,
                    dashArray: '3,3',
                    opacity: 0.6
                }).addTo(sourceLayer);
            });
            sourcesDiv.innerHTML = html;
            sourceLayer.addTo(map);
        } else {
            sourcesDiv.innerHTML = '<div style="color:#888;margin-top:10px;">无聚合来源</div>';
        }
    }
    
    // 清除选中状态
    function clearSelection() {
        if (currentPolyline && currentEdge) {
            currentPolyline.setStyle({weight: currentEdge.src_feat_type === 'lift' ? 4 : 3});
        }
        currentEdge = null;
        currentPolyline = null;
        sourceLayer.clearLayers();
    }
    
    // 记录变更
    function recordChange() {
        if (!currentEdge) return;
        
        const edgeId = currentEdge.edge_id;
        const original = originalEdges.find(e => e.edge_id === edgeId);
        const isLift = currentEdge.src_feat_type === 'lift';
        
        // 检查是否有变化
        let change = pendingChanges.get(edgeId) || { 
            edge: currentEdge, 
            original: original,
            flipped: false,
            updates: {}
        };
        
        // 通用字段
        const newName = document.getElementById('edit-name').value;
        const newOneway = document.getElementById('edit-oneway').checked;
        const newEnabled = document.getElementById('edit-enabled').checked;
        
        // 对比原始值
        change.updates = {};
        
        if (newName !== (original.name || '')) {
            change.updates.name = newName;
            currentEdge.name = newName;
        }
        if (newOneway !== original.oneway) {
            change.updates.oneway = newOneway;
            currentEdge.oneway = newOneway;
        }
        if (newEnabled !== original.is_enabled) {
            change.updates.is_enabled = newEnabled;
            currentEdge.is_enabled = newEnabled;
        }
        
        if (isLift) {
            // 缆车专用字段
            const newLiftType = document.getElementById('edit-lift-type').value;
            const newOccupancy = parseInt(document.getElementById('edit-occupancy').value) || 0;
            const newDuration = parseInt(document.getElementById('edit-duration').value) || 0;
            
            if (newLiftType !== (original.lift_type || '')) {
                change.updates.lift_type = newLiftType;
                currentEdge.lift_type = newLiftType;
            }
            if (newOccupancy !== (original.occupancy || 0)) {
                change.updates.occupancy = newOccupancy;
                currentEdge.occupancy = newOccupancy;
            }
            if (newDuration !== (original.duration || 0)) {
                change.updates.duration = newDuration;
                currentEdge.duration = newDuration;
            }
        } else {
            // 雪道专用字段
            const newDiff = document.getElementById('edit-difficulty').value;
            if (newDiff !== (original.difficulty || '')) {
                change.updates.difficulty = newDiff;
                currentEdge.difficulty = newDiff;
            }
        }
        
        // 只有有变化才记录
        if (change.flipped || Object.keys(change.updates).length > 0) {
            pendingChanges.set(edgeId, change);
        } else {
            pendingChanges.delete(edgeId);
        }
        
        updateChangesUI();
        drawEdges();
        
        // 重新选中
        const newLine = polylines[edgeId];
        if (newLine) {
            currentPolyline = newLine;
            newLine.setStyle({weight: 6});
        }
    }
    
    // 翻转方向
    window.flipDirection = function() {
        if (!currentEdge) return;
        
        const edgeId = currentEdge.edge_id;
        const original = originalEdges.find(e => e.edge_id === edgeId);
        
        // 交换起终点
        const tmp = currentEdge.from_node;
        currentEdge.from_node = currentEdge.to_node;
        currentEdge.to_node = tmp;
        
        // 反转几何
        const coords = parseWKT(currentEdge.geom);
        coords.reverse();
        currentEdge.geom = 'LINESTRING(' + coords.map(c => `${c[1]} ${c[0]}`).join(', ') + ')';
        
        // 记录变更
        let change = pendingChanges.get(edgeId) || {
            edge: currentEdge,
            original: original,
            flipped: false,
            updates: {}
        };
        change.flipped = !change.flipped;
        
        if (change.flipped || Object.keys(change.updates).length > 0) {
            pendingChanges.set(edgeId, change);
        } else {
            pendingChanges.delete(edgeId);
        }
        
        // 更新显示
        document.getElementById('edit-from').value = 'Node ' + currentEdge.from_node;
        document.getElementById('edit-to').value = 'Node ' + currentEdge.to_node;
        
        updateChangesUI();
        drawEdges();
        
        // 重新选中
        const newLine = polylines[edgeId];
        if (newLine) {
            currentPolyline = newLine;
            newLine.setStyle({weight: 6});
        }
        
        showToast('方向已翻转');
    };
    
    // 绑定表单变更事件
    document.getElementById('edit-name').addEventListener('change', recordChange);
    document.getElementById('edit-difficulty').addEventListener('change', recordChange);
    document.getElementById('edit-enabled').addEventListener('change', recordChange);
    document.getElementById('edit-oneway').addEventListener('change', recordChange);
    document.getElementById('edit-lift-type').addEventListener('change', recordChange);
    document.getElementById('edit-occupancy').addEventListener('change', recordChange);
    document.getElementById('edit-duration').addEventListener('change', recordChange);
    
    // 更新变更列表 UI
    function updateChangesUI() {
        const list = document.getElementById('changes-list');
        const count = document.getElementById('change-count');
        const exportBtn = document.getElementById('export-btn');
        const clearBtn = document.getElementById('clear-btn');

        const totalCount = pendingChanges.size + pendingNewEdges.size;
        count.textContent = totalCount;
        exportBtn.disabled = totalCount === 0;
        clearBtn.disabled = totalCount === 0;

        if (totalCount === 0) {
            list.innerHTML = '<div style="color:#888;font-size:12px;">暂无变更</div>';
            return;
        }

        let html = '';

        // 显示新增边
        pendingNewEdges.forEach((newEdge, tempId) => {
            const isLift = newEdge.src_feat_type === 'lift';
            const typeIcon = isLift ? '🚡' : '⛷️';
            const details = [];
            if (newEdge.name) details.push(`名称: "${newEdge.name}"`);
            if (newEdge.osm_id) details.push(`OSM: ${newEdge.osm_id}`);
            if (newEdge.difficulty) details.push(`难度: ${newEdge.difficulty}`);

            html += `<div class="change-item" style="border-left-color:#28a745;">
                <div class="change-type" style="color:#28a745;">新增${isLift ? '缆车' : '雪道'}</div>
                <div class="change-target">${typeIcon} ${newEdge.name || '(未命名)'}</div>
                <div class="change-detail">Node ${newEdge.from_node} → Node ${newEdge.to_node}</div>
                ${details.length > 0 ? `<div class="change-detail">${details.join(', ')}</div>` : ''}
            </div>`;
        });

        // 显示现有边的修改
        pendingChanges.forEach((change, id) => {
            const parts = [];
            const details = [];
            const isLift = change.edge.src_feat_type === 'lift';

            if (change.flipped) {
                parts.push('翻转方向');
            }
            if (change.updates.name !== undefined) {
                parts.push('修改名称');
                details.push(`名称: "${change.updates.name}"`);
            }
            if (change.updates.oneway !== undefined) {
                parts.push(change.updates.oneway ? '改为单向' : '改为双向');
            }
            if (change.updates.difficulty !== undefined) {
                parts.push('修改难度');
                details.push(`难度: ${change.updates.difficulty || '未知'}`);
            }
            if (change.updates.lift_type !== undefined) {
                parts.push('修改缆车类型');
                details.push(`类型: ${change.updates.lift_type}`);
            }
            if (change.updates.occupancy !== undefined) {
                parts.push('修改载客量');
                details.push(`载客: ${change.updates.occupancy}`);
            }
            if (change.updates.duration !== undefined) {
                parts.push('修改运行时长');
                details.push(`时长: ${change.updates.duration}s`);
            }
            if (change.updates.is_enabled !== undefined) {
                parts.push(change.updates.is_enabled ? '启用' : '禁用');
            }

            const cls = change.flipped ? 'flip' : (change.updates.is_enabled === false ? 'disable' : '');
            const typeIcon = isLift ? '🚡' : '⛷️';
            html += `<div class="change-item ${cls}" onclick="locateEdge(${id})">
                <div class="change-type">${parts.join(' + ')}</div>
                <div class="change-target">${typeIcon} Edge ${id}: ${change.edge.name || '(未命名)'}</div>
                ${details.length > 0 ? `<div class="change-detail">${details.join(', ')}</div>` : ''}
            </div>`;
        });
        list.innerHTML = html;
    }
    
    // 定位边
    window.locateEdge = function(edgeId) {
        const edge = graphData.edges.find(e => e.edge_id === edgeId);
        const line = polylines[edgeId];
        if (edge && line) {
            const coords = parseWKT(edge.geom);
            if (coords.length > 0) {
                map.setView(coords[Math.floor(coords.length/2)], 16);
                selectEdge(edge, line);
            }
        }
    };
    
    // 清空变更
    window.clearChanges = function() {
        if (!confirm('确定要清空所有变更吗？页面将恢复到初始状态。')) return;

        pendingChanges.clear();
        pendingNewEdges.clear();

        // 恢复原始数据
        graphData.edges = JSON.parse(JSON.stringify(originalEdges));

        // 清除新增边图层
        newEdgeLayer.clearLayers();
        drawLayer.clearLayers();

        // 重置绘制模式
        drawMode = null;
        drawnPoints = [];
        selectedFromNode = null;
        selectedToNode = null;

        clearSelection();
        document.getElementById('placeholder').style.display = 'block';
        document.getElementById('edge-form').style.display = 'none';
        document.getElementById('node-info').style.display = 'none';
        document.getElementById('new-edge-form').style.display = 'none';
        document.getElementById('draw-mode-hint').style.display = 'none';
        document.getElementById('btn-add-run').disabled = false;
        document.getElementById('btn-add-lift').disabled = false;
        document.getElementById('map').style.cursor = '';

        updateChangesUI();
        drawEdges();

        showToast('已清空所有变更');
    };
    
    // 简单的 SHA-256 哈希函数（用于生成持久 ID）
    async function sha256(message) {
        const msgBuffer = new TextEncoder().encode(message);
        const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
        const hashArray = Array.from(new Uint8Array(hashBuffer));
        return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    }

    // 导出 Patch
    window.exportPatch = async function() {
        if (pendingChanges.size === 0 && pendingNewEdges.size === 0) {
            showToast('没有变更需要导出');
            return;
        }

        const operations = [];

        // 处理现有边的修改
        pendingChanges.forEach((change, id) => {
            if (change.flipped) {
                operations.push({
                    op: 'flip_edge',
                    src_feat_id: change.edge.src_feat_id,
                    src_sub_id: change.edge.src_sub_id
                });
            }

            if (change.updates.is_enabled !== undefined) {
                operations.push({
                    op: 'set_edge_enabled',
                    src_feat_id: change.edge.src_feat_id,
                    src_sub_id: change.edge.src_sub_id,
                    is_enabled: change.updates.is_enabled
                });
            }

            const otherUpdates = {...change.updates};
            delete otherUpdates.is_enabled;
            if (Object.keys(otherUpdates).length > 0) {
                operations.push({
                    op: 'update_edge',
                    src_feat_id: change.edge.src_feat_id,
                    src_sub_id: change.edge.src_sub_id,
                    changes: otherUpdates
                });
            }
        });

        // 处理新增边
        for (const [tempId, newEdge] of pendingNewEdges) {
            // 生成持久的 src_feat_id
            let src_feat_id;
            if (newEdge.osm_id) {
                // 基于 OSM ID 生成
                src_feat_id = (await sha256('osm:' + newEdge.osm_id)).substring(0, 40);
            } else {
                // 基于几何和时间戳生成
                src_feat_id = (await sha256('manual:' + newEdge.geom + ':' + newEdge.created_at)).substring(0, 40);
            }

            operations.push({
                op: 'add_manual_edge',
                src_feat_id: src_feat_id,
                src_sub_id: 0,
                osm_id: newEdge.osm_id || null,
                src_feat_type: newEdge.src_feat_type,
                from_node: newEdge.from_node,
                to_node: newEdge.to_node,
                name: newEdge.name,
                difficulty: newEdge.difficulty || '',
                oneway: newEdge.oneway,
                geom: newEdge.geom,
                lift_type: newEdge.lift_type || null,
                duration: newEdge.duration || null,
                occupancy: newEdge.occupancy || null
            });
        }

        const patch = {
            version: '1.0',
            created_at: new Date().toISOString(),
            source_hashes: sourceHashes,
            operations: operations,
            stats: {
                total: operations.length,
                flip: operations.filter(o => o.op === 'flip_edge').length,
                update: operations.filter(o => o.op === 'update_edge').length,
                enable: operations.filter(o => o.op === 'set_edge_enabled').length,
                add: operations.filter(o => o.op === 'add_manual_edge').length
            }
        };

        const blob = new Blob([JSON.stringify(patch, null, 2)], {type: 'application/json'});
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'patch.json';
        a.click();
        URL.revokeObjectURL(url);

        showToast('已导出 patch.json (' + operations.length + ' 个操作)');
    };
    
    // 渲染任务列表
    window.renderTasks = function() {
        const showDir = document.getElementById('filter-direction').checked;
        const showDiff = document.getElementById('filter-difficulty').checked;
        
        const filtered = reviewTasks.filter(t => {
            if (t.task_type === 'check_direction' && showDir) return true;
            if (t.task_type === 'missing_difficulty' && showDiff) return true;
            return false;
        });
        
        document.getElementById('task-count').textContent = filtered.length;
        
        const list = document.getElementById('task-list');
        list.innerHTML = filtered.slice(0, 30).map(t => `
            <div class="task-item ${t.priority}" onclick="locateTask(${t.edge_id})">
                <strong>${t.task_type === 'check_direction' ? '方向确认' : '缺少难度'}</strong>
                <div>${t.description}</div>
            </div>
        `).join('');
    };
    
    // 定位任务
    window.locateTask = function(edgeId) {
        const edge = graphData.edges.find(e => e.edge_id === edgeId);
        const line = polylines[edgeId];
        if (edge && line) {
            const coords = parseWKT(edge.geom);
            if (coords.length > 0) {
                map.setView(coords[Math.floor(coords.length/2)], 16);
                selectEdge(edge, line);
            }
        }
    };
    
    // ============================================
    // 绘制模式相关函数
    // ============================================

    // 找到最近的节点
    function findNearestNode(latlng, toleranceMeters = 30) {
        let nearest = null;
        let minDist = toleranceMeters;

        for (const node of graphData.nodes) {
            const dist = map.distance(latlng, [node.lat, node.lon]);
            if (dist < minDist) {
                minDist = dist;
                nearest = node;
            }
        }
        return nearest;
    }

    // 开始绘制模式
    window.startDrawEdge = function(type) {
        // 清除之前的选中状态
        clearSelection();

        drawMode = type;
        drawnPoints = [];
        selectedFromNode = null;
        selectedToNode = null;

        // 更新 UI
        document.getElementById('placeholder').style.display = 'none';
        document.getElementById('edge-form').style.display = 'none';
        document.getElementById('node-info').style.display = 'none';
        document.getElementById('new-edge-form').style.display = 'none';

        document.getElementById('draw-mode-hint').style.display = 'block';
        document.getElementById('draw-mode-status').textContent = type === 'run' ? '绘制雪道' : '绘制缆车';
        document.getElementById('draw-mode-tip').textContent = '点击地图选择起点节点（或在空白处双击创建新节点）';

        // 更新按钮状态
        document.getElementById('btn-add-run').disabled = true;
        document.getElementById('btn-add-lift').disabled = true;

        // 更改鼠标样式
        document.getElementById('map').style.cursor = 'crosshair';

        showToast('已进入绘制模式，点击选择起点');
    };

    // 取消绘制模式
    window.cancelDrawMode = function() {
        drawMode = null;
        drawnPoints = [];
        selectedFromNode = null;
        selectedToNode = null;

        // 清除绘制图层
        drawLayer.clearLayers();

        // 恢复 UI
        document.getElementById('draw-mode-hint').style.display = 'none';
        document.getElementById('new-edge-form').style.display = 'none';
        document.getElementById('placeholder').style.display = 'block';

        // 恢复按钮
        document.getElementById('btn-add-run').disabled = false;
        document.getElementById('btn-add-lift').disabled = false;

        // 恢复鼠标样式
        document.getElementById('map').style.cursor = '';

        showToast('已取消绘制');
    };

    // 更新绘制中的折线
    function updateDrawingLine() {
        if (drawingLine) {
            drawLayer.removeLayer(drawingLine);
        }
        if (drawnPoints.length >= 1) {
            const color = drawMode === 'lift' ? '#8b5cf6' : '#22c55e';
            drawingLine = L.polyline(drawnPoints, {
                color: color,
                weight: 4,
                dashArray: '5,5',
                opacity: 0.8
            }).addTo(drawLayer);
        }
    }

    // 显示新增 edge 表单
    function showNewEdgeForm() {
        document.getElementById('draw-mode-hint').style.display = 'none';
        document.getElementById('new-edge-form').style.display = 'block';

        // 根据类型显示对应字段
        const isLift = drawMode === 'lift';
        document.getElementById('new-run-fields').style.display = isLift ? 'none' : 'block';
        document.getElementById('new-lift-fields').style.display = isLift ? 'block' : 'none';

        // 设置节点信息
        document.getElementById('new-from').value = 'Node ' + selectedFromNode.node_id;
        document.getElementById('new-to').value = 'Node ' + selectedToNode.node_id;

        // 清空表单
        document.getElementById('new-osm-id').value = '';
        document.getElementById('new-name').value = '';
        document.getElementById('new-difficulty').value = '';
        document.getElementById('new-oneway').checked = true;
        document.getElementById('new-lift-type').value = 'chair_lift';
        document.getElementById('new-occupancy').value = '';
        document.getElementById('new-duration').value = '';
    }

    // 确认添加新边
    window.confirmNewEdge = function() {
        if (!selectedFromNode || !selectedToNode || drawnPoints.length < 2) {
            showToast('请先完成绘制');
            return;
        }

        const isLift = drawMode === 'lift';

        // 构建 WKT
        const wktCoords = drawnPoints.map(p => `${p[1]} ${p[0]}`).join(', ');
        const geom = `LINESTRING(${wktCoords})`;

        // 创建新边数据
        const tempId = 'new_' + (++newEdgeTempId);
        const newEdge = {
            temp_id: tempId,
            src_feat_type: isLift ? 'lift' : 'run',
            osm_id: document.getElementById('new-osm-id').value.trim() || null,
            name: document.getElementById('new-name').value.trim(),
            difficulty: isLift ? '' : document.getElementById('new-difficulty').value,
            oneway: document.getElementById('new-oneway').checked,
            from_node: selectedFromNode.node_id,
            to_node: selectedToNode.node_id,
            geom: geom,
            created_at: new Date().toISOString(),
            lift_type: isLift ? document.getElementById('new-lift-type').value : null,
            duration: isLift ? (parseInt(document.getElementById('new-duration').value) || null) : null,
            occupancy: isLift ? (parseInt(document.getElementById('new-occupancy').value) || null) : null
        };

        // 保存到待处理列表
        pendingNewEdges.set(tempId, newEdge);

        // 在地图上绘制新边（实线）
        const color = isLift ? '#8b5cf6' : (colors[newEdge.difficulty] || '#22c55e');
        L.polyline(drawnPoints, {
            color: color,
            weight: 4,
            opacity: 0.9
        }).addTo(newEdgeLayer);

        // 更新变更 UI
        updateChangesUI();

        // 清除绘制状态
        drawLayer.clearLayers();
        drawMode = null;
        drawnPoints = [];
        selectedFromNode = null;
        selectedToNode = null;

        // 恢复 UI
        document.getElementById('new-edge-form').style.display = 'none';
        document.getElementById('placeholder').style.display = 'block';
        document.getElementById('btn-add-run').disabled = false;
        document.getElementById('btn-add-lift').disabled = false;
        document.getElementById('map').style.cursor = '';

        showToast('已添加新' + (isLift ? '缆车' : '雪道') + '，记得导出 Patch');
    };

    // 地图点击事件处理（绘制模式）
    map.on('click', function(e) {
        if (!drawMode) return;

        const latlng = e.latlng;
        const nearNode = findNearestNode(latlng, 30);

        if (!selectedFromNode) {
            // 选择起点
            if (nearNode) {
                selectedFromNode = nearNode;
                drawnPoints.push([nearNode.lat, nearNode.lon]);

                // 高亮起点
                L.circleMarker([nearNode.lat, nearNode.lon], {
                    radius: 8,
                    fillColor: '#22c55e',
                    color: '#fff',
                    weight: 3,
                    fillOpacity: 1
                }).addTo(drawLayer);

                document.getElementById('draw-mode-tip').textContent = '继续点击添加路径点，点击节点完成';
                showToast('起点已选择 (Node ' + nearNode.node_id + ')');
            } else {
                showToast('请点击已有节点作为起点');
            }
        } else if (!selectedToNode) {
            // 添加中间点或选择终点
            if (nearNode && nearNode.node_id !== selectedFromNode.node_id) {
                // 选择为终点
                selectedToNode = nearNode;
                drawnPoints.push([nearNode.lat, nearNode.lon]);

                // 高亮终点
                L.circleMarker([nearNode.lat, nearNode.lon], {
                    radius: 8,
                    fillColor: '#ef4444',
                    color: '#fff',
                    weight: 3,
                    fillOpacity: 1
                }).addTo(drawLayer);

                updateDrawingLine();
                showNewEdgeForm();
                showToast('终点已选择，请填写属性');
            } else {
                // 添加中间点
                drawnPoints.push([latlng.lat, latlng.lng]);

                // 添加中间点标记
                L.circleMarker([latlng.lat, latlng.lng], {
                    radius: 4,
                    fillColor: '#f59e0b',
                    color: '#fff',
                    weight: 2,
                    fillOpacity: 0.8
                }).addTo(drawLayer);

                updateDrawingLine();
            }
        }
    });

    // Toast
    function showToast(msg) {
        const t = document.getElementById('toast');
        t.textContent = msg;
        t.classList.add('show');
        setTimeout(() => t.classList.remove('show'), 2500);
    }

    // 显示控制
    document.getElementById('show-runs').onchange = e => e.target.checked ? map.addLayer(runLayer) : map.removeLayer(runLayer);
    document.getElementById('show-lifts').onchange = e => e.target.checked ? map.addLayer(liftLayer) : map.removeLayer(liftLayer);
    document.getElementById('show-nodes').onchange = e => e.target.checked ? map.addLayer(nodeLayer) : map.removeLayer(nodeLayer);
    document.getElementById('show-arrows').onchange = e => e.target.checked ? map.addLayer(arrowLayer) : map.removeLayer(arrowLayer);
    
    // 初始化
    drawEdges();
    drawNodes();
    renderTasks();
    updateChangesUI();
});
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
        pass
    
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
    
    # 加载 meta
    meta = {}
    for row in cur.execute('SELECT key, value FROM meta'):
        meta[row[0]] = row[1]
    
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
        'center': {'lon': center_lon, 'lat': center_lat},
        'meta': meta
    }


def main():
    parser = argparse.ArgumentParser(description='生成图数据 HTML 编辑器')
    parser.add_argument('db', help='ski_graph.sqlite 文件')
    parser.add_argument('-o', '--output', default='editor.html', help='输出 HTML 文件')
    parser.add_argument('-t', '--tasks', default='review_tasks.json', help='审核任务 JSON')
    
    args = parser.parse_args()
    
    print(f"加载 {args.db}...")
    graph_data = load_graph_data(args.db)
    
    source_hashes = {
        'runs': graph_data['meta'].get('runs_hash', ''),
        'lifts': graph_data['meta'].get('lifts_hash', '')
    }
    
    del graph_data['meta']
    
    print(f"加载 {args.tasks}...")
    try:
        with open(args.tasks, 'r', encoding='utf-8') as f:
            review_tasks = json.load(f)
    except FileNotFoundError:
        review_tasks = []
    
    print(f"生成 {args.output}...")
    html = HTML_TEMPLATE.replace('__GRAPH_DATA__', json.dumps(graph_data, ensure_ascii=False))
    html = html.replace('__REVIEW_TASKS__', json.dumps(review_tasks, ensure_ascii=False))
    html = html.replace('__SOURCE_HASHES__', json.dumps(source_hashes, ensure_ascii=False))
    
    with open(args.output, 'w', encoding='utf-8') as f:
        f.write(html)
    
    print("完成!")
    print(f"  - 节点: {len(graph_data['nodes'])}")
    print(f"  - 边: {len(graph_data['edges'])}")
    print(f"  - 审核任务: {len(review_tasks)}")


if __name__ == '__main__':
    main()
