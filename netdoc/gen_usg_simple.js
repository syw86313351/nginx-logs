const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  AlignmentType, HeadingLevel, BorderStyle, WidthType, ShadingType,
  VerticalAlign, LevelFormat, PageNumber, Header, Footer, PageBreak
} = require('docx');
const fs = require('fs');

const BLUE   = "1F497D";
const LBBLUE = "DEEAF1";
const WHITE  = "FFFFFF";
const GRAY   = "595959";
const CODBG  = "F2F2F2";
const YH     = "Microsoft YaHei";
const MONO   = "Courier New";

const bdr = (c="AAAAAA") => ({style:BorderStyle.SINGLE,size:1,color:c});
const bds = c => ({top:bdr(c),bottom:bdr(c),left:bdr(c),right:bdr(c)});
const cm  = {top:80,bottom:80,left:120,right:120};

const empty = () => new Paragraph({spacing:{before:40,after:40},children:[new TextRun("")]});

const h1 = t => new Paragraph({
  heading:HeadingLevel.HEADING_1, spacing:{before:400,after:140},
  children:[new TextRun({text:t,bold:true,size:28,font:YH,color:BLUE})]
});
const h2 = t => new Paragraph({
  heading:HeadingLevel.HEADING_2, spacing:{before:240,after:80},
  children:[new TextRun({text:t,bold:true,size:23,font:YH,color:"2E74B5"})]
});
const p = (t,opts={}) => new Paragraph({
  spacing:{before:50,after:50},
  children:[new TextRun({text:t,size:22,font:YH,...opts})]
});

// CLI 命令块
const cli = lines => {
  if(typeof lines==="string") lines=[lines];
  return lines.map(t=>new Paragraph({
    spacing:{before:16,after:16}, indent:{left:440},
    shading:{fill:CODBG,type:ShadingType.CLEAR},
    children:[new TextRun({text:t,size:20,font:MONO,color:"1A3A5C"})]
  }));
};

// 注意框
const warn = t => new Paragraph({
  spacing:{before:80,after:80}, indent:{left:300,right:300},
  shading:{fill:"FFFCE6",type:ShadingType.CLEAR},
  border:{left:{style:BorderStyle.SINGLE,size:8,color:"FFC000",space:6}},
  children:[new TextRun({text:"⚠ "+t,size:20,font:YH,color:"7F5200"})]
});

// 截图占位框
const shot = label => new Table({
  width:{size:9360,type:WidthType.DXA}, columnWidths:[9360],
  rows:[new TableRow({children:[new TableCell({
    borders:bds("4472C4"), width:{size:9360,type:WidthType.DXA},
    shading:{fill:"F0F5FF",type:ShadingType.CLEAR},
    margins:{top:260,bottom:260,left:360,right:360},
    children:[
      new Paragraph({alignment:AlignmentType.CENTER,
        children:[new TextRun({text:"[ 截图 ]",size:20,font:YH,color:"AAAAAA",italics:true})]}),
      new Paragraph({alignment:AlignmentType.CENTER,spacing:{before:40},
        children:[new TextRun({text:label,size:20,font:YH,color:"2E74B5"})]}),
    ]
  })]})],
});

// 普通表格
const tbl = (headers,rows,colW) => {
  const total=colW.reduce((a,b)=>a+b,0);
  return new Table({
    width:{size:total,type:WidthType.DXA}, columnWidths:colW,
    rows:[
      new TableRow({tableHeader:true, children:headers.map((h,i)=>new TableCell({
        borders:bds(BLUE), width:{size:colW[i],type:WidthType.DXA},
        shading:{fill:BLUE,type:ShadingType.CLEAR}, margins:cm,
        children:[new Paragraph({alignment:AlignmentType.CENTER,
          children:[new TextRun({text:h,bold:true,size:20,font:YH,color:WHITE})]})]
      }))}),
      ...rows.map((row,ri)=>new TableRow({children:row.map((c,ci)=>new TableCell({
        borders:bds("CCCCCC"), width:{size:colW[ci],type:WidthType.DXA},
        shading:{fill:ri%2===0?LBBLUE:WHITE,type:ShadingType.CLEAR}, margins:cm,
        children:[new Paragraph({children:[new TextRun({text:c,size:20,font:YH})]})]
      }))}))
    ]
  });
};

const body = [

  // 封面
  new Paragraph({alignment:AlignmentType.CENTER, spacing:{before:800,after:200},
    children:[new TextRun({text:"华为 USG6305E 防火墙",bold:true,size:52,font:YH,color:"17375E"})]}),
  new Paragraph({alignment:AlignmentType.CENTER, spacing:{before:80,after:80},
    children:[new TextRun({text:"双出口配置实施步骤",bold:true,size:38,font:YH,color:BLUE})]}),
  new Paragraph({alignment:AlignmentType.CENTER, spacing:{before:80,after:80},
    children:[new TextRun({text:"基于 192.168.254.0/24 网段",size:22,font:YH,color:GRAY})]}),
  new Paragraph({alignment:AlignmentType.CENTER, spacing:{before:120,after:1400},
    children:[new TextRun({text:"2026-06-03",size:20,font:YH,color:GRAY})]}),

  // 一、规划
  h1("一、规划"),
  tbl(
    ["接口","角色","安全域","IP 地址"],
    [
      ["GE1/0/0","LAN（内网）","Trust",   "192.168.254.1/24"],
      ["GE1/0/1","WAN1（主出口）","Untrust","运营商分配（ISP1）"],
      ["GE1/0/2","WAN2（备出口）","Untrust","运营商分配（ISP2）"],
    ],
    [2400,2400,1800,2760]
  ),
  empty(),

  // 二、接口配置
  new Paragraph({children:[new PageBreak()]}),
  h1("二、接口配置"),

  h2("2.1 LAN 口 GE1/0/0"),
  ...cli([
    "[USG6305E] interface GigabitEthernet 1/0/0",
    "[USG6305E-GigabitEthernet1/0/0] description LAN-Trust",
    "[USG6305E-GigabitEthernet1/0/0] ip address 192.168.254.1 255.255.255.0",
    "[USG6305E-GigabitEthernet1/0/0] service-manage https permit",
    "[USG6305E-GigabitEthernet1/0/0] service-manage ssh permit",
    "[USG6305E-GigabitEthernet1/0/0] service-manage ping permit",
    "[USG6305E-GigabitEthernet1/0/0] quit",
  ]),
  empty(),
  shot("截图：display interface GigabitEthernet 1/0/0 — 确认 IP 及 UP 状态"),
  empty(),

  h2("2.2 WAN1 主出口 GE1/0/1"),
  ...cli([
    "[USG6305E] interface GigabitEthernet 1/0/1",
    "[USG6305E-GigabitEthernet1/0/1] description WAN1-ISP1",
    "[USG6305E-GigabitEthernet1/0/1] ip address <ISP1_IP> <ISP1_MASK>",
    "[USG6305E-GigabitEthernet1/0/1] quit",
  ]),
  empty(),
  shot("截图：display interface GigabitEthernet 1/0/1 — 确认 IP 及 UP 状态"),
  empty(),

  h2("2.3 WAN2 备出口 GE1/0/2"),
  ...cli([
    "[USG6305E] interface GigabitEthernet 1/0/2",
    "[USG6305E-GigabitEthernet1/0/2] description WAN2-ISP2",
    "[USG6305E-GigabitEthernet1/0/2] ip address <ISP2_IP> <ISP2_MASK>",
    "[USG6305E-GigabitEthernet1/0/2] quit",
  ]),
  empty(),
  shot("截图：display interface GigabitEthernet 1/0/2 — 确认 IP 及 UP 状态"),
  empty(),
  p("验证所有接口："),
  ...cli(["[USG6305E] display interface brief"]),
  empty(),
  shot("截图：display interface brief — 三个接口汇总状态"),
  empty(),

  // 三、安全域
  new Paragraph({children:[new PageBreak()]}),
  h1("三、安全域配置"),

  h2("3.1 LAN 口加入 Trust 域"),
  ...cli([
    "[USG6305E] firewall zone trust",
    "[USG6305E-zone-trust] add interface GigabitEthernet 1/0/0",
    "[USG6305E-zone-trust] quit",
  ]),
  empty(),

  h2("3.2 两条 WAN 口加入 Untrust 域"),
  ...cli([
    "[USG6305E] firewall zone untrust",
    "[USG6305E-zone-untrust] add interface GigabitEthernet 1/0/1",
    "[USG6305E-zone-untrust] add interface GigabitEthernet 1/0/2",
    "[USG6305E-zone-untrust] quit",
  ]),
  empty(),
  p("验证："),
  ...cli(["[USG6305E] display zone"]),
  empty(),
  shot("截图：display zone — 确认各接口归属正确的安全域"),
  empty(),

  // 四、路由
  new Paragraph({children:[new PageBreak()]}),
  h1("四、路由配置"),
  p("ISP1 主路由 preference 60（优先），ISP2 备路由 preference 80（次选），ISP1 故障时自动切换。"),
  empty(),

  h2("4.1 主路由（ISP1）"),
  ...cli([
    "[USG6305E] ip route-static 0.0.0.0 0.0.0.0 <ISP1_GW> preference 60",
  ]),
  empty(),

  h2("4.2 备路由（ISP2）"),
  ...cli([
    "[USG6305E] ip route-static 0.0.0.0 0.0.0.0 <ISP2_GW> preference 80",
  ]),
  empty(),
  p("验证："),
  ...cli(["[USG6305E] display ip routing-table"]),
  empty(),
  shot("截图：display ip routing-table — 确认两条默认路由及 preference 值"),
  empty(),

  // 五、NAT
  new Paragraph({children:[new PageBreak()]}),
  h1("五、NAT 配置"),
  p("内网 192.168.254.0/24 访问公网，两个 WAN 口分别配置 Easy IP。"),
  empty(),

  h2("5.1 WAN1 出口 NAT"),
  ...cli([
    "[USG6305E] nat-policy",
    "[USG6305E-policy-nat] rule name NAT_ISP1",
    "[USG6305E-policy-nat-rule-NAT_ISP1] source-zone trust",
    "[USG6305E-policy-nat-rule-NAT_ISP1] destination-zone untrust",
    "[USG6305E-policy-nat-rule-NAT_ISP1] source-address 192.168.254.0 24",
    "[USG6305E-policy-nat-rule-NAT_ISP1] egress-interface GigabitEthernet 1/0/1",
    "[USG6305E-policy-nat-rule-NAT_ISP1] action source-nat easy-ip",
    "[USG6305E-policy-nat-rule-NAT_ISP1] quit",
  ]),
  empty(),

  h2("5.2 WAN2 出口 NAT"),
  ...cli([
    "[USG6305E-policy-nat] rule name NAT_ISP2",
    "[USG6305E-policy-nat-rule-NAT_ISP2] source-zone trust",
    "[USG6305E-policy-nat-rule-NAT_ISP2] destination-zone untrust",
    "[USG6305E-policy-nat-rule-NAT_ISP2] source-address 192.168.254.0 24",
    "[USG6305E-policy-nat-rule-NAT_ISP2] egress-interface GigabitEthernet 1/0/2",
    "[USG6305E-policy-nat-rule-NAT_ISP2] action source-nat easy-ip",
    "[USG6305E-policy-nat-rule-NAT_ISP2] quit",
    "[USG6305E-policy-nat] quit",
  ]),
  empty(),
  p("验证："),
  ...cli(["[USG6305E] display nat-policy rule all"]),
  empty(),
  shot("截图：display nat-policy rule all — 两条 NAT 规则均为 Enable"),
  empty(),

  // 六、防火墙安全策略
  new Paragraph({children:[new PageBreak()]}),
  h1("六、防火墙安全策略"),
  tbl(
    ["策略名","源域","目的域","动作","说明"],
    [
      ["TRUST_TO_UNTRUST","Trust",  "Untrust","permit","内网访问公网"],
      ["TRUST_TO_LOCAL",  "Trust",  "Local",  "permit","内网管理设备（SSH/HTTPS）"],
      ["LOCAL_TO_UNTRUST","Local",  "Untrust","permit","设备自身访问公网"],
    ],
    [2400,1400,1400,1200,3160]
  ),
  empty(),

  h2("6.1 内网访问公网"),
  ...cli([
    "[USG6305E] security-policy",
    "[USG6305E-policy-security] rule name TRUST_TO_UNTRUST",
    "[USG6305E-policy-security-rule-TRUST_TO_UNTRUST] source-zone trust",
    "[USG6305E-policy-security-rule-TRUST_TO_UNTRUST] destination-zone untrust",
    "[USG6305E-policy-security-rule-TRUST_TO_UNTRUST] source-address 192.168.254.0 24",
    "[USG6305E-policy-security-rule-TRUST_TO_UNTRUST] action permit",
    "[USG6305E-policy-security-rule-TRUST_TO_UNTRUST] quit",
  ]),
  empty(),

  h2("6.2 内网管理设备"),
  ...cli([
    "[USG6305E-policy-security] rule name TRUST_TO_LOCAL",
    "[USG6305E-policy-security-rule-TRUST_TO_LOCAL] source-zone trust",
    "[USG6305E-policy-security-rule-TRUST_TO_LOCAL] destination-zone local",
    "[USG6305E-policy-security-rule-TRUST_TO_LOCAL] source-address 192.168.254.0 24",
    "[USG6305E-policy-security-rule-TRUST_TO_LOCAL] service https",
    "[USG6305E-policy-security-rule-TRUST_TO_LOCAL] service ssh",
    "[USG6305E-policy-security-rule-TRUST_TO_LOCAL] service icmp",
    "[USG6305E-policy-security-rule-TRUST_TO_LOCAL] action permit",
    "[USG6305E-policy-security-rule-TRUST_TO_LOCAL] quit",
  ]),
  empty(),

  h2("6.3 设备自身访问公网"),
  ...cli([
    "[USG6305E-policy-security] rule name LOCAL_TO_UNTRUST",
    "[USG6305E-policy-security-rule-LOCAL_TO_UNTRUST] source-zone local",
    "[USG6305E-policy-security-rule-LOCAL_TO_UNTRUST] destination-zone untrust",
    "[USG6305E-policy-security-rule-LOCAL_TO_UNTRUST] action permit",
    "[USG6305E-policy-security-rule-LOCAL_TO_UNTRUST] quit",
    "[USG6305E-policy-security] quit",
  ]),
  empty(),
  p("验证："),
  ...cli(["[USG6305E] display security-policy rule all"]),
  empty(),
  shot("截图：display security-policy rule all — 三条策略均为 Enable"),
  empty(),

  // 七、保存
  h1("七、保存配置"),
  ...cli([
    "<USG6305E> save",
    "# 提示是否覆盖，输入 y 确认",
  ]),
  empty(),
  shot("截图：save 执行成功提示"),
  empty(),
];

const doc = new Document({
  numbering:{config:[{reference:"bullets",levels:[{
    level:0,format:LevelFormat.BULLET,text:"•",alignment:AlignmentType.LEFT,
    style:{paragraph:{indent:{left:720,hanging:360}}}
  }]}]},
  styles:{
    default:{document:{run:{font:YH,size:22}}},
    paragraphStyles:[
      {id:"Heading1",name:"Heading 1",basedOn:"Normal",next:"Normal",quickFormat:true,
        run:{size:28,bold:true,font:YH,color:BLUE},
        paragraph:{spacing:{before:400,after:140},outlineLevel:0}},
      {id:"Heading2",name:"Heading 2",basedOn:"Normal",next:"Normal",quickFormat:true,
        run:{size:23,bold:true,font:YH,color:"2E74B5"},
        paragraph:{spacing:{before:240,after:80},outlineLevel:1}},
    ]
  },
  sections:[{
    properties:{page:{
      size:{width:12240,height:15840},
      margin:{top:1260,right:1260,bottom:1260,left:1260}
    }},
    headers:{default:new Header({children:[new Paragraph({
      border:{bottom:{style:BorderStyle.SINGLE,size:6,color:BLUE,space:1}},
      spacing:{after:80},
      children:[
        new TextRun({text:"华为 USG6305E  双出口配置实施步骤",size:18,font:YH,color:GRAY}),
        new TextRun({text:"\t192.168.254.0/24",size:18,font:YH,color:GRAY})
      ],
      tabStops:[{type:"right",position:9720}]
    })]})},
    footers:{default:new Footer({children:[new Paragraph({
      border:{top:{style:BorderStyle.SINGLE,size:6,color:BLUE,space:1}},
      alignment:AlignmentType.CENTER, spacing:{before:80},
      children:[
        new TextRun({text:"第 ",size:18,font:YH,color:GRAY}),
        new TextRun({children:[PageNumber.CURRENT],size:18,font:YH,color:GRAY}),
        new TextRun({text:" 页",size:18,font:YH,color:GRAY})
      ]
    })]})},
    children:body
  }]
});

Packer.toBuffer(doc).then(buf=>{
  fs.writeFileSync("D:/dev-works/nginx-logs/netdoc/USG6305E_双出口配置实施步骤.docx",buf);
  console.log("Done.");
}).catch(e=>{console.error(e);process.exit(1);});
