# HTML source (auto-extract)

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>机房网络网关迁移改造文档</title>
<style>
:root{--bg:#f4f6f9;--card:#fff;--text:#1a1d26;--muted:#5c6370;--border:#dde2ea;--accent:#2563eb;--new-bg:#ecfdf5;--new-border:#10b981;--chg-bg:#fffbeb;--chg-border:#f59e0b;--unch-bg:#f8fafc;--tbd-bg:#fef2f2}
*{box-sizing:border-box}body{margin:0;font-family:"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif;background:var(--bg);color:var(--text);line-height:1.6}
.layout{display:flex;max-width:1400px;margin:0 auto}nav.toc{width:240px;flex-shrink:0;position:sticky;top:0;height:100vh;overflow-y:auto;padding:1.25rem 1rem;background:var(--card);border-right:1px solid var(--border);font-size:.875rem}
nav.toc h2{font-size:.75rem;text-transform:uppercase;color:var(--muted);margin:0 0 .75rem}nav.toc a{display:block;padding:.35rem .5rem;color:var(--text);text-decoration:none;border-radius:4px}nav.toc a:hover{background:#eff6ff;color:var(--accent)}
main{flex:1;padding:2rem 2.5rem 4rem;min-width:0}header.doc-header{background:linear-gradient(135deg,#1e3a5f,#2563eb);color:#fff;padding:2rem;border-radius:12px;margin-bottom:2rem}
header.doc-header h1{margin:0 0 .5rem;font-size:1.75rem}header.doc-header .meta{opacity:.9;font-size:.9rem}
.quick-cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:1rem;margin:1.5rem 0}
.quick-card{background:var(--card);border:1px solid var(--border);border-radius:8px;padding:1rem}.quick-card strong{display:block;font-size:1.1rem;color:var(--accent)}.quick-card span{font-size:.85rem;color:var(--muted)}
section{margin-bottom:2.5rem}section h2{font-size:1.35rem;border-bottom:2px solid var(--accent);padding-bottom:.4rem;margin-top:0}section h3{font-size:1.1rem;margin-top:1.5rem;color:#334155}
.legend{display:flex;flex-wrap:wrap;gap:.75rem;margin:1rem 0;font-size:.8rem}.legend span{padding:.25rem .6rem;border-radius:4px;border:1px solid var(--border)}
.legend .unchanged{background:var(--unch-bg)}.legend .new{background:var(--new-bg);border-color:var(--new-border)}.legend .changed{background:var(--chg-bg);border-color:var(--chg-border)}.legend .tbd{background:var(--tbd-bg);font-style:italic}
.table-wrap{overflow-x:auto;margin:1rem 0;border-radius:8px;border:1px solid var(--border);background:var(--card)}table{width:100%;border-collapse:collapse;font-size:.875rem}
th,td{padding:.55rem .75rem;text-align:left;border-bottom:1px solid var(--border)}th{background:#f1f5f9;font-weight:600;white-space:nowrap}tr:last-child td{border-bottom:none}
.ip{font-family:Consolas,"Courier New",monospace;font-size:.85em}tr.unchanged td{background:var(--unch-bg)}tr.new td{background:var(--new-bg)}tr.changed td{background:var(--chg-bg)}td.tbd,tr td.tbd{background:var(--tbd-bg);font-style:italic;color:#991b1b}
.cols2{display:grid;grid-template-columns:1fr 1fr;gap:1.5rem}@media(max-width:900px){.cols2{grid-template-columns:1fr}nav.toc{display:none}}
pre.topo{background:#0f172a;color:#e2e8f0;padding:1rem;border-radius:8px;font-size:.75rem;line-height:1.45;overflow-x:auto;margin:.5rem 0}
details{margin:1rem 0;border:1px solid var(--border);border-radius:8px;background:var(--card)}details summary{padding:.75rem 1rem;cursor:pointer;font-weight:600}details pre{margin:0;padding:1rem;background:#1e293b;color:#e2e8f0;font-size:.8rem;overflow-x:auto}
.steps{counter-reset:step;list-style:none;padding:0}.steps li{counter-increment:step;padding:.75rem 1rem .75rem 3rem;position:relative;margin-bottom:.5rem;background:var(--card);border:1px solid var(--border);border-radius:8px}
.steps li::before{content:counter(step);position:absolute;left:1rem;top:.75rem;width:1.5rem;height:1.5rem;background:var(--accent);color:#fff;border-radius:50%;text-align:center;line-height:1.5rem;font-size:.8rem;font-weight:bold}
.checklist{list-style:none;padding:0}.checklist li{padding:.5rem .75rem;border-bottom:1px solid var(--border)}.checklist li::before{content:"☐ ";color:var(--muted)}
.note{background:#eff6ff;border-left:4px solid var(--accent);padding:.75rem 1rem;margin:1rem 0;font-size:.9rem;border-radius:0 8px 8px 0}
.exec-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:1rem;margin:1rem 0 1.2rem}
.exec-card{background:var(--card);border:1px solid var(--border);border-radius:10px;padding:1rem}
.exec-card h4{margin:.1rem 0 .5rem;font-size:1rem;color:#1e3a8a}
.exec-card p{margin:0;color:#334155;font-size:.92rem}
.risk-box{display:grid;grid-template-columns:2fr 1fr;gap:1rem;margin-top:1rem}
.risk-main,.risk-side{background:var(--card);border:1px solid var(--border);border-radius:10px;padding:1rem}
.badge{display:inline-block;padding:.15rem .55rem;border-radius:999px;font-size:.78rem;font-weight:600}
.badge-mid{background:#fff7ed;color:#9a3412;border:1px solid #fdba74}
@media(max-width:1100px){.exec-grid{grid-template-columns:1fr}.risk-box{grid-template-columns:1fr}}
@media print{nav.toc{display:none}body{background:#fff}.layout{display:block}main{padding:0}pre.topo{background:#f1f5f9;color:#000;border:1px solid #ccc}}
</style>
</head>
<body>
<div class="layout">
<nav class="toc">
<h2>目录</h2>
<a href="#intro">文档说明</a>
<a href="#overview">改造概述</a>
<a href="#topology">拓扑与流量</a>
<a href="#lines">线路 A / B</a>
<a href="#vlan">VLAN 划分</a>
<a href="#cabling">物理接线</a>
<a href="#firewall">防火墙接口</a>
<a href="#switch">交换机端口</a>
<a href="#ipalloc">IP 地址分配</a>
<a href="#servers">服务器清单</a>
<a href="#changes">配置变更与割接</a>
<a href="#checklist">核对清单</a>
</nav>
<main>
<header class="doc-header">
<h1>机房网络网关迁移改造文档</h1>
<p class="meta">华为 USG6305E · ws1~ws20 · VLAN192 / VLAN10 · 线路 A 不动 / 线路 B 新增<br>版本 1.0 · 2026-05-28</p>
</header>
<section id="executive">
<h2>汇报结论（领导速览）</h2>
<div class="exec-grid">
  <div class="exec-card">
    <h4>改什么</h4>
    <p>仅改 B 组（ws9~ws20）默认网关：<span class="ip">10.0.0.11</span> → <span class="ip"><strong>10.0.0.254</strong></span>，并启用线路 B（XGE0/0/0 + GE0/0/7）。</p>
  </div>
  <div class="exec-card">
    <h4>不改什么</h4>
    <p>A 组（ws1~ws8）公网出网路径保持原样，GE0/0/0 与 GE0/0/1 持续交换透传，现网业务路径不变。</p>
  </div>
  <div class="exec-card">
    <h4>预期收益</h4>
    <p>去除 ws1 NAT 单点，B 组流量直达防火墙统一策略，网络职责清晰，回滚可按单台服务器快速执行。</p>
  </div>
</div>
<div class="risk-box">
  <div class="risk-main">
    <h4 style="margin:.1rem 0 .5rem;">风险与控制</h4>
    <p style="margin:0;">主要风险是现场参数不一致（公网 IP、VLAN ID、端口号）。控制策略：先灰度 1~2 台验证，再分批迁移；若异常，单台改回旧网关即可恢复。</p>
  </div>
  <div class="risk-side">
    <h4 style="margin:.1rem 0 .5rem;">风险等级</h4>
    <span class="badge badge-mid">中等可控</span>
    <p style="margin:.5rem 0 0;color:#475569;font-size:.9rem;">前提：严格执行割接前核对清单。</p>
  </div>
</div>
</section>
<section id="intro">
<h2>文档说明</h2>
<p>涵盖<strong>服务器 ws1~ws20</strong>、<strong>内网交换机</strong>、<strong>华为 USG6305E</strong>、<strong>线路 A/B</strong>、<strong>VLAN 192 / VLAN10</strong>、<strong>IP 分配</strong>及改造前/后对照。</p>
<div class="quick-cards">
<div class="quick-card"><strong>10.0.0.254</strong><span>新网关 GE0/0/7</span></div>
<div class="quick-card"><strong>10.0.0.11</strong><span>旧网关 ws1</span></div>
<div class="quick-card"><strong>A 组不改</strong><span>ws1~ws8 公网</span></div>
<div class="quick-card"><strong>B 组改网关</strong><span>ws9~ws20</span></div>
</div>
<div class="legend"><span class="unchanged">不变</span><span class="new">新增</span><span class="changed">变更</span><span class="tbd">待填</span></div>
</section>
<section id="overview">
<h2>1. 改造概述</h2>
<div class="table-wrap"><table>
<thead><tr><th>对象</th><th>改造前</th><th>改造后</th><th>变更</th></tr></thead>
<tbody>
<tr class="unchanged"><td>线路 A / GE0/0/0 / GE0/0/1</td><td>交换 VLAN1</td><td>同左</td><td>否</td></tr>
<tr class="new"><td>线路 B / XGE0/0/0</td><td>未接</td><td>路由 WAN</td><td><strong>新增</strong></td></tr>
<tr class="new"><td>GE0/0/7</td><td>未接</td><td>10.0.0.254 LAN</td><td><strong>新增</strong></td></tr>
<tr class="unchanged"><td>Sw-A / VLAN192</td><td>A 组</td><td>不变</td><td>否</td></tr>
<tr class="new"><td>Sw-B</td><td>无</td><td>Access VLAN10</td><td><strong>新增</strong></td></tr>
<tr class="unchanged"><td>ws1~ws8</td><td>公网 IP</td><td>不变</td><td>否</td></tr>
<tr class="changed"><td>ws9~ws20</td><td>网关 10.0.0.11</td><td>网关 <strong>10.0.0.254</strong></td><td><strong>是</strong></td></tr>
<tr class="changed"><td>ws1 NAT</td><td>10.0.0.11</td><td>迁后关闭</td><td>稍后</td></tr>
</tbody></table></div>
</section>
<section id="topology">
<h2>2. 拓扑与流量路径</h2>
<div class="cols2">
<div><h3>改造前</h3>
<pre class="topo">[线路A]--GE0/0/0==VLAN1桥==GE0/0/1--[Sw-A]
  |-- VLAN192: ws1~ws8 公网IP
  +-- VLAN10:  ws9~ws20 --&gt; 10.0.0.11(ws1 NAT) --&gt; 线路A
XGE0/0/0、GE0/0/7: 未接</pre>
<p><strong>A组：</strong>公网IP → VLAN192 → 透明桥 → 线路A</p>
<p><strong>B组：</strong>10.0.0.x → ws1 NAT → 线路A</p></div>
<div><h3>改造后</h3>
<pre class="topo">[线路A]--GE0/0/0==桥==GE0/0/1--[Sw-A]-- VLAN192 ws1~ws8(不动)
[线路B]--XGE0/0/0(SNAT)-- GE0/0/7(10.0.0.254)--[Sw-B]-- VLAN10 ws9~ws20</pre>
<p><strong>A组：</strong>不变</p>
<p><strong>B组：</strong>10.0.0.x → 10.0.0.254 → SNAT → 线路B</p></div>
</div>
<p class="note">防火墙<strong>混合模式</strong>：GE0/0/0+1 交换透传 A 组；XGE+GE7 路由服务 B 组。</p>
</section>
<section id="lines">
<h2>3. 线路 A / B</h2>
<div class="table-wrap"><table>
<thead><tr><th>对比项</th><th>线路 A（不动）</th><th>线路 B（新增）</th></tr></thead>
<tbody>
<tr><td>防火墙口</td><td>GE0/0/0</td><td>XGE0/0/0</td></tr>
<tr><td>模式</td><td>交换 VLAN1</td><td>路由 WAN</td></tr>
<tr><td>配对</td><td>GE0/0/1 → Sw-A</td><td>GE0/0/7 → Sw-B</td></tr>
<tr><td>WAN IP</td><td>无</td><td class="tbd">&lt;线路B公网IP/掩码&gt;</td></tr>
<tr><td>运营商网关</td><td>各机公网网关</td><td class="tbd">&lt;线路B运营商网关&gt;</td></tr>
<tr class="new"><td>LAN IP</td><td>—</td><td class="ip"><strong>10.0.0.254/24</strong></td></tr>
<tr><td>服务器</td><td>ws1~ws8</td><td>ws9~ws20</td></tr>
<tr><td>NAT</td><td>无</td><td>SNAT 10.0.0.0/24</td></tr>
</tbody></table></div>
</section>
<section id="vlan">
<h2>4. VLAN 划分</h2>
<div class="table-wrap"><table>
<thead><tr><th>VLAN</th><th>网段</th><th>改造前网关</th><th>改造后网关</th><th>成员</th></tr></thead>
<tbody>
<tr class="unchanged"><td>VLAN 1</td><td>无三层</td><td>—</td><td>—</td><td>GE0/0/0 ↔ GE0/0/1 ↔ Sw-A</td></tr>
<tr class="unchanged"><td>VLAN 192</td><td>公网 IP</td><td>各机公网网关</td><td><strong>不变</strong></td><td>ws1~ws8 网卡1</td></tr>
<tr class="changed"><td>VLAN10</td><td class="ip">10.0.0.0/24</td><td class="ip">10.0.0.11</td><td class="ip"><strong>10.0.0.254</strong></td><td>ws9~ws20 + Sw-B</td></tr>
</tbody></table></div>
</section>
<section id="cabling">
<h2>5. 物理接线</h2>
<h3>改造前</h3>
<div class="table-wrap"><table>
<thead><tr><th>本端</th><th>端口</th><th>对端</th><th>用途</th></tr></thead>
<tbody>
<tr><td>运营商A</td><td>—</td><td>GE0/0/0</td><td>线路A</td></tr>
<tr><td>USG</td><td>GE0/0/1</td><td>Sw-A</td><td>透明桥</td></tr>
<tr><td>交换机</td><td>Access</td><td>ws1~ws8 网卡1</td><td>VLAN192</td></tr>
<tr><td>交换机</td><td>Access</td><td>ws9~ws20</td><td>VLAN10</td></tr>
<tr><td>交换机</td><td>Access</td><td>ws1 网卡2</td><td>10.0.0.11 NAT</td></tr>
<tr class="unchanged"><td>USG</td><td>XGE0/0/0、GE0/0/7</td><td>未接</td><td>空闲</td></tr>
</tbody></table></div>
<h3>改造后</h3>
<div class="table-wrap"><table>
<thead><tr><th>本端</th><th>端口</th><th>对端</th><th>变更</th></tr></thead>
<tbody>
<tr class="unchanged"><td>运营商A → GE0/0/0</td><td colspan="2">不变</td><td>否</td></tr>
<tr class="unchanged"><td>GE0/0/1 → Sw-A</td><td colspan="2">不变</td><td>否</td></tr>
<tr class="new"><td>运营商B 光纤</td><td>XGE0/0/0</td><td>—</td><td><strong>新增</strong></td></tr>
<tr class="new"><td>GE0/0/7</td><td>Sw-B</td><td>VLAN10</td><td><strong>新增</strong></td></tr>
</tbody></table></div>
</section>
<section id="firewall">
<h2>6. 防火墙接口</h2>
<div class="table-wrap"><table>
<thead><tr><th>接口</th><th>改造前</th><th>改造后</th><th>IP</th><th>变更</th></tr></thead>
<tbody>
<tr class="unchanged"><td>GE0/0/0</td><td>交换VLAN1</td><td>同左</td><td>无</td><td>否</td></tr>
<tr class="unchanged"><td>GE0/0/1</td><td>交换VLAN1</td><td>同左</td><td>无</td><td>否</td></tr>
<tr class="new"><td>XGE0/0/0</td><td>空闲</td><td>路由WAN</td><td class="tbd">&lt;线路B公网IP&gt;</td><td><strong>新增</strong></td></tr>
<tr class="new"><td>GE0/0/7</td><td>空闲</td><td>路由LAN</td><td class="ip"><strong>10.0.0.254/24</strong></td><td><strong>新增</strong></td></tr>
</tbody></table></div>
<details><summary>防火墙配置摘要</summary>
<pre>interface XGigabitEthernet0/0/0
 undo portswitch
 ip address &lt;线路B公网IP&gt; &lt;掩码&gt;
interface GigabitEthernet0/0/7
 undo portswitch
 ip address 10.0.0.254 255.255.255.0
# SNAT 10.0.0.0/24 egress XGE0/0/0</pre></details>
</section>
<section id="switch">
<h2>7. 交换机端口</h2>
<div class="table-wrap"><table>
<thead><tr><th>端口</th><th>模式</th><th>VLAN</th><th>接入</th><th>变更</th></tr></thead>
<tbody>
<tr class="unchanged"><td>Sw-A</td><td>Access/Trunk</td><td>VLAN1</td><td>GE0/0/1</td><td>不动</td></tr>
<tr class="unchanged"><td>A组口</td><td>Access</td><td>192</td><td>ws1~ws8 网卡1</td><td>不动</td></tr>
<tr class="unchanged"><td>B组口</td><td>Access</td><td>VLAN10</td><td>ws9~ws20</td><td>不动</td></tr>
<tr class="changed"><td>ws1网卡2</td><td>Access</td><td>VLAN10</td><td>ws1</td><td>释放IP</td></tr>
<tr class="new"><td><strong>Sw-B</strong></td><td>Access</td><td>VLAN10</td><td><strong>GE0/0/7</strong></td><td><strong>新增</strong></td></tr>
</tbody></table></div>
</section>
<section id="ipalloc">
<h2>8. 10.0.0.0/24 IP 分配</h2>
<div class="table-wrap"><table>
<thead><tr><th>IP</th><th>设备</th><th>掩码</th><th>改造前</th><th>改造后</th><th>变更</th></tr></thead>
<tbody>
<tr class="new"><td class="ip"><strong>10.0.0.254</strong></td><td>USG GE0/0/7</td><td>/24</td><td>—</td><td><strong>B组新网关</strong></td><td>新增</td></tr>
<tr class="changed"><td class="ip">10.0.0.11</td><td>ws1 网卡2</td><td>/24</td><td>NAT网关</td><td>释放</td><td>下线</td></tr>
<tr class="changed"><td class="ip">10.0.0.12</td><td>ws9</td><td>/24</td><td>网关→11</td><td>网关→254</td><td>改网关</td></tr>
<tr class="changed"><td class="ip">10.0.0.13</td><td>ws10</td><td>/24</td><td>网关→11</td><td>网关→254</td><td>改网关</td></tr>
<tr class="changed"><td class="ip">10.0.0.14</td><td>ws11</td><td>/24</td><td>网关→11</td><td>网关→254</td><td>改网关</td></tr>
<tr class="changed"><td class="ip">10.0.0.15</td><td>ws12</td><td>/24</td><td>网关→11</td><td>网关→254</td><td>改网关</td></tr>
<tr class="changed"><td class="ip">10.0.0.16</td><td>ws13</td><td>/24</td><td>网关→11</td><td>网关→254</td><td>改网关</td></tr>
<tr class="changed"><td class="ip">10.0.0.17</td><td>ws14</td><td>/24</td><td>网关→11</td><td>网关→254</td><td>改网关</td></tr>
<tr class="changed"><td class="ip">10.0.0.18</td><td>ws15</td><td>/24</td><td>网关→11</td><td>网关→254</td><td>改网关</td></tr>
<tr class="changed"><td class="ip">10.0.0.19</td><td>ws16</td><td>/24</td><td>网关→11</td><td>网关→254</td><td>改网关</td></tr>
<tr class="changed"><td class="ip">10.0.0.20</td><td>ws17</td><td>/24</td><td>网关→11</td><td>网关→254</td><td>改网关</td></tr>
<tr class="changed"><td class="ip">10.0.0.21</td><td>ws18</td><td>/24</td><td>网关→11</td><td>网关→254</td><td>改网关</td></tr>
<tr class="changed"><td class="ip">10.0.0.22</td><td>ws19</td><td>/24</td><td>网关→11</td><td>网关→254</td><td>改网关</td></tr>
<tr class="changed"><td class="ip">10.0.0.23</td><td>ws20</td><td>/24</td><td>网关→11</td><td>网关→254</td><td>改网关</td></tr>
</tbody></table></div>
<p class="note">10.0.0.12~23 为示例，请按现网核对。</p>
</section>
<section id="servers">
<h2>9. 服务器清单 ws1~ws20</h2>
<h3>A 组（VLAN192 · 不改）</h3>
<div class="table-wrap"><table>
<thead><tr><th>主机</th><th>网卡</th><th>VLAN</th><th>IP</th><th>掩码</th><th>网关</th><th>DNS</th><th>出网</th><th>操作</th></tr></thead>
<tbody>
<tr class="unchanged"><td>ws1</td><td>网卡1</td><td>192</td><td class="tbd">&lt;公网IP-1&gt;</td><td class="tbd">&lt;掩码&gt;</td><td class="tbd">&lt;网关&gt;</td><td class="tbd">&lt;DNS&gt;</td><td>线路A</td><td>不改</td></tr>
<tr class="changed"><td>ws1</td><td>网卡2</td><td>10</td><td class="ip">10.0.0.11</td><td>/24</td><td>—</td><td>—</td><td>NAT</td><td>释放</td></tr>
<tr class="unchanged"><td>ws2</td><td>网卡1</td><td>192</td><td class="tbd">&lt;公网IP-2&gt;</td><td class="tbd">&lt;掩码&gt;</td><td class="tbd">&lt;网关&gt;</td><td class="tbd">&lt;DNS&gt;</td><td>线路A</td><td>不改</td></tr>
<tr class="unchanged"><td>ws3</td><td>网卡1</td><td>192</td><td class="tbd">&lt;公网IP-3&gt;</td><td class="tbd">&lt;掩码&gt;</td><td class="tbd">&lt;网关&gt;</td><td class="tbd">&lt;DNS&gt;</td><td>线路A</td><td>不改</td></tr>
<tr class="unchanged"><td>ws4</td><td>网卡1</td><td>192</td><td class="tbd">&lt;公网IP-4&gt;</td><td class="tbd">&lt;掩码&gt;</td><td class="tbd">&lt;网关&gt;</td><td class="tbd">&lt;DNS&gt;</td><td>线路A</td><td>不改</td></tr>
<tr class="unchanged"><td>ws5</td><td>网卡1</td><td>192</td><td class="tbd">&lt;公网IP-5&gt;</td><td class="tbd">&lt;掩码&gt;</td><td class="tbd">&lt;网关&gt;</td><td class="tbd">&lt;DNS&gt;</td><td>线路A</td><td>不改</td></tr>
<tr class="unchanged"><td>ws6</td><td>网卡1</td><td>192</td><td class="tbd">&lt;公网IP-6&gt;</td><td class="tbd">&lt;掩码&gt;</td><td class="tbd">&lt;网关&gt;</td><td class="tbd">&lt;DNS&gt;</td><td>线路A</td><td>不改</td></tr>
<tr class="unchanged"><td>ws7</td><td>网卡1</td><td>192</td><td class="tbd">&lt;公网IP-7&gt;</td><td class="tbd">&lt;掩码&gt;</td><td class="tbd">&lt;网关&gt;</td><td class="tbd">&lt;DNS&gt;</td><td>线路A</td><td>不改</td></tr>
<tr class="unchanged"><td>ws8</td><td>网卡1</td><td>192</td><td class="tbd">&lt;公网IP-8&gt;</td><td class="tbd">&lt;掩码&gt;</td><td class="tbd">&lt;网关&gt;</td><td class="tbd">&lt;DNS&gt;</td><td>线路A</td><td>不改</td></tr>
</tbody></table></div>
<h3>B 组（VLAN10 · 只改网关）</h3>
<div class="table-wrap"><table>
<thead><tr><th>主机</th><th>IP</th><th>掩码</th><th>改造前网关</th><th>改造后网关</th><th>出网</th><th>操作</th></tr></thead>
<tbody>
<tr class="changed"><td>ws9</td><td class="ip">10.0.0.12</td><td>/24</td><td class="ip">10.0.0.11</td><td class="ip"><strong>10.0.0.254</strong></td><td>线路B</td><td>改GATEWAY</td></tr>
<tr class="changed"><td>ws10</td><td class="ip">10.0.0.13</td><td>/24</td><td class="ip">10.0.0.11</td><td class="ip"><strong>10.0.0.254</strong></td><td>线路B</td><td>改GATEWAY</td></tr>
<tr class="changed"><td>ws11</td><td class="ip">10.0.0.14</td><td>/24</td><td class="ip">10.0.0.11</td><td class="ip"><strong>10.0.0.254</strong></td><td>线路B</td><td>改GATEWAY</td></tr>
<tr class="changed"><td>ws12</td><td class="ip">10.0.0.15</td><td>/24</td><td class="ip">10.0.0.11</td><td class="ip"><strong>10.0.0.254</strong></td><td>线路B</td><td>改GATEWAY</td></tr>
<tr class="changed"><td>ws13</td><td class="ip">10.0.0.16</td><td>/24</td><td class="ip">10.0.0.11</td><td class="ip"><strong>10.0.0.254</strong></td><td>线路B</td><td>改GATEWAY</td></tr>
<tr class="changed"><td>ws14</td><td class="ip">10.0.0.17</td><td>/24</td><td class="ip">10.0.0.11</td><td class="ip"><strong>10.0.0.254</strong></td><td>线路B</td><td>改GATEWAY</td></tr>
<tr class="changed"><td>ws15</td><td class="ip">10.0.0.18</td><td>/24</td><td class="ip">10.0.0.11</td><td class="ip"><strong>10.0.0.254</strong></td><td>线路B</td><td>改GATEWAY</td></tr>
<tr class="changed"><td>ws16</td><td class="ip">10.0.0.19</td><td>/24</td><td class="ip">10.0.0.11</td><td class="ip"><strong>10.0.0.254</strong></td><td>线路B</td><td>改GATEWAY</td></tr>
<tr class="changed"><td>ws17</td><td class="ip">10.0.0.20</td><td>/24</td><td class="ip">10.0.0.11</td><td class="ip"><strong>10.0.0.254</strong></td><td>线路B</td><td>改GATEWAY</td></tr>
<tr class="changed"><td>ws18</td><td class="ip">10.0.0.21</td><td>/24</td><td class="ip">10.0.0.11</td><td class="ip"><strong>10.0.0.254</strong></td><td>线路B</td><td>改GATEWAY</td></tr>
<tr class="changed"><td>ws19</td><td class="ip">10.0.0.22</td><td>/24</td><td class="ip">10.0.0.11</td><td class="ip"><strong>10.0.0.254</strong></td><td>线路B</td><td>改GATEWAY</td></tr>
<tr class="changed"><td>ws20</td><td class="ip">10.0.0.23</td><td>/24</td><td class="ip">10.0.0.11</td><td class="ip"><strong>10.0.0.254</strong></td><td>线路B</td><td>改GATEWAY</td></tr>
</tbody></table></div>
</section>
<section id="changes">
<h2>10. 配置变更与割接</h2>
<div class="table-wrap"><table>
<thead><tr><th>对象</th><th>操作</th></tr></thead>
<tbody>
<tr class="unchanged"><td>线路A、GE0/0/0/1、Sw-A、VLAN192、ws1~ws8</td><td><strong>不改</strong></td></tr>
<tr class="new"><td>线路B、XGE、GE7、Sw-B</td><td>新接线+新配置</td></tr>
<tr class="changed"><td>ws9~ws20</td><td>网关 10.0.0.11 → <strong>10.0.0.254</strong></td></tr>
</tbody></table></div>
<ol class="steps">
<li>准备：备份 ws1 NAT；记录实际 IP；获取线路 B 参数</li>
<li>预配：光纤接 XGE；GE7 接 Sw-B（VLAN10）</li>
<li>激活：启用接口；ping 10.0.0.254；验证 A 组</li>
<li>灰度：1~2 台 B 组改网关</li>
<li>批量：分 3~4 批切换</li>
<li>收尾：下线 ws1 NAT；更新本文档 IP</li>
</ol>
<p>回滚：单台改回 <code class="ip">10.0.0.11</code>；防火墙与 ws1 可并行。</p>
</section>
<section id="checklist">
<h2>11. 核对清单</h2>
<ul class="checklist">
<li>VLAN10 实际 VLAN ID</li>
<li>Sw-A / Sw-B 端口号</li>
<li>10.0.0.254 未占用</li>
<li>ws9~ws20 实际 IP</li>
<li>线路 B 公网 IP/掩码/网关/DNS</li>
<li>A 组各台公网 IP 填入第 9 节</li>
<li>ws1 DNAT 是否需迁防火墙</li>
<li>启用路由口后 A 组仍可达</li>
</ul>
</section>
<footer style="margin-top:3rem;padding-top:1rem;border-top:1px solid var(--border);color:var(--muted);font-size:.85rem">
<p>路径：d:/dev-works/nginx-logs/netdoc/机房网络网关迁移改造文档.html</p>
</footer>
</main>
</div>
</body>
</html>
```
