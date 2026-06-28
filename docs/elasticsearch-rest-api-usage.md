# Elasticsearch REST API 使用文件

本文件記錄 `analyzer`、`healthycheck` 及 `utility` 模組中所有對 Elasticsearch 的 REST API 操作及範例，供 debug 參考。

ES Base URL 來源：`org.onlab.nocsys.Utility.getEsUrl()`（以下範例以 `http://localhost:9200/` 為例）

---

## 一、analyzer 模組

### 1. 寫入 collectd 監控數據

| 項目 | 內容 |
|------|------|
| HTTP Method | POST |
| URL | `{ES_URL}collectd/doc/` |
| 用途 | 寫入交換機 CPU / Memory 監控數據 |

```bash
curl -X POST "http://localhost:9200/collectd/doc/" \
  -H "Content-Type: application/json" \
  -d '{
    "@timestamp": "2024-06-01T08:30:00.000Z",
    "host": "192.168.1.1",
    "port": 830,
    "plugin": "cpu",
    "collectd_type": "percent",
    "type_instance": "idle",
    "value": 85.5,
    "@version": "1"
  }'
```

---

### 2. 查詢 collectd — 單主機時序聚合

| 項目 | 內容 |
|------|------|
| HTTP Method | GET（帶 body） |
| URL | `{ES_URL}collectd/_search` |
| 用途 | 查詢指定主機的 CPU / Memory / Disk 時序統計（date_histogram + avg） |

```bash
curl -X GET "http://localhost:9200/collectd/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"term": {"host.keyword": "192.168.1.1"}},
          {"term": {"plugin.keyword": "cpu"}},
          {"term": {"collectd_type.keyword": "percent"}},
          {"term": {"type_instance.keyword": "idle"}},
          {"range": {"@timestamp": {"gte": "2024-06-01T00:00:00.000Z", "lte": "2024-06-01T23:59:59.000Z"}}}
        ]
      }
    },
    "sort": [{"@timestamp": {"order": "desc"}}],
    "aggs": {
      "value_per_base": {
        "date_histogram": {"field": "@timestamp", "interval": "60s"},
        "aggs": {
          "type_instance_val": {"avg": {"field": "value"}}
        }
      },
      "avg_base_value": {
        "avg_bucket": {"buckets_path": "value_per_base>type_instance_val"}
      }
    },
    "size": 0
  }'
```

---

### 3. 查詢 portstats — 單主機單 port 統計

| 項目 | 內容 |
|------|------|
| HTTP Method | GET（帶 body） |
| URL | `{ES_URL}portstats/_search` |
| 用途 | 查詢指定主機特定 port 的流量統計（packets, bytes） |

```bash
curl -X GET "http://localhost:9200/portstats/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"term": {"host.keyword": "192.168.1.1"}},
          {"term": {"port": 1}},
          {"range": {"@timestamp": {"gte": "2024-06-01T00:00:00.000Z", "lte": "2024-06-01T23:59:59.000Z"}}}
        ]
      }
    },
    "sort": [{"@timestamp": {"order": "desc"}}],
    "aggs": {
      "value_per_base": {
        "date_histogram": {"field": "@timestamp", "interval": "60s"},
        "aggs": {
          "cal_value": {"max": {"field": "packetsReceived"}}
        }
      },
      "avg_base_value": {
        "avg_bucket": {"buckets_path": "value_per_base>cal_value"}
      }
    },
    "size": 0
  }'
```

---

### 4. 查詢 portstats — 單主機所有 port 明細

| 項目 | 內容 |
|------|------|
| HTTP Method | GET（帶 body） |
| URL | `{ES_URL}portstats/_search` |
| 用途 | 查詢單主機所有 port 的 packets/bytes/dropped/errors 統計 |

```bash
curl -X GET "http://localhost:9200/portstats/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"term": {"host.keyword": "192.168.1.1"}},
          {"range": {"@timestamp": {"gte": "2024-06-01T00:00:00.000Z", "lte": "2024-06-01T23:59:59.000Z"}}}
        ]
      }
    },
    "sort": [{"@timestamp": {"order": "desc"}}],
    "aggs": {
      "value_per_port": {
        "terms": {"field": "port", "size": 100},
        "aggs": {
          "value_per_base": {
            "date_histogram": {"field": "@timestamp", "interval": "60s"},
            "aggs": {
              "packets_rx_avg": {"max": {"field": "packetsReceived"}},
              "packets_tx_avg": {"max": {"field": "packetsSent"}},
              "dropped_rx_avg": {"max": {"field": "packetsRxDropped"}},
              "dropped_tx_avg": {"max": {"field": "packetsTxDropped"}},
              "error_rx_avg": {"max": {"field": "packetsRxErrors"}},
              "error_tx_avg": {"max": {"field": "packetsTxErrors"}},
              "bytes_rx_avg": {"max": {"field": "bytesReceived"}},
              "bytes_tx_avg": {"max": {"field": "bytesSent"}}
            }
          }
        }
      }
    },
    "size": 0
  }'
```

---

### 5. 查詢 portstats — 單主機 port 彙總

| 項目 | 內容 |
|------|------|
| HTTP Method | GET（帶 body） |
| URL | `{ES_URL}portstats/_search` |
| 用途 | 彙總主機所有 port 的 packets/bytes（先取各 port max，再 sum_bucket） |

```bash
curl -X GET "http://localhost:9200/portstats/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"term": {"host.keyword": "192.168.1.1"}},
          {"range": {"@timestamp": {"gte": "2024-06-01T00:00:00.000Z", "lte": "2024-06-01T23:59:59.000Z"}}}
        ]
      }
    },
    "sort": [{"@timestamp": {"order": "desc"}}],
    "aggs": {
      "value_per_base": {
        "date_histogram": {"field": "@timestamp", "interval": "60s"},
        "aggs": {
          "packets_rx_max": {
            "terms": {"field": "port", "size": 100},
            "aggs": {"max_value": {"max": {"field": "packetsReceived"}}}
          },
          "cal_packets_rx_value": {"sum_bucket": {"buckets_path": "packets_rx_max>max_value"}},
          "packets_tx_max": {
            "terms": {"field": "port", "size": 100},
            "aggs": {"max_value": {"max": {"field": "packetsSent"}}}
          },
          "cal_packets_tx_value": {"sum_bucket": {"buckets_path": "packets_tx_max>max_value"}}
        }
      }
    },
    "size": 0
  }'
```

---

### 6. 查詢 collectd — 多主機聚合

| 項目 | 內容 |
|------|------|
| HTTP Method | GET（帶 body） |
| URL | `{ES_URL}collectd/_search` |
| 用途 | 多主機 CPU / Memory / Disk 聚合查詢（per_host → per_time → per_type_instance） |

```bash
curl -X GET "http://localhost:9200/collectd/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"match": {"plugin": "cpu"}},
          {"match": {"collectd_type": "percent"}},
          {"range": {"@timestamp": {"gte": "2024-06-01T00:00:00.000Z", "lte": "2024-06-01T23:59:59.000Z"}}},
          {"terms": {"host.keyword": ["192.168.1.1", "192.168.1.2", "192.168.1.3"]}}
        ]
      }
    },
    "sort": [{"@timestamp": {"order": "desc"}}],
    "aggs": {
      "per_host": {
        "terms": {"field": "host.keyword", "size": 1000},
        "aggs": {
          "per_time": {
            "date_histogram": {"field": "@timestamp", "interval": "300s"},
            "aggs": {
              "per_type_instance": {
                "terms": {"field": "type_instance.keyword", "size": 100},
                "aggs": {
                  "avg_value": {"avg": {"field": "value"}}
                }
              }
            }
          }
        }
      }
    },
    "size": 0
  }'
```

---

### 7. 查詢 portstats — 多主機聚合

| 項目 | 內容 |
|------|------|
| HTTP Method | GET（帶 body） |
| URL | `{ES_URL}portstats/_search` |
| 用途 | 多主機交換機 port 統計彙總（per_host → per_time → sum） |

```bash
curl -X GET "http://localhost:9200/portstats/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"match": {"plugin": "interface"}},
          {"range": {"@timestamp": {"gte": "2024-06-01T00:00:00.000Z", "lte": "2024-06-01T23:59:59.000Z"}}},
          {"terms": {"host.keyword": ["192.168.1.1", "192.168.1.2"]}}
        ]
      }
    },
    "sort": [{"@timestamp": {"order": "desc"}}],
    "aggs": {
      "per_host": {
        "terms": {"field": "host.keyword", "size": 1000},
        "aggs": {
          "per_time": {
            "date_histogram": {"field": "@timestamp", "interval": "300s"},
            "aggs": {
              "per_type_instance": {
                "terms": {"field": "collectd_type.keyword", "size": 100},
                "aggs": {
                  "rx_max": {"max": {"field": "rx"}},
                  "tx_max": {"max": {"field": "tx"}}
                }
              }
            }
          }
        }
      }
    },
    "size": 0
  }'
```

---

### 8. 查詢 control_log — Nginx 流量分析

| 項目 | 內容 |
|------|------|
| HTTP Method | GET（帶 body） |
| URL | `{ES_URL}control_log/_search` |
| 用途 | 查詢 Nginx access log 流量趨勢（按時間分組統計請求數） |

```bash
curl -X GET "http://localhost:9200/control_log/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"match": {"source": "access.log"}},
          {"range": {"@timestamp": {"gte": "2024-06-01T00:00:00.000Z", "lte": "2024-06-01T23:59:59.000Z"}}}
        ]
      }
    },
    "sort": [{"@timestamp": {"order": "desc"}}],
    "aggs": {
      "count_per_base": {
        "date_histogram": {"field": "@timestamp", "interval": "300s"},
        "aggs": {
          "filter_by_clientip": {"terms": {"field": "clientIP.keyword"}}
        }
      }
    },
    "size": 0
  }'
```

---

### 9. 查詢 control_log — 按 URL 或 ClientIP 排名

| 項目 | 內容 |
|------|------|
| HTTP Method | GET（帶 body） |
| URL | `{ES_URL}control_log/_search` |
| 用途 | 統計 access log 中各 request URL 或 clientIP 的請求次數排名 |

```bash
# 按 request URL 排名
curl -X GET "http://localhost:9200/control_log/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"match": {"source": "access.log"}},
          {"range": {"@timestamp": {"gte": "2024-06-01T00:00:00.000Z", "lte": "2024-06-01T23:59:59.000Z"}}}
        ]
      }
    },
    "sort": [{"@timestamp": {"order": "desc"}}],
    "aggs": {
      "count_per_base": {"terms": {"field": "request.keyword"}}
    },
    "size": 0
  }'
```

```bash
# 按 clientIP 排名
curl -X GET "http://localhost:9200/control_log/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"match": {"source": "access.log"}},
          {"range": {"@timestamp": {"gte": "2024-06-01T00:00:00.000Z", "lte": "2024-06-01T23:59:59.000Z"}}}
        ]
      }
    },
    "sort": [{"@timestamp": {"order": "desc"}}],
    "aggs": {
      "count_per_base": {"terms": {"field": "clientip.keyword"}}
    },
    "size": 0
  }'
```

---

### 10. 通用 ES 搜尋代理

| 項目 | 內容 |
|------|------|
| HTTP Method | GET（帶 body） |
| URL | `{ES_URL}{index}/_search` |
| 對外 REST 路徑 | `POST /mars/analyzer/v1/searchbyJson/{index}` |
| 用途 | 前端指定 index，直接透傳查詢 body 到 ES |

```bash
# 透過 Mars API 代理
curl -X POST "https://192.168.42.11/mars/analyzer/v1/searchbyJson/collectd" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {"match_all": {}},
    "size": 10
  }'
```

---

## 二、healthycheck 模組

### 1. 查詢 collectd — 閾值檢測

| 項目 | 內容 |
|------|------|
| HTTP Method | POST |
| URL | `{ES_URL}collectd/doc/_search` |
| 用途 | 定期查詢 CPU / Memory / Disk 數據，比對告警閾值 |
| 頻率 | 每 60 秒 |

```bash
curl -X POST "http://localhost:9200/collectd/doc/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "filter": {
          "bool": {
            "must": [
              {"match": {"plugin": "cpu"}},
              {"match": {"collectd_type": "percent"}},
              {"match": {"type_instance": "idle"}},
              {"range": {"@timestamp": {"gte": "2024-06-01T08:00:00.000Z", "lte": "2024-06-01T08:01:00.000Z"}}}
            ]
          }
        }
      }
    },
    "sort": [{"@timestamp": {"order": "asc"}}],
    "size": 10000
  }'
```

---

### 2. 查詢 portstats — 閾值檢測

| 項目 | 內容 |
|------|------|
| HTTP Method | POST |
| URL | `{ES_URL}portstats/doc/_search` |
| 用途 | 查詢 port 的 RX/TX、丟包率、流量，比對閾值觸發告警 |
| 頻率 | 每 60 秒 |

```bash
curl -X POST "http://localhost:9200/portstats/doc/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "filter": {
          "bool": {
            "must": [
              {"match": {"host": "192.168.1.1"}},
              {"range": {"@timestamp": {"gte": "2024-06-01T08:00:00.000Z", "lte": "2024-06-01T08:01:00.000Z"}}}
            ]
          }
        }
      }
    },
    "sort": [{"@timestamp": {"order": "asc"}}],
    "size": 10000
  }'
```

---

### 3. 查詢 ES 空間使用量

| 項目 | 內容 |
|------|------|
| HTTP Method | GET |
| URL | `{ES_URL}_cat/indices?format=json` |
| 用途 | 取得各 index 磁碟佔用，判斷儲存是否超過閾值 |

```bash
curl -X GET "http://localhost:9200/_cat/indices?format=json"
```

回應範例：
```json
[
  {"health": "green", "status": "open", "index": "collectd", "pri.store.size": "5.2gb", "docs.count": "12000000"},
  {"health": "green", "status": "open", "index": "portstats", "pri.store.size": "3.1gb", "docs.count": "8000000"},
  {"health": "green", "status": "open", "index": "control_log", "pri.store.size": "1.5gb", "docs.count": "5000000"}
]
```

---

### 4. 查詢 ES 集群健康狀態

| 項目 | 內容 |
|------|------|
| HTTP Method | GET |
| URL | `{ES_URL}_cat/indices?format=json` |
| 用途 | 檢查是否有 index 的 health 為 "red"，觸發 ES 不健康告警 |

```bash
curl -X GET "http://localhost:9200/_cat/indices?format=json" | \
  python3 -c "import json,sys; data=json.load(sys.stdin); [print(i['index']) for i in data if i.get('health')=='red']"
```

---

### 5. 更新 alert — 寫入結束時間

| 項目 | 內容 |
|------|------|
| HTTP Method | POST |
| URL | `{ES_URL}alert/doc/{id}/_update` |
| 用途 | 當告警恢復時，更新該 alert 的 end_time |

```bash
curl -X POST "http://localhost:9200/alert/doc/abc123/_update" \
  -H "Content-Type: application/json" \
  -d '{
    "doc": {
      "end_time": "2024-06-01T09:30:00.000Z"
    }
  }'
```

---

### 6. 查詢 alert — 搜尋未結束的告警

| 項目 | 內容 |
|------|------|
| HTTP Method | POST |
| URL | `{ES_URL}alert/doc/_search` |
| 用途 | 系統啟動時搜尋 end_time 為空的告警（孤立告警），進行清理 |

```bash
curl -X POST "http://localhost:9200/alert/doc/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "must_not": {
          "exists": {"field": "end_time"}
        }
      }
    },
    "size": 10000,
    "_source": false
  }'
```

---

## 三、utility 模組（Mars 對外 REST API）

以下為 `utility` 模組透過 Mars REST API 暴露的 Elasticsearch 管理操作。前端或使用者透過 `https://<MARS_IP>/mars/utility/elasticsearch/v1/...` 呼叫。

### 1. 查詢 index 所有資料

```bash
curl -X GET "https://192.168.42.11/mars/utility/elasticsearch/v1/{index}"
```

後端實際呼叫：`GET {ES_URL}{index}/_search`（body: `{"query":{"match_all":{}}}`)

---

### 2. 帶條件查詢

```bash
curl -X POST "https://192.168.42.11/mars/utility/elasticsearch/v1/{index}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {"range": {"@timestamp": {"gte": "2024-01-01", "lte": "2024-01-02"}}},
    "size": 100
  }'
```

後端實際呼叫：`GET {ES_URL}{index}/_search`（轉發 body）

---

### 3. 按 ID 查詢文件

```bash
curl -X GET "https://192.168.42.11/mars/utility/elasticsearch/v1/{index}/{type}/{id}"
```

後端實際呼叫：`GET {ES_URL}{index}/{type}/{id}`

---

### 4. 刪除過期資料（delete_by_query）

```bash
curl -X POST "https://192.168.42.11/mars/utility/elasticsearch/v1/{index}/_delete_by_query" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "range": {
        "@timestamp": {"lt": "2024-01-01T00:00:00.000Z"}
      }
    }
  }'
```

後端實際呼叫：`POST {ES_URL}{index}/_delete_by_query?conflicts=proceed&wait_for_completion=false`

> 注意：此操作為非同步（`wait_for_completion=false`），會回傳 task ID。

---

### 5. 釋放磁碟空間（force merge）

```bash
curl -X POST "https://192.168.42.11/mars/utility/elasticsearch/v1/space/clear/{index}"
```

後端實際呼叫：`POST {ES_URL}{index}/_forcemerge?only_expunge_deletes=true`

> 注意：僅回收已標記刪除文件的空間，本身不刪除資料。

---

### 6. 設定 index 保留天數

```bash
curl -X POST "https://192.168.42.11/mars/utility/elasticsearch/v1/{index}/keep" \
  -H "Content-Type: application/json" \
  -d '{"keepDays": 30}'
```

---

### 7. 刪除 index 保留天數設定（恢復預設 180 天）

```bash
curl -X DELETE "https://192.168.42.11/mars/utility/elasticsearch/v1/{index}/keep"
```

---

### 8. 查詢所有 index 保留設定

```bash
curl -X GET "https://192.168.42.11/mars/utility/elasticsearch/v1/keep/list"
```

回應範例：
```json
{
  "esKeepDays": [
    {"index": "collectd", "keepDay": 30},
    {"index": "portstats", "keepDay": 30}
  ]
}
```

---

### 9. 列出所有 index

```bash
curl -X GET "https://192.168.42.11/mars/utility/elasticsearch/v1/index/list"
```

回應範例：
```json
{"indices": ["collectd", "portstats", "control_log", "switch_syslog", "alert"]}
```

---

### 10. 查詢非同步刪除任務

```bash
curl -X GET "https://192.168.42.11/mars/utility/elasticsearch/v1/tasks/list"
```

後端實際呼叫：`GET {ES_URL}_tasks?actions=*/delete/byquery&detailed`

---

### 11. 取消非同步任務

```bash
curl -X POST "https://192.168.42.11/mars/utility/elasticsearch/v1/tasks/cancel/{taskId}"
```

後端實際呼叫：`POST {ES_URL}_tasks/{taskId}/_cancel`

---

### 12. 刪除已完成任務紀錄

```bash
curl -X DELETE "https://192.168.42.11/mars/utility/elasticsearch/v1/tasks/delete/{taskId}"
```

後端實際呼叫：`DELETE {ES_URL}.tasks/task/{taskId}?refresh`

---

### 13. 建立備份快照

```bash
curl -X PUT "https://192.168.42.11/mars/utility/elasticsearch/v1/_snapshot/{backup_name}"
```

後端實際呼叫：`PUT {ES_URL}_snapshot/{backup_name}`（body: `{"type":"fs","settings":{"location":"/mnt/backup/{backup_name}"}}`)

---

### 14. 查詢 ES 空間狀態

```bash
curl -X GET "https://192.168.42.11/mars/utility/elasticsearch/v1/status"
```

後端實際呼叫：`GET {ES_URL}_cat/indices?format=json`

---

### 15. 自動清除排程機制

系統啟動時由 `UtilityManager` 啟動 `ElasticsearchTaskLoop`：

- **觸發時間：** 每天凌晨 1:00
- **執行間隔：** 每 24 小時（86400 秒）
- **清除邏輯：**
  1. `GET {ES_URL}_cat/indices?format=json` — 取得所有 index
  2. 讀取每個 index 的 `keepDays` 設定（預設 180 天）
  3. `POST {ES_URL}{index}/_delete_by_query?conflicts=proceed` — 刪除超過 keepDays 的文件
  4. `POST {ES_URL}_all/_forcemerge?only_expunge_deletes=true` — 回收磁碟空間

刪除查詢 body 範例（以 30 天為例）：
```json
{
  "query": {
    "range": {
      "@timestamp": {
        "lt": "2024-05-01T00:00:00.000Z"
      }
    }
  }
}
```

> 特殊：`alert` index 使用 `start_time` 欄位取代 `@timestamp`。

---

### 16. CSV 下載資料

```bash
# 下載全部資料（轉 CSV）
curl -X GET "https://192.168.42.11/mars/utility/elasticsearch/v1/csv/{index}"

# 帶條件下載
curl -X POST "https://192.168.42.11/mars/utility/elasticsearch/v1/csv/{index}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {"range": {"@timestamp": {"gte": "2024-01-01", "lte": "2024-01-02"}}},
    "size": 10000
  }'

# 取得已產生的 CSV 檔案
curl -X GET "https://192.168.42.11/mars/utility/elasticsearch/v1/csv/file"
```

---

## 四、涉及的 ES Index 總覽

| Index | 用途 | 寫入來源 | 讀取模組 |
|-------|------|----------|----------|
| collectd | 系統監控（CPU, Memory, Disk, Interface） | analyzer | analyzer, healthycheck, utility |
| portstats | 交換機 port 統計 | 外部 filebeat | analyzer, healthycheck, utility |
| syslog | Syslog 紀錄 | 外部 filebeat | analyzer, utility |
| control_log | Filebeat/Nginx access log | 外部 filebeat | analyzer, utility |
| switch_syslog | 交換機 Syslog | 外部 filebeat | utility |
| alert | 告警歷史紀錄 | healthycheck | healthycheck, utility |
| .tasks | ES 內部任務紀錄 | ES 系統 | utility（管理用） |


---

## 五、共用配置

| 配置項 | 說明 |
|--------|------|
| `ES_URL` | ES base URL，由 `org.onlab.nocsys.Utility.getEsUrl()` 取得 |
| `ELASTICSEARCH_CONN_TIMEOUT` | 連線逾時（毫秒） |
| `ELASTICSEARCH_READ_TIMEOUT` | 讀取逾時（毫秒） |
| `ES_QUERY_MAX_RETRY` | 查詢失敗重試次數（3） |
| `ES_QUERY_RETRY_INTERVAL_MS` | 重試間隔（2000 毫秒） |

---

## 六、參考範例（來源：[elasticsearch_example](https://github.com/macauleycheng/elasticsearch_example)）

### 1. 常用管理指令

```bash
# 搜尋所有文件
curl -XPOST -H "Content-Type: application/json" http://127.0.0.1:9200/_search \
  -d '{"query":{"match_all":{}}}'

# 列出所有索引
curl -XGET http://127.0.0.1:9200/_cat/indices?v

# 刪除 index
curl -XDELETE http://127.0.0.1:9200/portstats
curl -XDELETE http://127.0.0.1:9200/control_log

# 查看叢集健康狀態
curl -XGET http://localhost:9200/_cluster/health?pretty=true
curl -XGET 'http://localhost:9200/_cluster/health?level=indices&pretty'

# 查看磁碟分配說明
curl -XGET http://localhost:9200/_cluster/allocation/explain?pretty

# 查看節點資訊
curl -XGET -H "Content-Type: application/json" http://127.0.0.1:9200/_nodes/?pretty

# 查看所有 template
curl -XGET http://127.0.0.1:9200/_template/
```

---

### 2. 解除 read_only 限制

當 ES 因為磁碟空間不足自動鎖定 index 時使用：

```bash
# 解除特定 index
curl -XPUT -g -H 'Content-Type: application/json' \
  'http://127.0.0.1:9200/logstash/_settings' \
  -d '{"index": {"blocks": {"read_only_allow_delete": "false"}}}'

# 解除所有 index
curl -XPUT -g -H 'Content-Type: application/json' \
  'http://127.0.0.1:9200/_settings' \
  -d '{"index": {"blocks": {"read_only_allow_delete": "false"}}}'

# 另一種寫法
curl -X PUT "http://localhost:9200/collectd/_settings" \
  -H "Content-Type:application/json" \
  -d '{"index.blocks.read_only_allow_delete": null}'
```

---

### 3. 設定 replica 和動態欄位

```bash
# 設定 replica 為 0（單節點環境避免 yellow）
curl -XPUT -H "Content-Type: application/json" \
  http://127.0.0.1:9200/collectd/_settings \
  -d '{"number_of_replicas": 0}'

# 開啟動態新增欄位
curl -XPUT -H "Content-Type: application/json" \
  http://127.0.0.1:9200/filebeat/_settings \
  -d '{"index.mapper.dynamic": true}'
```

---

### 4. 修改 Mapping

```bash
# 為 control_log 新增 log_ts 欄位
curl -XPUT http://127.0.0.1:9200/control_log/_mapping/ \
  -H "Content-Type: application/json" \
  -d '{"properties": {"log_ts": {"type": "text", "norms": false, "fielddata": true}}}'

# 查看 mapping
curl -XGET http://127.0.0.1:9200/control_log/_mapping/

# 為 logstash 新增 fielddata
curl -XPOST -H "Content-Type: application/json" \
  http://127.0.0.1:9200/logstash/_mapping/doc/ \
  -d '{"properties": {"type_instance": {"type": "text", "fielddata": true}}}'
```

---

### 5. 新增 Index Template

```bash
curl -XPUT -H "Content-Type: application/json" \
  http://127.0.0.1:9200/_template/control_log \
  -d '{
    "order": 0,
    "version": 60001,
    "index_patterns": ["control_log"],
    "settings": {
      "index": {
        "number_of_shards": "1",
        "refresh_interval": "5s"
      }
    },
    "mappings": {
      "dynamic_templates": [
        {"message_field": {"path_match": "message", "mapping": {"norms": false, "type": "text"}, "match_mapping_type": "string"}},
        {"string_fields": {"mapping": {"norms": false, "type": "text", "fields": {"keyword": {"ignore_above": 256, "type": "keyword"}}}, "match_mapping_type": "string", "match": "*"}}
      ],
      "properties": {
        "@timestamp": {"type": "date"},
        "@version": {"type": "keyword"},
        "geoip": {
          "dynamic": true,
          "properties": {
            "ip": {"type": "ip"},
            "latitude": {"type": "half_float"},
            "location": {"type": "geo_point"},
            "longitude": {"type": "half_float"}
          }
        }
      }
    },
    "aliases": {}
  }'
```

---

### 6. 備份與快照

```bash
# 建立快照 repository（注意：應使用 PUT）
curl -XPUT -H "Content-Type: application/json" \
  http://127.0.0.1:9200/_snapshot/my_backup \
  -d '{"type": "fs", "settings": {"location": "/mnt/backup/gotest"}}'

# 查看進行中的快照
curl -XGET http://127.0.0.1:9200/_snapshot/my_backup/_current
```

---

### 7. Scroll Search（大量資料分頁）

```bash
# 第一次請求：取得 scroll_id
curl -XGET -g -H "Content-Type: application/json" \
  'http://127.0.0.1:9200/logstash/_search?q=@timestamp:["2018-01-01"+TO+"2018-09-30"]&size=2&scroll=1m'

# 後續請求：使用 scroll_id 繼續取資料（推薦用 POST body 傳遞）
curl -XPOST -H "Content-Type: application/json" \
  'http://127.0.0.1:9200/_search/scroll' \
  -d '{"scroll": "1m", "scroll_id": "<YOUR_SCROLL_ID>"}'
```

---

### 8. 查詢範例 — CPU 時間範圍

```bash
curl -XGET -H "Content-Type: application/json" \
  http://127.0.0.1:9200/collectd/_search -d '{
  "query": {
    "bool": {
      "must": [
        {"match": {"plugin": "cpu"}},
        {"match": {"collectd_type": "percent"}},
        {"match": {"host": "192.168.200.31"}},
        {"range": {"@timestamp": {"gte": "2024-01-01", "lte": "2024-01-02"}}}
      ]
    }
  },
  "sort": [{"@timestamp": {"order": "asc"}}],
  "size": 1000
}'
```

---

### 9. 查詢範例 — Memory 時間範圍

```bash
curl -XGET -H "Content-Type: application/json" \
  http://127.0.0.1:9200/collectd/_search -d '{
  "query": {
    "bool": {
      "must": [
        {"match": {"plugin": "memory"}},
        {"match": {"collectd_type": "percent"}},
        {"match": {"host": "cicada"}},
        {"range": {"@timestamp": {"gte": "now-15d/d"}}}
      ]
    }
  },
  "sort": [{"@timestamp": {"order": "asc"}}],
  "size": 1000
}'
```

---

### 10. 查詢範例 — Disk 使用率

```bash
curl -XGET -H "Content-Type: application/json" \
  http://127.0.0.1:9200/collectd/_search -d '{
  "query": {
    "bool": {
      "must": [
        {"match": {"plugin": "df"}},
        {"match": {"collectd_type": "percent_bytes"}},
        {"match": {"host": "cicada"}},
        {"match": {"plugin_instance": "root"}},
        {"match": {"type_instance": "used"}},
        {"range": {"@timestamp": {"gte": "now-15d/d"}}}
      ]
    }
  },
  "sort": [{"@timestamp": {"order": "asc"}}],
  "size": 10
}'
```

---

### 11. 查詢範例 — Portstats 時間範圍

```bash
# 使用相對時間
curl -XGET -H "Content-Type: application/json" \
  http://127.0.0.1:9200/portstats/_search -d '{
  "query": {
    "bool": {
      "must": [
        {"match": {"deviceName": "cicada"}},
        {"range": {"@timestamp": {"gte": "now-15d/d"}}}
      ]
    }
  },
  "sort": [{"@timestamp": {"order": "asc"}}],
  "size": 1000
}'

# 使用絕對時間
curl -XGET -H "Content-Type: application/json" \
  http://127.0.0.1:9200/portstats/_search -d '{
  "query": {
    "bool": {
      "must": [
        {"match": {"deviceName": "cicada"}},
        {"range": {"@timestamp": {"gte": "2024-01-01", "lte": "2024-12-01"}}}
      ]
    }
  },
  "sort": [{"@timestamp": {"order": "asc"}}],
  "size": 1000
}'
```

---

### 12. 查詢範例 — Aggregation（date_histogram + avg）

```bash
curl -XGET -H "Content-Type: application/json" \
  http://127.0.0.1:9200/collectd/_search -d '{
  "query": {
    "bool": {
      "must": [
        {"match": {"plugin": "memory"}},
        {"match": {"collectd_type": "percent"}},
        {"match": {"host": "cicada"}},
        {"match": {"type_instance": "used"}},
        {"range": {"@timestamp": {"gte": "2024-01-01T00:00Z", "lte": "2024-01-15T23:59Z"}}}
      ]
    }
  },
  "sort": [{"@timestamp": {"order": "desc"}}],
  "aggs": {
    "value_per_hour": {
      "date_histogram": {"field": "@timestamp", "interval": "10m"},
      "aggs": {
        "type_instance_val": {"avg": {"field": "value"}}
      }
    },
    "avg_hour_value": {
      "avg_bucket": {"buckets_path": "value_per_hour>type_instance_val"}
    }
  },
  "size": 0
}'
```

---

### 13. 查詢範例 — control_log 按 ClientIP 時間分佈

```bash
curl -XGET -H 'Content-Type: application/json' \
  http://127.0.0.1:9200/control_log/_search -d '{
  "query": {
    "bool": {
      "filter": [
        {"match_all": {}},
        {"match_phrase": {"source": "/var/log/nginx/access.log"}},
        {"match_phrase": {"clientip": "114.136.221.180"}},
        {"range": {"@timestamp": {"gte": "2024-01-01T00:00:00.000Z", "lte": "2024-01-07T23:59:59.999Z"}}}
      ]
    }
  },
  "sort": [{"@timestamp": {"order": "desc"}}],
  "aggs": {
    "requests_over_time": {
      "date_histogram": {"field": "@timestamp", "fixed_interval": "3h", "time_zone": "Asia/Taipei", "min_doc_count": 1}
    }
  }
}'
```

---

### 14. 推送資料到 ES（Python 腳本）

```python
import json
import pycurl

ELASTICSEARCH_URL = "http://127.0.0.1:9200/"
READ_FILE = "./log_stash.json"

def main():
    with open(READ_FILE) as f:
        data = json.load(f)
        entries = data['hits']['hits']
        for en in entries:
            index = en["_index"]
            doc_type = en["_type"]
            source = json.dumps(en["_source"])
            c = pycurl.Curl()
            c.setopt(pycurl.URL, ELASTICSEARCH_URL + index + "/" + doc_type)
            c.setopt(pycurl.HTTPHEADER, ['Content-Type: application/json'])
            c.setopt(pycurl.POST, 1)
            c.setopt(pycurl.POSTFIELDS, source)
            c.perform()
            c.close()

if __name__ == "__main__":
    main()
```

---

### 15. ES 文件結構範例

**collectd 文件：**
```json
{
  "@timestamp": "2018-09-14T15:56:48.467Z",
  "collectd_type": "percent",
  "host": "192.168.200.65",
  "value": 76.29,
  "type_instance": "idle",
  "@version": "1",
  "plugin": "cpu"
}
```

**portstats 文件：**
```json
{
  "port": 5,
  "bytesReceived": 0,
  "bytesSent": 0,
  "packetsReceived": 0,
  "packetsSent": 0,
  "packetsRxDropped": 0,
  "packetsTxDropped": 0,
  "packetsRxErrors": 0,
  "packetsTxErrors": -1,
  "deviceName": "cicada",
  "deviceId": "of:0000cc37ab772c80",
  "host": "cicada",
  "@timestamp": "2018-09-13T13:26:56Z"
}
```


---

## 七、常見問題排查

### ES Index 變成 read_only

**症狀：** 寫入失敗，回傳 `cluster_block_exception`、`FORBIDDEN/12/index read-only / allow delete`

**原因：** 磁碟使用率超過 95%，ES 自動鎖定所有 index

**解法：**
```bash
# 1. 清理空間（刪除舊資料或手動刪除 index）
curl -XDELETE http://127.0.0.1:9200/collectd

# 2. 解除所有 index 的 read_only 鎖定
curl -XPUT -H 'Content-Type: application/json' \
  'http://127.0.0.1:9200/_settings' \
  -d '{"index": {"blocks": {"read_only_allow_delete": "false"}}}'
```

---

### ES 狀態為 Yellow

**症狀：** `_cluster/health` 回傳 `"status": "yellow"`

**原因：** 單節點環境中 replica shard 無法分配

**解法：**
```bash
# 將所有 index 的 replica 設為 0
curl -XPUT -H "Content-Type: application/json" \
  http://127.0.0.1:9200/_settings \
  -d '{"number_of_replicas": 0}'
```

---

### 刪除資料後磁碟空間未釋放

**症狀：** 執行 `_delete_by_query` 後磁碟佔用沒有明顯減少

**原因：** ES 的 delete 是軟刪除（標記），需要 merge 才能真正釋放

**解法：**
```bash
# 對特定 index 執行 force merge
curl -XPOST "http://127.0.0.1:9200/collectd/_forcemerge?only_expunge_deletes=true"

# 對所有 index 執行
curl -XPOST "http://127.0.0.1:9200/_all/_forcemerge?only_expunge_deletes=true"
```

> 注意：force merge 會消耗 CPU 和 I/O，建議在離峰時執行。

---

### 連線 ES 逾時

**症狀：** `SocketTimeoutException` 或 `ConnectException`

**排查步驟：**
```bash
# 1. 確認 ES 是否運行
curl -X GET "http://127.0.0.1:9200/"

# 2. 確認 ES 叢集狀態
curl -X GET "http://127.0.0.1:9200/_cluster/health?pretty"

# 3. 確認磁碟空間
df -h

# 4. 檢查 ES log
docker logs elasticsearch 2>&1 | tail -50
```

---

### 非同步 delete_by_query 任務卡住

**症狀：** 前端顯示任務一直未完成

**排查步驟：**
```bash
# 查看所有正在執行的 delete_by_query 任務
curl -X GET "http://127.0.0.1:9200/_tasks?actions=*/delete/byquery&detailed&pretty"

# 取消卡住的任務
curl -X POST "http://127.0.0.1:9200/_tasks/{task_id}/_cancel"

# 刪除已完成任務紀錄
curl -X DELETE "http://127.0.0.1:9200/.tasks/task/{task_id}?refresh"
```
