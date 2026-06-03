const {
  Document, Packer, Paragraph, TextRun, AlignmentType,
  LevelFormat, BorderStyle, WidthType,
  Table, TableRow, TableCell, ShadingType
} = require('docx');
const fs = require('fs');

const FONT = "宋体";
const FONT_EN = "Courier New";
const SIZE_BODY = 24;   // 12pt
const SIZE_H1   = 36;   // 18pt 标题
const SIZE_H2   = 26;   // 13pt 章节标题

function p(children, opts = {}) {
  return new Paragraph({ children, ...opts });
}

function t(str, opts = {}) {
  return new TextRun({ text: str, font: FONT, size: SIZE_BODY, ...opts });
}

// IP 表格
const bd = { style: BorderStyle.SINGLE, size: 1, color: "CCCCCC" };
const borders = { top: bd, bottom: bd, left: bd, right: bd };

function ipTable(rows) {
  return new Table({
    width: { size: 8200, type: WidthType.DXA },
    columnWidths: [3400, 4800],
    rows: [
      // 表头
      new TableRow({
        tableHeader: true,
        children: [
          cell("IP 地址", 3400, "E8F0FE", true),
          cell("说明",    4800, "E8F0FE", true),
        ]
      }),
      ...rows.map(([ip, desc]) =>
        new TableRow({
          children: [
            cell(ip,   3400, "F8F8F8", false, FONT_EN),
            cell(desc, 4800, "FFFFFF", false),
          ]
        })
      )
    ]
  });
}

function cell(text, width, fill, bold, font) {
  return new TableCell({
    borders,
    width: { size: width, type: WidthType.DXA },
    margins: { top: 80, bottom: 80, left: 160, right: 160 },
    shading: { fill, type: ShadingType.CLEAR },
    children: [p([new TextRun({ text, font: font || FONT, size: SIZE_BODY, bold: !!bold })])]
  });
}

function sectionTitle(num, title) {
  return p([t(`${num}、${title}`, { bold: true, size: SIZE_H2 })], {
    spacing: { before: 160, after: 80 }
  });
}

function bodyPara(str, opts = {}) {
  return p([t(str)], {
    indent: { firstLine: 480 },
    spacing: { after: 100 },
    ...opts
  });
}

const doc = new Document({
  numbering: {
    config: [
      {
        reference: "bullet",
        levels: [{
          level: 0, format: LevelFormat.BULLET, text: "·",
          alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 720, hanging: 360 } } }
        }]
      }
    ]
  },
  styles: {
    default: { document: { run: { font: FONT, size: SIZE_BODY } } }
  },
  sections: [{
    properties: {
      page: {
        size: { width: 11906, height: 16838 },
        margin: { top: 1200, right: 1440, bottom: 1200, left: 1440 }
      }
    },
    children: [

      /* ── 标题 ── */
      p([t("关于出口网络IP地址调整及白名单配置的通知", { bold: true, size: SIZE_H1 })], {
        alignment: AlignmentType.CENTER,
        spacing: { before: 0, after: 240 }
      }),

      /* ── 分隔线 ── */
      p([], {
        border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: "3B82F6", space: 1 } },
        spacing: { after: 200 }
      }),

      /* ── 称呼 ── */
      p([t("各位同事及合作方：")], { spacing: { after: 120 } }),

      /* ── 引言 ── */
      bodyPara(
        "为提升网络服务质量与稳定性，我司计划对出口网络进行升级改造，实施主备双线路模式。" +
        "升级后，主线路出现故障时将自动切换至备用线路，有效保障业务连续性、降低单点故障风险。"
      ),
      bodyPara(
        "本次升级涉及出口公网IP地址变更，若您的系统配置了基于IP的访问控制策略，" +
        "请提前将以下IP地址加入白名单，以确保网络切换后业务正常运行。",
        { spacing: { after: 180 } }
      ),

      /* ── 一、出口IP ── */
      sectionTitle("一", "出口网络IP地址（Egress）"),
      ipTable([
        ["182.140.240.121", "主出口"],
        ["182.140.146.128", "备用出口"],
        ["182.140.146.150", "备用出口"],
      ]),

      p([], { spacing: { after: 100 } }),

      /* ── 二、入口IP ── */
      sectionTitle("二", "入口网络IP地址（Ingress）"),
      ipTable([
        ["47.93.176.227",  "入口节点 1"],
        ["8.148.150.96",   "入口节点 2"],
        ["47.100.55.110",  "入口节点 3"],
      ]),

      p([], { spacing: { after: 100 } }),

      /* ── 三、影响范围 ── */
      sectionTitle("三", "影响范围"),
      bodyPara("若系统存在基于IP的访问控制配置，请重点核查以下场景："),

      p([t("微信生态相关服务", { bold: true })], {
        indent: { left: 480 }, spacing: { before: 60, after: 40 }
      }),
      ...["微信支付", "微信公众号", "微信小程序", "微信开放平台相关接口"].map(s =>
        p([t(s)], { numbering: { reference: "bullet", level: 0 }, spacing: { after: 40 } })
      ),

      p([t("支付平台", { bold: true })], {
        indent: { left: 480 }, spacing: { before: 60, after: 40 }
      }),
      ...["支付宝支付", "其他第三方支付平台"].map(s =>
        p([t(s)], { numbering: { reference: "bullet", level: 0 }, spacing: { after: 40 } })
      ),

      p([], { spacing: { after: 100 } }),

      /* ── 四、工作要求 ── */
      sectionTitle("四", "工作要求"),
      bodyPara(
        "请在网络切换前完成上述IP地址的白名单配置及连通性验证。" +
        "未及时完成配置可能导致接口调用失败、支付异常、消息推送中断等问题，影响业务正常运行。"
      ),
      bodyPara(
        "具体切换时间将提前另行通知，请各部门相关技术人员尽快安排配置工作。",
        { spacing: { after: 240 } }
      ),

      /* ── 落款 ── */
      p([], {
        border: { top: { style: BorderStyle.SINGLE, size: 2, color: "CCCCCC", space: 1 } },
        spacing: { after: 120 }
      }),
      p([t("2026年6月3日")], {
        alignment: AlignmentType.RIGHT
      })
    ]
  }]
});

Packer.toBuffer(doc).then(buf => {
  fs.writeFileSync("关于出口网络IP地址调整及白名单配置的通知.docx", buf);
  console.log("Done.");
});
