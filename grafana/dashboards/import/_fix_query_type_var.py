#!/usr/bin/env python3
import json
from pathlib import Path

path = Path(__file__).parent / "nginx-client-ip-stats.json"
text = path.read_text(encoding="utf-8")

HOST_VAR_QUERY = (
    'sum by (server_name) (count_over_time({job="nginx", node=~"$node"} '
    '| json | server_name != "" and server_name != "-" [1h]))'
)

old_stream = (
    '{job=\\"nginx\\", node=\\"$node\\", host=~\\"$host\\"} | json '
    '| host != \\"\\" and host != \\"-\\"'
)
new_stream = (
    '{job=\\"nginx\\", node=\\"$node\\"} | json '
    '| server_name != \\"\\" and server_name != \\"-\\" | server_name=~\\"$host\\"'
)
text = text.replace(old_stream, new_stream)

for sc in ("3xx", "4xx", "5xx"):
    old = (
        f'{{job=\\"nginx\\", node=\\"$node\\", host=~\\"$host\\", status_class=\\"{sc}\\"}} | json '
        f'| host != \\"\\" and host != \\"-\\"'
    )
    new = (
        f'{{job=\\"nginx\\", node=\\"$node\\", status_class=\\"{sc}\\"}} | json '
        f'| server_name != \\"\\" and server_name != \\"-\\" | server_name=~\\"$host\\"'
    )
    text = text.replace(old, new)

text = text.replace("sum by (host,", "sum by (server_name,")
text = text.replace('"host": 0', '"server_name": 0')
text = text.replace('"options": "host"', '"options": "server_name"')
text = text.replace('fields[\\"host\\"]', 'fields[\\"server_name\\"]')
text = text.replace("{{host}}", "{{server_name}}")

data = json.loads(text)
q = HOST_VAR_QUERY
for i, v in enumerate(data["templating"]["list"]):
    if v.get("name") == "host":
        data["templating"]["list"][i] = {
            "name": "host",
            "label": "入口域名",
            "type": "query",
            "datasource": {"type": "loki", "uid": "${DS_LOKI}"},
            "query": {
                "query": q,
                "refId": "LokiVariableQueryEditor-VariableQuery",
            },
            "definition": q,
            "label": "server_name",
            "multi": True,
            "includeAll": True,
            "allValue": ".*",
            "refresh": 2,
            "sort": 1,
            "current": {"text": "All", "value": "$__all", "selected": True},
            "description": "Query 类型：sum by(server_name) 从 JSON 解析；须先选中转主机",
        }
        break

data["version"] = 14
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("v14 ok")
