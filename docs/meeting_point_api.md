# 集合点 API 文档

## 基础 URL
```
https://snownavi.ski
```

## API 端点

### 1. 获取团队所有集合点

**请求**
```
GET /api/team/{teamId}/meeting-points
```

**响应 (200)**
```json
{
  "meetingPoints": [
    {
      "id": "mp_123456",
      "teamId": "team_abc",
      "name": "山顶餐厅",
      "latitude": 45.123456,
      "longitude": 6.789012,
      "createdBy": "device_001",
      "creatorNickname": "张三",
      "createdAt": "2024-01-15T10:30:00Z",
      "isActive": true
    }
  ]
}
```

---

### 2. 添加集合点

**请求**
```
POST /api/team/{teamId}/meeting-points
Content-Type: application/json

{
  "name": "山顶餐厅",
  "latitude": 45.123456,
  "longitude": 6.789012,
  "createdBy": "device_001",
  "creatorNickname": "张三"
}
```

**响应 (201)**
```json
{
  "meetingPoint": {
    "id": "mp_123456",
    "teamId": "team_abc",
    "name": "山顶餐厅",
    "latitude": 45.123456,
    "longitude": 6.789012,
    "createdBy": "device_001",
    "creatorNickname": "张三",
    "createdAt": "2024-01-15T10:30:00Z",
    "isActive": false
  }
}
```

---

### 3. 更新集合点（修改名称）

**请求**
```
PUT /api/team/{teamId}/meeting-points/{pointId}
Content-Type: application/json

{
  "name": "新名称"
}
```

**响应 (200)**
```json
{
  "meetingPoint": {
    "id": "mp_123456",
    "teamId": "team_abc",
    "name": "新名称",
    "latitude": 45.123456,
    "longitude": 6.789012,
    "createdBy": "device_001",
    "creatorNickname": "张三",
    "createdAt": "2024-01-15T10:30:00Z",
    "isActive": false
  }
}
```

---

### 4. 删除集合点

**请求**
```
DELETE /api/team/{teamId}/meeting-points/{pointId}
```

**响应 (200)**
```json
{
  "success": true
}
```

---

### 5. 设置当前有效集合点

设置指定集合点为当前有效集合点。同一时间只能有一个有效集合点。

**请求**
```
POST /api/team/{teamId}/meeting-points/{pointId}/activate
```

**响应 (200)**
```json
{
  "success": true
}
```

**说明**: 调用此 API 后，服务端应该：
1. 将该 `pointId` 对应的集合点的 `isActive` 设置为 `true`
2. 将其他所有集合点的 `isActive` 设置为 `false`

---

### 6. 取消当前有效集合点

取消所有集合点的有效状态。

**请求**
```
POST /api/team/{teamId}/meeting-points/clear-active
```

**响应 (200)**
```json
{
  "success": true
}
```

---

## 错误响应

所有 API 在发生错误时返回以下格式：

```json
{
  "error": "错误描述信息"
}
```

**常见状态码**:
- `400` - 请求参数错误
- `404` - 团队或集合点不存在
- `500` - 服务器内部错误

---

## 数据模型

### MeetingPoint

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 集合点唯一ID |
| teamId | string | 所属团队ID |
| name | string | 集合点名称 |
| latitude | number | 纬度 |
| longitude | number | 经度 |
| createdBy | string | 创建者设备ID |
| creatorNickname | string | 创建者昵称 |
| createdAt | string (ISO8601) | 创建时间 |
| isActive | boolean | 是否为当前有效集合点 |

