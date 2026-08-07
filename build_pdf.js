const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const guideDir = path.join(__dirname, 'learning-guide');
const mdPath = path.join(guideDir, 'Excalidraw_AWS_Cloud_Engineering_Guide.md');
const htmlPath = path.join(guideDir, 'guide_rendered.html');
const pdfPath = path.join(guideDir, 'Excalidraw_AWS_Cloud_Engineering_Guide.pdf');

console.log('Step 1: Converting Markdown to HTML via npx marked...');
const rawMd = fs.readFileSync(mdPath, 'utf8');

// Run marked via CLI
const htmlBody = execSync(`npx --yes marked -i "${mdPath}" --gfm`).toString('utf8');

// Post-process HTML to convert mermaid code blocks into <div class="mermaid">
let processedHtml = htmlBody.replace(/<pre><code class="language-mermaid">([\s\S]*?)<\/code><\/pre>/g, (match, p1) => {
  const unescaped = p1
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
  return `<div class="mermaid">${unescaped}</div>`;
});

// Post-process callout blockquotes
processedHtml = processedHtml.replace(/<blockquote>\s*<p><strong>(Warning|Note|Tip|Important|Caution)<\/strong>:(.*?)<\/p>\s*<\/blockquote>/gs, (match, type, content) => {
  const lower = type.toLowerCase();
  return `<div class="callout callout-${lower}"><strong>${type}:</strong>${content}</div>`;
});

// Full HTML Template with print CSS and Mermaid.js
const fullHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Excalidraw-on-AWS: Complete Cloud Engineering Curriculum</title>
  <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=Fira+Code:wght@400;500;600&display=swap');

    @page {
      size: A4;
      margin: 18mm 15mm 18mm 15mm;
      @bottom-right {
        content: counter(page);
      }
    }

    * {
      box-sizing: border-box;
    }

    body {
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      font-size: 10.5pt;
      line-height: 1.6;
      color: #1a1f2c;
      background: #ffffff;
      margin: 0;
      padding: 0;
    }

    /* Cover Page */
    .cover-page {
      height: 95vh;
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      text-align: center;
      page-break-after: always;
      padding: 40px 20px;
      border: 3px solid #2563eb;
      border-radius: 12px;
      margin-bottom: 30px;
    }

    .cover-badge {
      background: #e0e7ff;
      color: #3730a3;
      font-weight: 700;
      font-size: 11pt;
      padding: 6px 16px;
      border-radius: 20px;
      text-transform: uppercase;
      letter-spacing: 1px;
      margin-bottom: 24px;
    }

    .cover-title {
      font-size: 28pt;
      font-weight: 800;
      color: #0f172a;
      line-height: 1.25;
      margin: 0 0 16px 0;
    }

    .cover-subtitle {
      font-size: 14pt;
      font-weight: 400;
      color: #475569;
      max-width: 650px;
      margin: 0 0 40px 0;
      line-height: 1.5;
    }

    .cover-meta {
      font-size: 10pt;
      color: #64748b;
      border-top: 1px solid #e2e8f0;
      padding-top: 20px;
      width: 80%;
      display: flex;
      justify-content: space-around;
    }

    /* Headings */
    h1, h2, h3, h4, h5, h6 {
      color: #0f172a;
      font-family: 'Inter', sans-serif;
      font-weight: 700;
      page-break-after: avoid;
    }

    h1 {
      font-size: 20pt;
      border-bottom: 2px solid #2563eb;
      padding-bottom: 8px;
      margin-top: 36px;
      margin-bottom: 18px;
      page-break-before: always;
    }

    /* Prevent page break before first h1 */
    .content > h1:first-child {
      page-break-before: avoid;
      margin-top: 0;
    }

    h2 {
      font-size: 15pt;
      border-bottom: 1px solid #cbd5e1;
      padding-bottom: 6px;
      margin-top: 28px;
      margin-bottom: 14px;
      color: #1e293b;
    }

    h3 {
      font-size: 12pt;
      margin-top: 20px;
      margin-bottom: 10px;
      color: #334155;
    }

    p, ul, ol {
      margin-top: 0;
      margin-bottom: 12px;
    }

    li {
      margin-bottom: 4px;
    }

    /* Code Blocks */
    pre {
      background: #0f172a;
      color: #f8fafc;
      font-family: 'Fira Code', Consolas, monospace;
      font-size: 9pt;
      padding: 14px 16px;
      border-radius: 8px;
      overflow-x: auto;
      page-break-inside: avoid;
      margin: 14px 0;
      line-height: 1.45;
    }

    code {
      font-family: 'Fira Code', Consolas, monospace;
      font-size: 9.5pt;
      background: #f1f5f9;
      color: #0f172a;
      padding: 2px 6px;
      border-radius: 4px;
    }

    pre code {
      background: transparent;
      color: inherit;
      padding: 0;
    }

    /* Tables */
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 16px 0;
      font-size: 9.5pt;
      page-break-inside: avoid;
    }

    th, td {
      border: 1px solid #cbd5e1;
      padding: 8px 12px;
      text-align: left;
    }

    th {
      background: #f1f5f9;
      color: #0f172a;
      font-weight: 700;
    }

    tr:nth-child(even) {
      background: #f8fafc;
    }

    /* Callout Boxes */
    .callout {
      padding: 12px 16px;
      border-left: 4px solid #2563eb;
      background: #eff6ff;
      border-radius: 0 8px 8px 0;
      margin: 14px 0;
      page-break-inside: avoid;
    }

    .callout-warning, .callout-caution {
      border-left-color: #d97706;
      background: #fffbeb;
    }

    .callout-tip {
      border-left-color: #16a34a;
      background: #f0fdf4;
    }

    .callout-important {
      border-left-color: #dc2626;
      background: #fef2f2;
    }

    blockquote {
      border-left: 4px solid #94a3b8;
      background: #f8fafc;
      margin: 14px 0;
      padding: 10px 16px;
      color: #334155;
      font-style: italic;
      page-break-inside: avoid;
    }

    /* Mermaid Diagrams */
    .mermaid {
      text-align: center;
      margin: 20px 0;
      page-break-inside: avoid;
      background: #fafafa;
      padding: 16px;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
    }

    hr {
      border: none;
      border-top: 1px solid #e2e8f0;
      margin: 24px 0;
    }
  </style>
</head>
<body>

  <!-- Cover Page -->
  <div class="cover-page">
    <div class="cover-badge">Complete Learning Curriculum</div>
    <h1 class="cover-title">Excalidraw-on-AWS:<br>Cloud Engineering Guide</h1>
    <p class="cover-subtitle">
      A Zero-to-Hero University Course covering AWS EC2, Ubuntu 24.04 LTS, Docker Containerization, Nginx Reverse Proxying, Route 53 DNS, Let's Encrypt TLS/SSL, Architecture Diagrams, Troubleshooting & Interview Preparation
    </p>
    <div class="cover-meta">
      <div><strong>Target Audience:</strong> Computer Science Students</div>
      <div><strong>Scope:</strong> 20 Comprehensive Parts</div>
      <div><strong>Format:</strong> Complete Merged Master Edition</div>
    </div>
  </div>

  <!-- Main Content -->
  <div class="content">
    ${processedHtml}
  </div>

  <script>
    mermaid.initialize({
      startOnLoad: true,
      theme: 'neutral',
      securityLevel: 'loose'
    });
  </script>
</body>
</html>`;

fs.writeFileSync(htmlPath, fullHtml, 'utf8');
console.log(`Step 2: Saved rendered HTML to: ${htmlPath}`);

console.log('Step 3: Rendering PDF via Headless Microsoft Edge...');
const edgePath = `C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe`;
const command = `"${edgePath}" --headless --disable-gpu --run-all-compositor-stages-before-draw --print-to-pdf="${pdfPath}" "file:///${htmlPath.replace(/\\/g, '/')}"`;

try {
  execSync(command, { timeout: 60000 });
  console.log(`SUCCESS! Created PDF at: ${pdfPath}`);
} catch (err) {
  console.error('Error generating PDF:', err.message);
}
