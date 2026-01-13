# SnowNavi 滑雪导航离线图包工具链

## 📁 文件清单

| 文件 | 功能 |
|------|------|
| `ski_graph_preprocess.py` | 预处理：GeoJSON → SQLite |
| `generate_editor.py` | 生成 HTML 可视化编辑器（推荐）|
| `generate_preview.py` | 生成 HTML 只读预览 |
| `export_geojson.py` | SQLite → GeoJSON（供 QGIS 编辑）|
| `import_geojson.py` | GeoJSON → SQLite（导入编辑结果）|
| `diff_patch.py` | 对比两个 SQLite，生成 patch.json |
| `apply_patch.py` | 将 patch.json 应用到 SQLite |

---

## 🔄 完整工作流

```
┌─────────────────────────────────────────────────────────────────┐
│                         数据处理流程                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   runs.geojson + lifts.geojson                                  │
│              │                                                  │
│              ▼                                                  │
│   ┌──────────────────────┐                                      │
│   │ ski_graph_preprocess │  Step 1: 预处理                       │
│   └──────────────────────┘                                      │
│              │                                                  │
│              ▼                                                  │
│   ski_graph.sqlite + review_tasks.json                          │
│              │                                                  │
│              ▼                                                  │
│   ┌──────────────────────┐                                      │
│   │   generate_editor    │  Step 2: 生成编辑器                    │
│   └──────────────────────┘                                      │
│              │                                                  │
│              ▼                                                  │
│        editor.html ─────────────────────────────┐               │
│              │                                  │               │
│              ▼                                  ▼               │
│   ┌──────────────────────┐          ┌──────────────────┐        │
│   │  浏览器中编辑数据      │          │  点击导出 Patch   │        │
│   │  - 修改名称/难度       │   ──→    │                  │        │
│   │  - 翻转方向           │          └──────────────────┘        │
│   │  - 启用/禁用边        │                   │                  │
│   └──────────────────────┘                   ▼                  │
│                                         patch.json              │
│                                              │                  │
│   ┌──────────────────────────────────────────┘                  │
│   │                                                             │
│   │  (当源数据更新时)                                             │
│   │                                                             │
│   ▼                                                             │
│   ski_graph_new.sqlite (重新预处理)                               │
│              │                                                  │
│              ▼                                                  │
│   ┌──────────────────────┐                                      │
│   │    apply_patch       │  Step 3: 应用 patch                   │
│   └──────────────────────┘                                      │
│              │                                                  │
│              ▼                                                  │
│   ski_graph_final.sqlite ──────→ 发布到 App                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📖 使用指南

### Step 1: 预处理 GeoJSON

```bash
python ski_graph_preprocess.py runs.geojson lifts.geojson \
    -o ski_graph.sqlite \
    -r review_tasks.json \
    --eps 5.0
```

**参数说明：**
- `--eps`: 端点聚类半径（米），默认 5.0
- `-o`: 输出 SQLite 文件
- `-r`: 输出审核任务文件

**输出：**
- `ski_graph.sqlite`: 图数据库
- `review_tasks.json`: 需要人工审核的问题列表

---

### Step 2: 使用 HTML 编辑器（推荐）

```bash
python generate_editor.py ski_graph.sqlite -o editor.html -t review_tasks.json
```

在浏览器中打开 `editor.html`，可以：

| 功能 | 操作 |
|------|------|
| **选中边** | 点击地图上的雪道或缆车 |
| **修改名称** | 在右侧面板输入新名称 |
| **修改难度** | 从下拉菜单选择难度等级 |
| **翻转方向** | 点击「🔄 翻转方向」按钮 |
| **启用/禁用** | 勾选或取消「启用此边」 |
| **保存修改** | 点击「💾 保存修改」按钮 |
| **导出 Patch** | 点击「📤 导出 Patch」下载 patch.json |
| **定位问题** | 点击右侧待审核列表中的任务 |

**节点功能：**
- 点击节点查看详情
- 橙色节点表示聚合了多个原始端点
- 点击聚合节点会显示原始点位置和来源

---

### Step 2 备选: 只读预览

```bash
python generate_preview.py ski_graph.sqlite -o preview.html
```

---

### Step 3: 应用 Patch

```bash
# 重新生成基础数据（当源 GeoJSON 更新时）
python ski_graph_preprocess.py runs.geojson lifts.geojson -o ski_graph_new.sqlite

# 应用 patch
python apply_patch.py ski_graph_new.sqlite patch.json \
    -o ski_graph_final.sqlite
```

**注意：** 如果源数据 hash 不匹配，需要使用 `--force` 强制应用。

---

## 🎨 QGIS 配置建议

### 按难度着色

在 QGIS 中设置分类样式：

| difficulty | 颜色 |
|------------|------|
| novice | #22c55e (绿) |
| easy | #3b82f6 (蓝) |
| intermediate | #ef4444 (红) |
| advanced | #111827 (黑) |
| (空/unknown) | #9ca3af (灰) |

### 显示方向箭头

1. 图层属性 → 符号
2. 选择 "箭头" 符号
3. 勾选 "仅显示末端"

### 快捷筛选

创建筛选器：
- 缺少名称: `"name" = '' OR "name" IS NULL`
- 未启用: `"is_enabled" = false`
- 高难度: `"difficulty" = 'advanced'`

---

## 📊 数据结构

### SQLite 表结构

**meta 表：**
| 字段 | 说明 |
|------|------|
| key | 键名 |
| value | 值 |

**nodes 表：**
| 字段 | 类型 | 说明 |
|------|------|------|
| node_id | INTEGER | 节点 ID |
| lon | REAL | 经度 |
| lat | REAL | 纬度 |
| kind | TEXT | 类型: junction, lift_station |
| comment | TEXT | 备注 |

**edges 表：**
| 字段 | 类型 | 说明 |
|------|------|------|
| edge_id | INTEGER | 边 ID |
| src_feat_type | TEXT | 源类型: run, lift |
| src_feat_id | TEXT | 源 feature ID |
| src_sub_id | INTEGER | 切分段号 |
| name | TEXT | 名称 |
| uses | TEXT | 用途 |
| difficulty | TEXT | 难度 |
| status | TEXT | 状态 |
| oneway | INTEGER | 是否单向 |
| from_node | INTEGER | 起点节点 |
| to_node | INTEGER | 终点节点 |
| length_m | REAL | 长度（米）|
| geom | TEXT | WKT 几何 |
| is_enabled | INTEGER | 是否启用 |
| cost | REAL | 路由代价 |
| note | TEXT | 备注 |

---

## ⚠️ 常见问题

### Q: 端点没有正确连接？
A: 调整 `--eps` 参数增大聚类半径，或在 QGIS 中手动添加连接。

### Q: 雪道方向错误？
A: 在 QGIS 中交换 `from_node` 和 `to_node`，或使用 `flip_edge` patch 操作。

### Q: 如何禁用某条边？
A: 将 `is_enabled` 设为 0。

### Q: Patch 应用失败？
A: 检查源数据 hash 是否匹配，必要时使用 `--force`。

---

## 🔧 依赖

- Python 3.8+
- 无外部依赖（仅使用标准库）

可选：
- QGIS 3.x（用于可视化编辑）
