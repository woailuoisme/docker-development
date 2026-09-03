# Gotenberg 使用说明

Gotenberg 是一个文档转换 API，默认运行在 `http://localhost:3200`。

## 能力

- 将 `URL`、`HTML`、`Markdown` 和 Office 文档转换为 PDF
- 合并、拆分和旋转 PDF 文件
- 生成 HTML 截图
- 输出 PDF/A

## 示例

### URL 转 PDF

```bash
curl \
  --request POST http://localhost:3200/forms/chromium/convert/url \
  --form url=https://example.com \
  -o page.pdf
```

### HTML 文件转 PDF

```bash
curl \
  --request POST http://localhost:3200/forms/chromium/convert/html \
  --form files=@./index.html \
  -o page.pdf
```

### Markdown 转 PDF

```bash
curl \
  --request POST http://localhost:3200/forms/chromium/convert/markdown \
  --form files=@./README.md \
  -o doc.pdf
```

### Office 文档转 PDF

```bash
curl \
  --request POST http://localhost:3200/forms/libreoffice/convert \
  --form files=@./demo.docx \
  -o demo.pdf
```

### 合并 PDF

```bash
curl \
  --request POST http://localhost:3200/forms/pdfengines/merge \
  --form files=@./a.pdf \
  --form files=@./b.pdf \
  -o merged.pdf
```

### 拆分 PDF

```bash
curl \
  --request POST http://localhost:3200/forms/pdfengines/split \
  --form files=@./book.pdf \
  --form splitMode=intervals \
  --form splitSpan=1 \
  -o split.zip
```

### HTML 截图

```bash
curl \
  --request POST http://localhost:3200/forms/chromium/screenshot/html \
  --form files=@./index.html \
  -o shot.jpeg
```
