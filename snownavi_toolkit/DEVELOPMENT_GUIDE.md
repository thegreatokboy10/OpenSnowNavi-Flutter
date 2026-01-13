# SnowNavi 滑雪导航离线数据包开发指南

> 版本: 1.0  
> 更新日期: 2026-01-08  
> 项目目标: 构建基于图结构的滑雪场离线导航系统

---

## 一、项目概述

### 1.1 系统架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        数据流程图                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [OpenSkiMap]     [实地测绘]                                     │
│       │               │                                         │
│       ▼               ▼                                         │
│  ┌─────────┐    ┌─────────┐                                     │
│  │runs.    │    │lifts.   │    GeoJSON 源数据                    │
│  │geojson  │    │geojson  │                                     │
│  └────┬────┘    └────┬────┘                                     │
│       │              │                                          │
│       └──────┬───────┘                                          │
│              ▼                                                  │
│  ┌───────────────────────┐                                      │
│  │ ski_graph_preprocess  │  预处理脚本                           │
│  │  - 端点聚类           │                                      │
│  │  - 交叉检测           │                                      │
│  │  - 图构建             │                                      │
│  └───────────┬───────────┘                                      │
│              ▼                                                  │
│  ┌───────────────────────┐                                      │
│  │   ski_graph.sqlite    │  离线图数据库                         │
│  └───────────┬───────────┘                                      │
│              │                                                  │
│      ┌───────┴───────┐                                          │
│      ▼               ▼                                          │
│  ┌────────┐    ┌──────────┐                                     │
│  │Editor  │    │ 导航引擎  │                                     │
│  │(人工   │    │(路径规划) │  ← 待开发                            │
│  │ 审核)  │    └──────────┘                                     │
│  └───┬────┘                                                     │
│      ▼                                                          │
│  ┌─────────┐                                                    │
│  │patch.   │    修改补丁                                         │
│  │json     │                                                    │
│  └────┬────┘                                                    │
│       ▼                                                          │
│  ┌───────────────────────┐                                      │
│  │    apply_patch        │  应用补丁                             │
│  └───────────────────────┘                                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| 数据存储 | SQLite | 离线图数据库 |
| 数据处理 | Python 3 | 预处理、补丁应用 |
| 可视化编辑 | HTML/JS + Leaflet | 浏览器端编辑器 |
| 导航引擎 | 待定 | Dijkstra/A* 路径规划 |
| 移动端 | 待定 | iOS/Android 客户端 |

---

## 二、开发进度

### 2.1 ✅ 已完成功能

#### 数据预处理 (`ski_graph_preprocess.py`)
- [x] GeoJSON 解析和校验
- [x] DBSCAN 端点聚类（自动合并相近节点）
- [x] Run-Run 交叉检测（在交叉点切分雪道）
- [x] 图结构构建（nodes + edges）
- [x] 缆车类型识别和方向默认值
- [x] 源数据 hash 记录（用于版本追踪）
- [x] 审核任务自动生成

#### 可视化工具
- [x] `generate_preview.py` - 只读预览 HTML
- [x] `generate_editor.py` - 可编辑 HTML 编辑器
  - 雪道属性编辑（名称、难度）
  - 缆车属性编辑（类型、载客量、运行时长）
  - 方向翻转
  - 单向/双向切换
  - 启用/禁用
  - 节点聚合来源显示
  - 变更追踪和 Patch 导出

#### 补丁系统
- [x] `diff_patch.py` - 从 GeoJSON 对比生成补丁
- [x] `apply_patch.py` - 应用补丁到 SQLite
- [x] 支持的操作类型:
  - `flip_edge` - 翻转边方向
  - `update_edge` - 更新边属性
  - `set_edge_enabled` - 设置启用状态
  - `add_manual_node` - 添加手动节点
  - `add_manual_edge` - 添加手动边

#### QGIS 兼容（备选方案）
- [x] `export_geojson.py` - 导出为 QGIS 可编辑格式
- [x] `import_geojson.py` - 从 QGIS 导入修改

### 2.2 🚧 待完成功能

#### 数据质量
- [ ] 雪道方向自动推断（基于海拔数据）
- [ ] 孤立节点检测
- [ ] 图连通性验证
- [ ] 缺失数据自动填充

#### 导航引擎（核心待开发）
- [ ] 基础路径规划算法
- [ ] 多目标优化（难度偏好、时间最短、体力消耗）
- [ ] 实时位置匹配
- [ ] 离线地图渲染

#### 移动端
- [ ] iOS/Android 客户端
- [ ] 离线数据包分发
- [ ] GPS 定位集成

---

## 三、数据库结构详解

### 3.1 SQLite 文件结构

```
ski_graph.sqlite
├── meta          # 元数据键值对
├── nodes         # 图节点（路口、缆车站）
├── node_sources  # 节点聚合来源记录
└── edges         # 图边（雪道、缆车）
```

### 3.2 表结构定义

#### `meta` - 元数据表

| 字段 | 类型 | 说明 |
|------|------|------|
| `key` | TEXT PK | 键名 |
| `value` | TEXT | 值 |

**标准键值:**
```
version       = "1.0"
runs_hash     = "7a94129d55c6e6561b54337a7a95f564"  # 源数据 MD5
lifts_hash    = "3d8c0b8fd6809a7e0646cd15b09dcd7a"
node_count    = "141"
edge_count    = "114"
patch_applied = "2026-01-08T10:30:00Z"  # 最后应用的补丁时间
```

#### `nodes` - 节点表

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| `node_id` | INTEGER | PRIMARY KEY | 节点唯一标识 |
| `lon` | REAL | NOT NULL | 经度 (WGS84) |
| `lat` | REAL | NOT NULL | 纬度 (WGS84) |
| `kind` | TEXT | | 节点类型 |
| `comment` | TEXT | | 备注 |

**`kind` 枚举值:**
- `junction` - 普通路口（雪道交汇点）
- `lift_station` - 缆车站（上/下站）
- `manual` - 手动添加的节点

#### `node_sources` - 节点聚合来源表

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK | 自增主键 |
| `node_id` | INTEGER FK | 关联的节点 ID |
| `lon` | REAL | 原始点经度 |
| `lat` | REAL | 原始点纬度 |
| `source_type` | TEXT | 来源类型 (`run`/`lift`) |
| `feat_id` | TEXT | 原始 feature ID |
| `feat_name` | TEXT | 原始 feature 名称 |

**用途:** 记录哪些原始端点被聚合到同一个节点，便于调试和溯源。

#### `edges` - 边表

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `edge_id` | INTEGER PK | | 边唯一标识 |
| `src_feat_type` | TEXT | | 来源类型: `run` / `lift` |
| `src_feat_id` | TEXT | | 原始 feature ID (用于补丁定位) |
| `src_sub_id` | INTEGER | | 切分段序号 (0=未切分) |
| `name` | TEXT | | 名称 |
| `uses` | TEXT | | 用途: `downhill`/`nordic`/`lift` |
| `difficulty` | TEXT | | 难度级别 (仅雪道) |
| `status` | TEXT | | 运营状态 |
| `oneway` | INTEGER | | 是否单向: 0=双向, 1=单向 |
| `from_node` | INTEGER FK | | 起点节点 ID |
| `to_node` | INTEGER FK | | 终点节点 ID |
| `length_m` | REAL | | 长度（米）|
| `geom` | TEXT | | WKT LINESTRING 几何 |
| `is_enabled` | INTEGER | 1 | 是否启用: 0=禁用, 1=启用 |
| `cost` | REAL | | 路径规划代价 |
| `note` | TEXT | | 备注 |
| `lift_type` | TEXT | | 缆车类型 (仅缆车) |
| `duration` | INTEGER | | 运行时长秒数 (仅缆车) |
| `occupancy` | INTEGER | | 载客量 (仅缆车) |

**`difficulty` 枚举值 (北美标准):**
- `novice` - 初学者 (绿色)
- `easy` - 简单 (蓝色)
- `intermediate` - 中级 (红色)
- `advanced` - 高级 (黑色)
- `expert` - 专家 (双黑)
- `unknown` - 未知

**`lift_type` 枚举值:**
- `gondola` - 厢式缆车 (默认双向)
- `chair_lift` - 吊椅缆车 (默认单向)
- `drag_lift` - 拖牵 (默认单向)
- `t-bar` - T型吊杆 (默认单向)
- `cable_car` - 大型缆车 (默认双向)
- `funicular` - 缆索铁路 (默认双向)
- `magic_carpet` - 魔毯 (默认单向)

**`status` 枚举值:**
- `operating` - 运营中
- `closed` - 已关闭
- `planned` - 规划中

### 3.3 索引

```sql
CREATE INDEX idx_edges_from ON edges(from_node);
CREATE INDEX idx_edges_to ON edges(to_node);
CREATE INDEX idx_edges_src ON edges(src_feat_id, src_sub_id);
CREATE INDEX idx_node_sources ON node_sources(node_id);
```

### 3.4 几何格式

**WKT LINESTRING 示例:**
```
LINESTRING(126.6501526 43.4103078, 126.6491187 43.4106298, 126.6484535 43.4109123)
```
- 坐标格式: `经度 纬度`
- 坐标系: WGS84 (EPSG:4326)
- 顺序: 从 `from_node` 到 `to_node`

---

## 四、导航引擎开发指南

### 4.1 图结构特点

```
滑雪场图 = 有向加权图 G(V, E)

V = nodes (路口 + 缆车站)
E = edges (雪道 + 缆车)

特点:
1. 雪道大多单向（下山方向）
2. 缆车连接不同海拔区域
3. 需要考虑难度约束
4. 可能存在多个连通分量
```

### 4.2 路径规划算法建议

#### 基础: Dijkstra 最短路径
```python
def dijkstra(graph, start, end, cost_func):
    """
    graph: 图结构
    start: 起点 node_id
    end: 终点 node_id
    cost_func: 代价函数 f(edge) -> float
    """
    # 标准 Dijkstra 实现
    pass
```

#### 进阶: 多目标优化
```python
def plan_route(graph, start, end, preferences):
    """
    preferences = {
        'max_difficulty': 'intermediate',  # 最大接受难度
        'prefer_lifts': True,              # 偏好使用缆车
        'avoid_crowded': True,             # 避开拥挤
        'minimize': 'time' | 'distance' | 'difficulty'
    }
    """
    pass
```

### 4.3 代价函数设计

```python
def calculate_edge_cost(edge, preferences):
    """计算边的路径规划代价"""
    
    if edge['src_feat_type'] == 'lift':
        # 缆车代价 = 等待时间 + 运行时间
        base_cost = edge['duration'] or estimate_lift_time(edge['length_m'])
        
    else:
        # 雪道代价 = 滑行时间（基于长度和难度）
        speed = get_speed_by_difficulty(edge['difficulty'], preferences['skill_level'])
        base_cost = edge['length_m'] / speed
    
    # 难度惩罚
    if difficulty_level(edge['difficulty']) > difficulty_level(preferences['max_difficulty']):
        return float('inf')  # 不可通行
    
    return base_cost
```

### 4.4 实时位置匹配

```python
def match_position(graph, gps_lon, gps_lat, heading=None):
    """
    将 GPS 位置匹配到图上最近的边
    
    Returns:
        {
            'edge_id': 123,
            'position': 0.35,  # 在边上的相对位置 [0, 1]
            'distance': 5.2,   # 匹配距离（米）
            'confidence': 0.92
        }
    """
    pass
```

### 4.5 数据加载示例

```python
import sqlite3

def load_graph(db_path):
    """加载图数据用于路径规划"""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    
    # 构建邻接表
    adjacency = {}  # node_id -> [(edge_id, to_node, cost), ...]
    
    for row in cur.execute('''
        SELECT edge_id, from_node, to_node, length_m, cost, 
               oneway, difficulty, src_feat_type, lift_type, duration
        FROM edges 
        WHERE is_enabled = 1
    '''):
        edge = dict(row)
        from_n = edge['from_node']
        to_n = edge['to_node']
        
        # 添加正向边
        if from_n not in adjacency:
            adjacency[from_n] = []
        adjacency[from_n].append((edge['edge_id'], to_n, edge))
        
        # 如果双向，添加反向边
        if not edge['oneway']:
            if to_n not in adjacency:
                adjacency[to_n] = []
            adjacency[to_n].append((edge['edge_id'], from_n, edge))
    
    # 加载节点坐标
    nodes = {}
    for row in cur.execute('SELECT node_id, lon, lat FROM nodes'):
        nodes[row['node_id']] = (row['lon'], row['lat'])
    
    conn.close()
    
    return {
        'adjacency': adjacency,
        'nodes': nodes
    }
```

---

## 五、工具使用手册

### 5.1 完整工作流程

```bash
# 1. 预处理源数据
python ski_graph_preprocess.py runs.geojson lifts.geojson \
    -o ski_graph.sqlite \
    -r review_tasks.json

# 2. 生成编辑器
python generate_editor.py ski_graph.sqlite \
    -o editor.html \
    -t review_tasks.json

# 3. 在浏览器中打开 editor.html 进行人工审核
#    - 检查方向
#    - 补充缺失信息
#    - 禁用错误数据
#    - 导出 patch.json

# 4. 应用补丁
python apply_patch.py ski_graph.sqlite patch.json \
    -o ski_graph_final.sqlite

# 5. 验证最终数据
python generate_preview.py ski_graph_final.sqlite -o preview.html
```

### 5.2 脚本参数说明

#### `ski_graph_preprocess.py`
```
用法: python ski_graph_preprocess.py <runs.geojson> <lifts.geojson> [选项]

选项:
  -o, --output FILE    输出 SQLite 文件 (默认: ski_graph.sqlite)
  -r, --review FILE    审核任务输出 JSON (默认: review_tasks.json)
  --cluster-eps FLOAT  聚类半径（米）(默认: 15)
```

#### `generate_editor.py`
```
用法: python generate_editor.py <ski_graph.sqlite> [选项]

选项:
  -o, --output FILE    输出 HTML 文件 (默认: editor.html)
  -t, --tasks FILE     审核任务 JSON (默认: review_tasks.json)
```

#### `apply_patch.py`
```
用法: python apply_patch.py <ski_graph.sqlite> <patch.json> [选项]

选项:
  -o, --output FILE    输出文件 (默认: 覆盖原文件)
  --force              忽略 hash 不匹配警告
```

---

## 六、补丁文件格式

### 6.1 patch.json 结构

```json
{
  "version": "1.0",
  "created_at": "2026-01-08T10:30:00.000Z",
  "source_hashes": {
    "runs": "7a94129d55c6e6561b54337a7a95f564",
    "lifts": "3d8c0b8fd6809a7e0646cd15b09dcd7a"
  },
  "operations": [
    {
      "op": "flip_edge",
      "src_feat_id": "abc123...",
      "src_sub_id": 0
    },
    {
      "op": "update_edge",
      "src_feat_id": "def456...",
      "src_sub_id": 0,
      "changes": {
        "name": "雪道A",
        "difficulty": "intermediate",
        "oneway": true
      }
    },
    {
      "op": "set_edge_enabled",
      "src_feat_id": "ghi789...",
      "src_sub_id": 0,
      "is_enabled": false
    }
  ],
  "stats": {
    "total": 3,
    "flip": 1,
    "update": 1,
    "enable": 1
  }
}
```

### 6.2 操作类型详解

| 操作 | 说明 | 必需参数 |
|------|------|----------|
| `flip_edge` | 翻转边方向 | src_feat_id, src_sub_id |
| `update_edge` | 更新属性 | src_feat_id, src_sub_id, changes |
| `set_edge_enabled` | 启用/禁用 | src_feat_id, src_sub_id, is_enabled |
| `add_manual_node` | 添加节点 | node_id, lon, lat, kind |
| `add_manual_edge` | 添加边 | from_node, to_node, name, difficulty, geom |

---

## 七、后续开发路线图

### Phase 1: 数据质量 (1-2周)
- [ ] 集成 DEM 高程数据，自动推断雪道方向
- [ ] 实现图连通性检查
- [ ] 添加数据完整性报告

### Phase 2: 导航引擎核心 (2-4周)
- [ ] 实现基础 Dijkstra 路径规划
- [ ] 添加难度约束支持
- [ ] 实现多目标优化（时间/距离/难度）
- [ ] GPS 位置匹配算法

### Phase 3: 移动端集成 (4-8周)
- [ ] 设计离线数据包格式
- [ ] 实现地图瓦片渲染
- [ ] iOS/Android SDK 封装
- [ ] 实时导航 UI

### Phase 4: 高级功能 (持续迭代)
- [ ] 多雪场支持
- [ ] 用户偏好学习
- [ ] 拥挤度预测
- [ ] 社交功能（好友位置）

---

## 八、测试数据

### 北大湖滑雪场 (beidahu)
- 节点: 141
- 边: 114 (雪道: 99, 缆车: 15)
- 缆车类型: gondola(8), chair_lift(7)
- 雪道难度分布: novice(3), easy(8), intermediate(44), advanced(9), unknown(35)

### 数据文件
```
/data/beidahu/
├── runs.geojson          # 雪道源数据
├── lifts.geojson         # 缆车源数据
├── ski_graph.sqlite      # 处理后的图数据库
├── review_tasks.json     # 待审核任务
└── patch.json            # 人工修正补丁
```

---

## 九、联系方式

如有问题，请联系项目负责人。

---

*文档结束*
