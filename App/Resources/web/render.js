/* glue: markdown-it + texmath(KaTeX) + highlight.js */
'use strict';

const md = window.markdownit({
  html: true,
  linkify: true,
  typographer: true,
  breaks: false,
  highlight: function (str, lang) {
    if (lang && window.hljs.getLanguage(lang)) {
      try {
        return '<pre class="hljs"><code>' +
          window.hljs.highlight(str, { language: lang, ignoreIllegals: true }).value +
          '</code></pre>';
      } catch (e) {}
    }
    try {
      return '<pre class="hljs"><code>' +
        window.hljs.highlightAuto(str).value + '</code></pre>';
    } catch (e) {}
    return '<pre class="hljs"><code>' + md.utils.escapeHtml(str) + '</code></pre>';
  }
}).use(texmath, {
  engine: window.katex,
  delimiters: 'dollars',
  katexOptions: { throwOnError: false, strict: false, output: 'htmlAndMathml' }
});

// Render markdown source into #content, preserving scroll ratio when possible.
window.renderMarkdown = function (src) {
  const el = document.getElementById('content');
  const prevRatio = (document.body.scrollHeight > window.innerHeight)
    ? window.scrollY / (document.body.scrollHeight - window.innerHeight)
    : 0;
  el.innerHTML = md.render(src || '');
  const max = document.body.scrollHeight - window.innerHeight;
  if (max > 0) window.scrollTo(0, prevRatio * max);
};

// signal native side that the page is ready
if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ready) {
  window.webkit.messageHandlers.ready.postMessage('ready');
}
