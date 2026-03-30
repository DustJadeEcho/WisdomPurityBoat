/**
 * 简易 Markdown → HTML 转换器（移动端大字版 v3）
 */

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function formatInline(text: string): string {
  let result: string = text;
  result = result.replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');
  result = result.replace(/\*(.+?)\*/g, '<i>$1</i>');
  result = result.replace(/`([^`]+)`/g,
    '<code style="background-color:#f0f0f0;padding:10px 18px;border-radius:8px;font-size:42px;">$1</code>');
  return result;
}

function isOrderedItem(trimmedLine: string): boolean {
  const dotIdx: number = trimmedLine.indexOf('. ');
  if (dotIdx <= 0) return false;
  const numPart: string = trimmedLine.substring(0, dotIdx);
  for (let i = 0; i < numPart.length; i++) {
    const ch: string = numPart.charAt(i);
    if (ch < '0' || ch > '9') return false;
  }
  return true;
}

function getOrderedItemContent(trimmedLine: string): string {
  const dotIdx: number = trimmedLine.indexOf('. ');
  return trimmedLine.substring(dotIdx + 2);
}

export function markdownToHtml(markdown: string): string {
  const lines: string[] = markdown.split('\n');
  let html: string = '';
  let inCodeBlock: boolean = false;
  let inUnorderedList: boolean = false;
  let inOrderedList: boolean = false;

  for (let i = 0; i < lines.length; i++) {
    const line: string = lines[i];
    const trimmed: string = line.trim();

    // ===== 代码块 =====
    if (trimmed.startsWith('```')) {
      if (inUnorderedList) { html += '</ul>'; inUnorderedList = false; }
      if (inOrderedList) { html += '</ol>'; inOrderedList = false; }
      if (inCodeBlock) {
        html += '</code></pre>';
        inCodeBlock = false;
      } else {
        html += '<pre style="background-color:#282c34;color:#abb2bf;padding:32px 28px;' +
          'border-radius:14px;font-size:40px;line-height:2.0;margin:20px 0;overflow-x:auto;' +
          'word-wrap:break-word;white-space:pre-wrap;">';
        html += '<code>';
        inCodeBlock = true;
      }
      continue;
    }

    if (inCodeBlock) {
      html += escapeHtml(line) + '\n';
      continue;
    }

    // ===== 空行 =====
    if (trimmed === '') {
      if (inUnorderedList) { html += '</ul>'; inUnorderedList = false; }
      if (inOrderedList) { html += '</ol>'; inOrderedList = false; }
      html += '<div style="height:20px;"></div>';
      continue;
    }

    // ===== 标题 =====
    if (trimmed.startsWith('#### ')) {
      if (inUnorderedList) { html += '</ul>'; inUnorderedList = false; }
      if (inOrderedList) { html += '</ol>'; inOrderedList = false; }
      html += '<h4 style="color:#1890FF;font-size:50px;margin:24px 0 16px 0;font-weight:bold;">' +
      formatInline(trimmed.substring(5)) + '</h4>';
      continue;
    }
    if (trimmed.startsWith('### ')) {
      if (inUnorderedList) { html += '</ul>'; inUnorderedList = false; }
      if (inOrderedList) { html += '</ol>'; inOrderedList = false; }
      html += '<h3 style="color:#1890FF;font-size:54px;margin:26px 0 16px 0;font-weight:bold;">' +
      formatInline(trimmed.substring(4)) + '</h3>';
      continue;
    }
    if (trimmed.startsWith('## ')) {
      if (inUnorderedList) { html += '</ul>'; inUnorderedList = false; }
      if (inOrderedList) { html += '</ol>'; inOrderedList = false; }
      html += '<h2 style="color:#1890FF;font-size:58px;margin:28px 0 18px 0;font-weight:bold;">' +
      formatInline(trimmed.substring(3)) + '</h2>';
      continue;
    }
    if (trimmed.startsWith('# ')) {
      if (inUnorderedList) { html += '</ul>'; inUnorderedList = false; }
      if (inOrderedList) { html += '</ol>'; inOrderedList = false; }
      html += '<h1 style="color:#1890FF;font-size:64px;margin:32px 0 20px 0;font-weight:bold;">' +
      formatInline(trimmed.substring(2)) + '</h1>';
      continue;
    }

    // ===== 分隔线 =====
    if (trimmed === '---' || trimmed === '***' || trimmed === '___') {
      if (inUnorderedList) { html += '</ul>'; inUnorderedList = false; }
      if (inOrderedList) { html += '</ol>'; inOrderedList = false; }
      html += '<hr style="border:none;border-top:2px solid #e8e8e8;margin:24px 0;">';
      continue;
    }

    // ===== 无序列表 =====
    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      if (inOrderedList) { html += '</ol>'; inOrderedList = false; }
      if (!inUnorderedList) {
        html += '<ul style="padding-left:44px;margin:16px 0;">';
        inUnorderedList = true;
      }
      const content: string = trimmed.substring(2);
      html += '<li style="margin:14px 0;line-height:2.0;font-size:44px;">' +
      formatInline(content) + '</li>';
      continue;
    }

    // ===== 有序列表 =====
    if (isOrderedItem(trimmed)) {
      if (inUnorderedList) { html += '</ul>'; inUnorderedList = false; }
      if (!inOrderedList) {
        html += '<ol style="padding-left:44px;margin:16px 0;">';
        inOrderedList = true;
      }
      const content: string = getOrderedItemContent(trimmed);
      html += '<li style="margin:14px 0;line-height:2.0;font-size:44px;">' +
      formatInline(content) + '</li>';
      continue;
    }

    // ===== 普通段落 =====
    if (inUnorderedList) { html += '</ul>'; inUnorderedList = false; }
    if (inOrderedList) { html += '</ol>'; inOrderedList = false; }
    html += '<p style="margin:14px 0;line-height:2.0;color:#333333;font-size:44px;' +
      'word-wrap:break-word;">' +
    formatInline(trimmed) + '</p>';
  }

  if (inCodeBlock) { html += '</code></pre>'; }
  if (inUnorderedList) { html += '</ul>'; }
  if (inOrderedList) { html += '</ol>'; }

  return '<div style="font-size:44px;color:#333333;line-height:2.0;padding:14px 8px;' +
    'word-wrap:break-word;">' +
    html + '</div>';
}