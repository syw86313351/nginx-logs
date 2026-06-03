const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  AlignmentType, HeadingLevel, BorderStyle, WidthType, ShadingType,
  VerticalAlign, LevelFormat, PageNumber, Header, Footer, PageBreak
} = require('docx');
const fs = require('fs');

const BLUE  = "1F497D";
const LBLUE = "DEEAF1";
const WHITE = "FFFFFF";
const GRAY  = "595959";
const YH    = "Microsoft YaHei";
const MONO  = "Courier New";

const bdr = (c="AAAAAA") => ({style:BorderStyle.SINGLE,size:1,color:c});
const bds = c => ({top:bdr(c),bottom:bdr(c),left:bdr(c),right:bdr(c)});
const cm  = {top:80,bottom:80,left:130,right:130};

const empty = () => new Paragraph({spacing:{before:40,after:40},children:[new TextRun("")]});

const h1 = t => new Paragraph({
  heading:HeadingLevel.HEADING_1, spacing:{before:400,after:120},
  children:[new TextRun({text:t,bold:true,size:28,font:YH,color:BLUE})]
});
const h2 = t => new Paragraph({
  heading:HeadingLevel.HEADING_2, spacing:{before:220,after:80},
  children:[new TextRun({text:t,bold:true,size:23,font:YH,color:"2E74B5"})]
});

const shot = label => new Table({
  width:{size:9360,type:WidthType.DXA}, columnWidths:[9360],
  rows:[new TableRow({children:[new TableCell({
    borders:bds("4472C4"), width:{size:9360,type:WidthType.DXA},
    shading:{fill:"F0F5FF",type:ShadingType.CLEAR},
    margins:{top:240,bottom:240,left:360,right:360},
    children:[
      new Paragraph({alignment:AlignmentType.CENTER,
        children:[new TextRun({text:"[ 截图 ]",size:20,font:YH,color:"AAAAAA",italics:true})]}),
      new Paragraph({alignment:AlignmentType.CENTER,spacing:{before:30},
        children:[new TextRun({text:label,size:20,font:YH,color:"2E74B5"})]}),
    ]
  })]})],
});

// 多行文字单元格
const mcell = (lines, w, ri, bold=false) => new TableCell({
  borders:bds("CCCCCC"), width:{size:w,type:WidthType.DXA},
  shading:{fill:ri%2===0?LBLUE:WHITE,type:ShadingType.CLEAR}, margins:cm,
  verticalAlign:VerticalAlign.CENTER,
  children: lines.map((t,i)=>new Paragraph({
    spacing:{before: i===0?0:20, after:0},
    children:[new TextRun({text:t,size:20,font:t.startsWith("1")||t.startsWith("6")||t.startsWith("1")? MONO:YH,
      font:YH, bold: bold&&i===0, color:"000000"})]
  }))
});

// 接口规划表（IP列多行）
const colW = [1300,900,1100,1600,1100,900,2160,1300];
const total = colW.reduce((a,b)=>a+b,0);

const hdrRow = new TableRow({tableHeader:true, children:[
  "接口","类型","工作模式","描述","安全域","模式","IP 地址","备注"
].map((h,i)=>new TableCell({
  borders:bds(BLUE), width:{size:colW[i],type:WidthType.DXA},
  shading:{fill:BLUE,type:ShadingType.CLEAR}, margins:cm,
  verticalAlign:VerticalAlign.CENTER,
  children:[new Paragraph({alignment:AlignmentType.CENTER,
    children:[new TextRun({text:h,bold:true,size:19,font:YH,color:WHITE})]})]
}))});

const rows = [
  // GE0/0/0
  ["GE0/0/0","电口","二层","公网出口","untrust","交换",["-"],"极云（1）"],
  // GE0/0/1
  ["GE0/0/1","电口","二层","内网交换机1","trust","交换",["-"],"千兆交换机\nVLAN 1"],
  // GE0/0/2
  ["GE0/0/2","电口","三层","公网出口","untrust","路由",
    ["IP：182.140.146.128","掩码：255.255.255.0","网关：182.140.146.129","DNS：61.139.2.69"],"极云（2）"],
  // GE0/0/3
  ["GE0/0/3","电口","三层","内网交换机2","trust","路由",
    ["IP：10.0.0.254","掩码：255.255.255.0"],"网关"],
  // XGE0/0/0
  ["XGE0/0/0","光口","三层","公网出口","untrust","路由",
    ["IP：182.140.240.121","掩码：255.255.255.128","网关：182.140.240.1","DNS：61.139.2.69"],"西信（新线路）"],
  // MEth0/0/0
  ["MEth0/0/0","电口","三层","带外管理口","trust","静态",["192.168.10.210"],"设备管理专用"],
];

const dataRows = rows.map((row,ri)=>{
  const ipLines = Array.isArray(row[6]) ? row[6] : [row[6]];
  const beiZhu  = row[7].split("\n");
  return new TableRow({children:[
    mcell([row[0]], colW[0], ri, true),
    mcell([row[1]], colW[1], ri),
    mcell([row[2]], colW[2], ri),
    mcell([row[3]], colW[3], ri),
    mcell([row[4]], colW[4], ri),
    mcell([row[5]], colW[5], ri),
    mcell(ipLines,  colW[6], ri),
    mcell(beiZhu,   colW[7], ri),
  ]});
});

const ifTable = new Table({
  width:{size:total,type:WidthType.DXA}, columnWidths:colW,
  rows:[hdrRow,...dataRows]
});

const body = [

  // 封面
  new Paragraph({alignment:AlignmentType.CENTER, spacing:{before:800,after:160},
    children:[new TextRun({text:"华为 USG6305E 防火墙",bold:true,size:52,font:YH,color:"17375E"})]}),
  new Paragraph({alignment:AlignmentType.CENTER, spacing:{before:80,after:80},
    children:[new TextRun({text:"双出口配置实施步骤",bold:true,size:38,font:YH,color:BLUE})]}),
  new Paragraph({alignment:AlignmentType.CENTER, spacing:{before:80,after:1400},
    children:[new TextRun({text:"2026-06-03",size:20,font:YH,color:GRAY})]}),

  // 一、接口规划
  h1("一、接口规划"),
  ifTable,
  empty(),
  shot("截图：Web 管理界面接口列表"),
  empty(),

  // 二、接口配置
  new Paragraph({children:[new PageBreak()]}),
  h1("二、接口配置"),

  h2("2.1 GE0/0/0 — 公网出口（极云1，二层交换）"),
  empty(), shot("截图：GE0/0/0 接口配置"), empty(),

  h2("2.2 GE0/0/1 — 内网交换机1（二层交换，VLAN 1）"),
  empty(), shot("截图：GE0/0/1 接口配置"), empty(),

  h2("2.3 GE0/0/2 — 公网出口（极云2，IP 182.140.146.128）"),
  empty(), shot("截图：GE0/0/2 接口配置，确认 IP / 网关"), empty(),

  h2("2.4 GE0/0/3 — 内网交换机2（网关 10.0.0.254）"),
  empty(), shot("截图：GE0/0/3 接口配置，确认 IP"), empty(),

  h2("2.5 XGE0/0/0 — 公网出口（西信，IP 182.140.240.121）"),
  empty(), shot("截图：XGE0/0/0 接口配置，确认 IP / 网关"), empty(),

  h2("2.6 MEth0/0/0 — 带外管理口（192.168.10.210）"),
  empty(), shot("截图：MEth0/0/0 接口配置"), empty(),

  // 三、安全域
  new Paragraph({children:[new PageBreak()]}),
  h1("三、安全域绑定"),

  h2("3.1 Trust 域"),
  empty(), shot("截图：Trust 域绑定接口（GE0/0/1 / GE0/0/3 / MEth0/0/0）"), empty(),

  h2("3.2 Untrust 域"),
  empty(), shot("截图：Untrust 域绑定接口（GE0/0/0 / GE0/0/2 / XGE0/0/0）"), empty(),

  // 四、路由
  new Paragraph({children:[new PageBreak()]}),
  h1("四、路由配置"),

  h2("4.1 主路由 — XGE0/0/0 西信（preference 60）"),
  empty(), shot("截图：主路由配置，下一跳 182.140.240.1"), empty(),

  h2("4.2 备路由1 — GE0/0/2 极云2（preference 80）"),
  empty(), shot("截图：备路由1 配置，下一跳 182.140.146.129"), empty(),

  h2("4.3 备路由2 — GE0/0/0 极云1（preference 100）"),
  empty(), shot("截图：备路由2 配置"), empty(),

  h2("4.4 验证路由表"),
  empty(), shot("截图：display ip routing-table"), empty(),

  // 五、NAT
  new Paragraph({children:[new PageBreak()]}),
  h1("五、NAT 配置"),

  h2("5.1 XGE0/0/0 出口 NAT（西信）"),
  empty(), shot("截图：NAT_XSX 规则"), empty(),

  h2("5.2 GE0/0/2 出口 NAT（极云2）"),
  empty(), shot("截图：NAT_JY2 规则"), empty(),

  h2("5.3 GE0/0/0 出口 NAT（极云1）"),
  empty(), shot("截图：NAT_JY1 规则"), empty(),

  h2("5.4 验证 NAT 策略"),
  empty(), shot("截图：display nat-policy rule all"), empty(),

  // 六、安全策略
  new Paragraph({children:[new PageBreak()]}),
  h1("六、防火墙安全策略"),

  h2("6.1 内网访问公网（Trust → Untrust）"),
  empty(), shot("截图：TRUST_TO_UNTRUST 策略"), empty(),

  h2("6.2 内网管理设备（Trust → Local）"),
  empty(), shot("截图：TRUST_TO_LOCAL 策略"), empty(),

  h2("6.3 验证安全策略"),
  empty(), shot("截图：display security-policy rule all"), empty(),

  // 七、保存
  h1("七、保存配置"),
  empty(), shot("截图：save 执行成功"), empty(),
];

const doc = new Document({
  styles:{
    default:{document:{run:{font:YH,size:22}}},
    paragraphStyles:[
      {id:"Heading1",name:"Heading 1",basedOn:"Normal",next:"Normal",quickFormat:true,
        run:{size:28,bold:true,font:YH,color:BLUE},
        paragraph:{spacing:{before:400,after:120},outlineLevel:0}},
      {id:"Heading2",name:"Heading 2",basedOn:"Normal",next:"Normal",quickFormat:true,
        run:{size:23,bold:true,font:YH,color:"2E74B5"},
        paragraph:{spacing:{before:220,after:80},outlineLevel:1}},
    ]
  },
  sections:[{
    properties:{page:{
      size:{width:12240,height:15840},
      margin:{top:1260,right:1080,bottom:1260,left:1080}
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
      alignment:AlignmentType.CENTER,spacing:{before:80},
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
