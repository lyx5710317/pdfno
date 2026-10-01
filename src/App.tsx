import { useEffect, useRef, useState } from 'react';
import type {
  DemoDocument,
  LearningNote,
  LearningTask,
  Mode,
  SourceSnapshot,
} from './domain/types';
import { documents } from './reader/demo';
import { candidateFormats } from './reader/capabilities';
import {
  codePoints,
  resolve,
  selectionOffsets,
  snapshot,
} from './domain/anchors';
import { applyEvent, mockProvider, type MockScenario } from './domain/tasks';
import { validateProvider } from './domain/provider';
import { moduleStatus } from './domain/modules';
import { loadNotes, saveNote } from './services/notes';
const modes: Record<Mode, string> = {
  translate: '选文翻译',
  grammar: '日英语法',
  reading: '假名与读音',
  page: '当前页翻译',
};
interface Workspace {
  page: number;
  source: SourceSnapshot | null;
  task: LearningTask | null;
  drafts: Record<Mode, string>;
  mode: Mode;
  noteId?: string;
}
const initial = (): Workspace => ({
  page: 0,
  source: null,
  task: null,
  drafts: { translate: '', grammar: '', reading: '', page: '' },
  mode: 'translate',
});
const statusText = {
  queued: '等待本地 mock 事件',
  streaming: '正在接收 mock 事件',
  completed: 'mock 完成 · 未调用模型',
  partial: '部分完成 · mock',
  failed: '失败 · mock',
  cancelled: '已取消 · 未调用模型',
};
export default function App() {
  const [screen, setScreen] = useState<
    'library' | 'reader' | 'settings' | 'connections' | 'tools' | 'about'
  >('library');
  const [active, setActive] = useState(documents[0].id);
  const [spaces, setSpaces] = useState<Record<string, Workspace>>(() =>
    Object.fromEntries(documents.map((d) => [d.id, initial()])),
  );
  const [left, setLeft] = useState<'outline' | 'search' | 'notes' | null>(() =>
    window.innerWidth > 1200 ? 'outline' : null,
  );
  const [right, setRight] = useState(true);
  const [wide, setWide] = useState(360);
  const [size, setSize] = useState(22);
  const [theme, setTheme] = useState('light');
  const [search, setSearch] = useState('');
  const [query, setQuery] = useState('');
  const [notice, setNotice] = useState('');
  const [notes, setNotes] = useState<LearningNote[]>([]);
  const [storageError, setStorageError] = useState(false);
  const [saveState, setSaveState] = useState('尚未保存');
  const [scenario, setScenario] = useState<MockScenario>('success');
  const [provider, setProvider] = useState({
    endpoint: 'https://api.example.com/v1',
    model: '',
  });
  const [native, setNative] = useState('尚未查询');
  const [history, setHistory] = useState<{ bookId: string; page: number }[]>(
    [],
  );
  const controllers = useRef(new Map<string, AbortController>());
  const article = useRef<HTMLElement>(null);
  const doc = documents.find((d) => d.id === active)!;
  const ws = spaces[active];
  const patch = (bookId: string, change: Partial<Workspace>) =>
    setSpaces((all) => ({ ...all, [bookId]: { ...all[bookId], ...change } }));
  useEffect(() => {
    const narrow = window.matchMedia('(max-width: 1200px)');
    const collapse = () => {
      if (narrow.matches) setLeft(null);
    };
    collapse();
    narrow.addEventListener('change', collapse);
    return () => narrow.removeEventListener('change', collapse);
  }, []);
  useEffect(() => {
    let mounted = true;
    loadNotes()
      .then((n) => {
        if (mounted) setNotes(n);
      })
      .catch(() => {
        if (mounted) {
          setStorageError(true);
          setNotice(
            '笔记存储无法读取。为保护原数据已暂停保存，请查看恢复说明。',
          );
        }
      });
    return () => {
      mounted = false;
    };
  }, []);
  useEffect(() => {
    const jobs = controllers.current;
    return () => {
      for (const c of jobs.values()) c.abort();
    };
  }, []);
  function open(d: DemoDocument) {
    setActive(d.id);
    setScreen('reader');
    setNotice('');
  }
  function navigate(bookId: string, page: number) {
    setHistory((h) => [...h, { bookId: active, page: ws.page }]);
    setActive(bookId);
    patch(bookId, { page });
    setScreen('reader');
    if (window.innerWidth <= 1200) setLeft(null);
  }
  function goBack() {
    const previous = history.at(-1);
    if (previous) {
      setActive(previous.bookId);
      patch(previous.bookId, { page: previous.page });
      setHistory((h) => h.slice(0, -1));
    }
  }
  function capture() {
    const selection = window.getSelection();
    if (!selection || selection.isCollapsed || selection.rangeCount === 0)
      return;
    const range = selection.getRangeAt(0);
    let node: Element | null =
      range.startContainer.nodeType === 1
        ? (range.startContainer as Element)
        : range.startContainer.parentElement;
    node = node?.closest('[data-block-id]') ?? null;
    if (!node || !article.current?.contains(node)) return;
    const offsets = selectionOffsets(node, range);
    if (!offsets) {
      setNotice('此骨架只支持单段选区；请在一段内选择原文。');
      return;
    }
    try {
      const s = snapshot(
        doc,
        ws.page,
        node.getAttribute('data-block-id')!,
        offsets.start,
        offsets.end,
      );
      patch(active, { source: s, noteId: undefined });
      setSaveState('尚未保存');
      setRight(true);
      setNotice('来源已捕获；点击面板不会改变原文快照。');
    } catch {
      setNotice('选区无法映射到原文，请重新选择。');
    }
  }
  function selectBlock(id: string) {
    const b = doc.pages[ws.page].blocks.find((b) => b.id === id)!;
    patch(active, {
      source: snapshot(doc, ws.page, id, 0, codePoints(b.text).length),
      noteId: undefined,
    });
    setRight(true);
    setSaveState('尚未保存');
  }
  function capturePage() {
    const text = doc.pages[ws.page].blocks.map((b) => b.text).join('\n');
    patch(active, {
      source: snapshot(
        doc,
        ws.page,
        'page',
        0,
        codePoints(text).length,
        'demo-page',
      ),
      mode: 'page',
      noteId: undefined,
    });
    setRight(true);
    setSaveState('尚未保存');
  }
  function jump(source: SourceSnapshot) {
    const target = documents.find((d) => d.id === source.bookId);
    if (!target || resolve(target, source) !== 'exact') {
      setNotice('来源需重新绑定，已保留旧引文；没有跳转到其他相同短语。');
      return;
    }
    navigate(target.id, source.pageIndex);
    patch(target.id, { source });
    requestAnimationFrame(() => {
      document
        .querySelector(`[data-block-id="${source.blockId}"]`)
        ?.scrollIntoView({ block: 'center' });
      article.current?.focus();
    });
  }
  async function generate() {
    const source = ws.source;
    if (!source) {
      setNotice('先选择正文或捕获当前样本页。');
      return;
    }
    if (controllers.current.has(active)) return;
    if (ws.mode === 'page' && source.scope !== 'demo-page') {
      setNotice('当前页翻译需要重新捕获当前样本页。');
      return;
    }
    if (ws.mode !== 'page' && source.scope === 'demo-page') {
      setNotice('选文学习需要单段选区，当前来源是整页快照。');
      return;
    }
    const controller = new AbortController();
    const bookId = active;
    const taskId = crypto.randomUUID();
    const mode = ws.mode;
    controllers.current.set(bookId, controller);
    patch(bookId, {
      task: { id: taskId, bookId, mode, source, status: 'queued', output: '' },
    });
    try {
      for await (const event of mockProvider(scenario).analyze(
        source,
        mode,
        controller.signal,
      )) {
        setSpaces((all) => {
          const t = all[bookId].task;
          if (t?.id !== taskId || controller.signal.aborted) return all;
          return {
            ...all,
            [bookId]: { ...all[bookId], task: applyEvent(t, event) },
          };
        });
      }
      if (controller.signal.aborted)
        setSpaces((all) => {
          const t = all[bookId].task;
          return t?.id === taskId
            ? {
                ...all,
                [bookId]: {
                  ...all[bookId],
                  task: { ...t, status: 'cancelled' },
                },
              }
            : all;
        });
    } finally {
      controllers.current.delete(bookId);
    }
  }
  async function save(includeResult = false) {
    const source = includeResult ? ws.task?.source : ws.source;
    if (!source || storageError) return;
    const previous = includeResult
      ? undefined
      : notes.find((n) => n.id === ws.noteId);
    const now = new Date().toISOString();
    const note: LearningNote = {
      id: previous?.id ?? crypto.randomUUID(),
      bookId: source.bookId,
      source,
      quote: source.quote.exact,
      userText: ws.drafts[ws.mode],
      aiText: includeResult ? (ws.task?.output ?? '') : '',
      revision: (previous?.revision ?? 0) + 1,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    };
    setSaveState('正在保存');
    try {
      const all = await saveNote(note);
      setNotes(all);
      if (!includeResult) patch(active, { noteId: note.id });
      setSaveState('本地已保存 · 未同步');
      setNotice('笔记保存在 PDFno 本地空间；未发送到 Bookno 或 iCloud。');
    } catch {
      setSaveState('保存失败 · 草稿已保留');
    }
  }
  function editNote(note: LearningNote) {
    jump(note.source);
    setSpaces((all) => ({
      ...all,
      [note.bookId]: {
        ...all[note.bookId],
        source: note.source,
        noteId: note.id,
        drafts: {
          ...all[note.bookId].drafts,
          [all[note.bookId].mode]: note.userText,
        },
      },
    }));
    setRight(true);
    setSaveState('已打开本地笔记');
  }
  const busy = ws.task?.status === 'queued' || ws.task?.status === 'streaming';
  const docNotes = notes.filter((n) => n.bookId === active);
  const results = doc.pages.flatMap((p, pageIndex) =>
    p.blocks
      .filter(
        (b) =>
          search &&
          b.text.toLocaleLowerCase().includes(search.toLocaleLowerCase()),
      )
      .map((b) => ({ b, pageIndex })),
  );
  return (
    <div className={`app ${theme === 'dark' ? 'dark' : ''}`}>
      <header className="topbar">
        <button
          className="brand"
          onClick={() => setScreen('library')}
          aria-label="PDFno 书库"
        >
          <span className="brandmark">P</span>
          <strong>PDFno</strong>
        </button>
        <div className="tabs" aria-label="文档标签">
          {documents.map((d) => (
            <button
              key={d.id}
              className={
                screen === 'reader' && active === d.id ? 'selected' : ''
              }
              aria-current={
                screen === 'reader' && active === d.id ? 'page' : undefined
              }
              onClick={() => open(d)}
            >
              {d.language.toUpperCase()} · {d.title}
            </button>
          ))}
        </div>
        <span className="build-badge">FOUNDATION 0.1</span>
        <button onClick={() => setScreen('settings')} aria-label="打开设置">
          设置
        </button>
      </header>
      <div className="shell">
        <nav className="rail" aria-label="应用导航">
          {(
            [
              ['library', '书库', '▤'],
              ['reader', '阅读', '▣'],
              ['connections', '连接', '⇄'],
              ['tools', '工具', '◇'],
              ['about', '说明', 'i'],
            ] as const
          ).map(([id, label, icon]) => (
            <button
              key={id}
              className={screen === id ? 'active' : ''}
              onClick={() => setScreen(id)}
              title={label}
              aria-label={label}
              aria-current={screen === id ? 'page' : undefined}
            >
              <span aria-hidden="true">{icon}</span>
              <small>{label}</small>
            </button>
          ))}
          <div className="rail-spacer" />
          <button
            onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}
            aria-label="切换深浅色"
            title="切换深浅色"
          >
            ◐
          </button>
        </nav>
        <main className={`content ${screen === 'reader' ? 'workspace' : ''}`}>
          {notice && (
            <div className="notice" role="status">
              {notice}
              <button onClick={() => setNotice('')} aria-label="关闭提示">
                ×
              </button>
            </div>
          )}
          {screen === 'library' && (
            <section className="home">
              <div className="eyebrow">YOUR READING SPACE</div>
              <h1>在原文里，留下理解。</h1>
              <p className="lead">
                Mac 优先的语言学习阅读器。先读，再思考，慢慢积累。
              </p>
              <div className="library-actions">
                <input
                  aria-label="搜索书库"
                  placeholder="搜索样本书籍"
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                />
                <button
                  className="primary"
                  onClick={() =>
                    setNotice(
                      '真实文件导入尚未接入。Kookit 分发许可待澄清；请先打开自制样本。',
                    )
                  }
                >
                  打开文件
                </button>
              </div>
              <div className="section-label">
                <h2>开发样本</h2>
                <span>自制内容 · 不联网</span>
              </div>
              <div className="books">
                {documents
                  .filter((d) =>
                    d.title.toLowerCase().includes(query.toLowerCase()),
                  )
                  .map((d, i) => (
                    <button
                      key={d.id}
                      className="book-card"
                      onClick={() => open(d)}
                    >
                      <div className={`cover cover-${i}`}>
                        <span>PDFno / STUDY SERIES</span>
                        <strong>{d.title}</strong>
                        <span>
                          {d.language === 'ja' ? '日本語' : 'ENGLISH'}
                          <br />
                          SELF-AUTHORED FIXTURE
                        </span>
                      </div>
                      <h3>{d.title}</h3>
                      <p>Demo text · {d.pages.length} 个样本页</p>
                      <span className="subtle">打开阅读工作区 →</span>
                    </button>
                  ))}
              </div>
              <div className="foundation-card">
                <span className="pill">当前版本</span>
                <h3>应用骨架已启用，真实引擎尚未接入。</h3>
                <p>
                  目录、选区、mock
                  学习与本地笔记可以运行。PDF、EPUB、漫画等格式仍保留为接入目标。
                </p>
                <button onClick={() => setScreen('about')}>
                  查看实现范围与来源
                </button>
              </div>
            </section>
          )}
          {screen === 'reader' && (
            <>
              <div
                className="reader-toolbar"
                role="toolbar"
                aria-label="阅读工具"
              >
                <div>
                  <button
                    onClick={() =>
                      setLeft(left === 'outline' ? null : 'outline')
                    }
                    aria-expanded={left === 'outline'}
                  >
                    目录
                  </button>
                  <button
                    onClick={() => setLeft(left === 'search' ? null : 'search')}
                    aria-expanded={left === 'search'}
                  >
                    搜索
                  </button>
                  <button
                    onClick={() => setLeft(left === 'notes' ? null : 'notes')}
                    aria-expanded={left === 'notes'}
                  >
                    笔记 {docNotes.length}
                  </button>
                </div>
                <div>
                  <button disabled={!history.length} onClick={goBack}>
                    返回
                  </button>
                  <button
                    onClick={() => setSize(Math.max(16, size - 2))}
                    aria-label="缩小字号"
                  >
                    A−
                  </button>
                  <button
                    onClick={() => setSize(Math.min(34, size + 2))}
                    aria-label="增大字号"
                  >
                    A＋
                  </button>
                  <button onClick={capturePage}>捕获当前页</button>
                  <button
                    onClick={() => setRight(!right)}
                    aria-expanded={right}
                  >
                    学习栏
                  </button>
                </div>
              </div>
              <div className="reader-body">
                {left && (
                  <aside className="navigation" aria-label="阅读导航">
                    <div className="pane-heading">
                      <h2>
                        {left === 'outline'
                          ? '目录'
                          : left === 'search'
                            ? '正文搜索'
                            : '本地笔记'}
                      </h2>
                      <button
                        onClick={() => setLeft(null)}
                        aria-label="收起导航"
                      >
                        ×
                      </button>
                    </div>
                    {left === 'outline' ? (
                      doc.pages.map((p, i) => (
                        <button
                          key={p.title}
                          className={`nav-entry ${ws.page === i ? 'active' : ''}`}
                          onClick={() => navigate(active, i)}
                        >
                          {p.title}
                          <small>样本页 {i + 1}</small>
                        </button>
                      ))
                    ) : left === 'search' ? (
                      <>
                        <input
                          aria-label="搜索正文"
                          value={search}
                          onChange={(e) => setSearch(e.target.value)}
                          placeholder="输入原文"
                        />
                        {results.map(({ b, pageIndex }) => (
                          <button
                            key={b.id}
                            className="nav-entry"
                            onClick={() => {
                              navigate(active, pageIndex);
                              patch(active, {
                                source: snapshot(
                                  doc,
                                  pageIndex,
                                  b.id,
                                  0,
                                  codePoints(b.text).length,
                                ),
                              });
                            }}
                          >
                            {b.text}
                            <small>样本页 {pageIndex + 1}</small>
                          </button>
                        ))}
                        {search && !results.length && (
                          <p className="subtle">未找到匹配原文</p>
                        )}
                      </>
                    ) : (
                      <>
                        {!docNotes.length && (
                          <p className="subtle">
                            暂无笔记。选择原文后写下理解。
                          </p>
                        )}
                        {docNotes.map((n) => (
                          <button
                            key={n.id}
                            className="nav-entry"
                            onClick={() => editNote(n)}
                          >
                            {n.quote}
                            <small>
                              {n.userText || '无手写内容'} · 修订 {n.revision}
                            </small>
                          </button>
                        ))}
                      </>
                    )}
                  </aside>
                )}
                <section className="canvas" aria-label="阅读画布">
                  <div className="page-meta">
                    <span>
                      {doc.language === 'ja' ? '日本語' : 'ENGLISH'} / DEMO TEXT
                    </span>
                    <span>
                      {ws.page + 1} / {doc.pages.length}
                    </span>
                  </div>
                  <article
                    className="paper"
                    ref={article}
                    tabIndex={-1}
                    onMouseUp={capture}
                    onKeyUp={(e) => {
                      if (e.shiftKey) capture();
                    }}
                    style={{ fontSize: size }}
                  >
                    <div className="eyebrow">PDFno STUDY SERIES</div>
                    <h1>{doc.pages[ws.page].title}</h1>
                    <p className="paper-intro">
                      自制测试正文 · 选择一段原文，或用段落按钮捕获来源。
                    </p>
                    {doc.pages[ws.page].blocks.map((b) => (
                      <div
                        key={b.id}
                        className={`block ${ws.source?.blockId === b.id ? 'captured' : ''}`}
                      >
                        <p data-block-id={b.id} lang={doc.language}>
                          {b.reading ? (
                            <>
                              <ruby>
                                {b.reading.base}
                                <rt>{b.reading.ruby}</rt>
                              </ruby>
                              {b.text.slice(b.reading.base.length)}
                            </>
                          ) : (
                            b.text
                          )}
                        </p>
                        <button
                          className="capture"
                          onClick={() => selectBlock(b.id)}
                          aria-label={`选择段落 ${b.id}`}
                        >
                          选择此段 →
                        </button>
                      </div>
                    ))}
                    <footer>
                      原文、译文和手写笔记分别保存。
                      <br />
                      此视图为 demo text，不是 PDF 或 EPUB 渲染结果。
                    </footer>
                  </article>
                  <div className="pagination">
                    <button
                      disabled={ws.page === 0}
                      onClick={() => navigate(active, ws.page - 1)}
                    >
                      ← 上一页
                    </button>
                    <span>样本页 {ws.page + 1}</span>
                    <button
                      disabled={ws.page === doc.pages.length - 1}
                      onClick={() => navigate(active, ws.page + 1)}
                    >
                      下一页 →
                    </button>
                  </div>
                </section>
                {right && (
                  <>
                    <div
                      className="separator"
                      role="separator"
                      tabIndex={0}
                      aria-label="学习栏宽度"
                      aria-orientation="vertical"
                      aria-valuemin={300}
                      aria-valuemax={480}
                      aria-valuenow={wide}
                      onKeyDown={(e) => {
                        if (e.key === 'ArrowLeft')
                          setWide(Math.min(480, wide + 20));
                        if (e.key === 'ArrowRight')
                          setWide(Math.max(300, wide - 20));
                        if (e.key === 'Home') setWide(360);
                      }}
                    />
                    <aside
                      className="assist"
                      style={{ width: wide }}
                      aria-label="学习侧栏"
                    >
                      <div className="pane-heading">
                        <h2>读懂这一句</h2>
                        <span className="pill">LOCAL MOCK</span>
                      </div>
                      <p className="subtle">
                        结果仅用于流程测试，无模型请求或费用。
                      </p>
                      <div className="mode-tabs" aria-label="学习模式">
                        {Object.entries(modes).map(([mode, label]) => (
                          <button
                            key={mode}
                            className={ws.mode === mode ? 'active' : ''}
                            aria-pressed={ws.mode === mode}
                            onClick={() =>
                              patch(active, { mode: mode as Mode })
                            }
                          >
                            {label}
                          </button>
                        ))}
                      </div>
                      <div className="source-card">
                        <div className="section-label">
                          <strong>当前来源</strong>
                          <span>
                            {ws.source?.scope === 'demo-page'
                              ? '样本页快照'
                              : '单段选区'}
                          </span>
                        </div>
                        {ws.source ? (
                          <>
                            <blockquote>{ws.source.quote.exact}</blockquote>
                            <p>
                              {doc.title} · 样本页 {ws.source.pageIndex + 1} ·
                              code point {ws.source.span.start}–
                              {ws.source.span.end}
                            </p>
                            <button onClick={() => jump(ws.source!)}>
                              回到原文
                            </button>
                          </>
                        ) : (
                          <p>在正文中选择文字，或点击“选择此段”。</p>
                        )}
                      </div>
                      <label className="field">
                        测试情境
                        <select
                          value={scenario}
                          onChange={(e) =>
                            setScenario(e.target.value as MockScenario)
                          }
                        >
                          <option value="success">正常完成</option>
                          <option value="rate-limit">模拟限流失败</option>
                          <option value="partial">模拟部分完成</option>
                          <option value="hold">等待事件，验证取消</option>
                        </select>
                      </label>
                      <div className="generate-actions">
                        <button
                          className="primary"
                          disabled={!ws.source || busy}
                          onClick={() => void generate()}
                        >
                          运行 mock
                        </button>
                        <button
                          disabled={!busy}
                          onClick={() =>
                            controllers.current.get(active)?.abort()
                          }
                        >
                          停止
                        </button>
                      </div>
                      {ws.task && (
                        <div className="result-card">
                          <div
                            role="status"
                            className={`task-status ${ws.task.status}`}
                          >
                            {statusText[ws.task.status]}
                          </div>
                          <small>结果来源：{ws.task.source.quote.exact}</small>
                          <pre>{ws.task.output}</pre>
                          {ws.task.error && <p role="alert">{ws.task.error}</p>}
                          <button onClick={() => jump(ws.task!.source)}>
                            回到结果来源
                          </button>
                          <button
                            disabled={
                              !['completed', 'partial'].includes(
                                ws.task.status,
                              ) ||
                              storageError ||
                              saveState === '正在保存'
                            }
                            onClick={() => void save(true)}
                          >
                            保存结果与笔记
                          </button>
                        </div>
                      )}
                      <label className="field">
                        我的笔记
                        <textarea
                          aria-label="我的笔记"
                          placeholder="写下自己的理解。切换模式会保留独立草稿。"
                          value={ws.drafts[ws.mode]}
                          onChange={(e) =>
                            patch(active, {
                              drafts: {
                                ...ws.drafts,
                                [ws.mode]: e.target.value,
                              },
                            })
                          }
                        />
                      </label>
                      <button
                        disabled={
                          !ws.source || storageError || saveState === '正在保存'
                        }
                        onClick={() => void save()}
                      >
                        保存当前选文笔记
                      </button>
                      <p className="save-state" role="status">
                        {saveState}
                      </p>
                    </aside>
                  </>
                )}
              </div>
            </>
          )}
          {screen === 'settings' && (
            <section className="settings page-section">
              <div className="eyebrow">PROVIDER & READING</div>
              <h1>模型与阅读设置</h1>
              <p className="lead">
                BYOK 边界已规划；当前只验证非敏感配置，不发送请求。
              </p>
              <label className="field">
                API endpoint
                <input
                  value={provider.endpoint}
                  onChange={(e) =>
                    setProvider({ ...provider, endpoint: e.target.value })
                  }
                />
              </label>
              <label className="field">
                Model
                <input
                  value={provider.model}
                  onChange={(e) =>
                    setProvider({ ...provider, model: e.target.value })
                  }
                />
              </label>
              <button
                onClick={() =>
                  setNotice(
                    validateProvider(provider) ??
                      '配置格式有效；连接未测试，密钥与模型服务尚未接入。',
                  )
                }
              >
                验证配置格式
              </button>
              <div className="foundation-card">
                <h3>API key：尚未启用</h3>
                <p>
                  原生 Keychain 尚未集成；当前不收集、不保存密钥。真实 BYOK
                  与连接测试属于后续任务。
                </p>
              </div>
              <label className="field">
                阅读字号
                <input
                  type="range"
                  min={16}
                  max={34}
                  step={2}
                  value={size}
                  onChange={(e) => setSize(Number(e.target.value))}
                />
                {size}px
              </label>
              <button
                onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}
              >
                切换深浅色
              </button>
              <h2>macOS 原生桥</h2>
              <p>
                Swift/Xcode 工程提供能力查询；Keychain 和 iCloud 保持未启用。
              </p>
              <button
                onClick={() => {
                  if (!window.pdfno) {
                    setNative('仅 Electron 可查询原生桥');
                    return;
                  }
                  void window.pdfno
                    .nativeCapabilities()
                    .then((c) =>
                      setNative(
                        'unavailable' in c
                          ? '桥接二进制未构建；运行 npm run native:build'
                          : `macOS bridge ${c.bridgeVersion} · Keychain 未集成 · iCloud 未启用`,
                      ),
                    )
                    .catch(() => setNative('桥接查询失败'));
                }}
              >
                查询原生能力
              </button>
              <p role="status">{native}</p>
            </section>
          )}
          {screen === 'connections' && (
            <section className="page-section">
              <div className="eyebrow">CONNECTIONS</div>
              <h1>连接你的阅读记录</h1>
              <div className="module-grid">
                <div className="foundation-card">
                  <span className="pill">BOOKNO · 未连接</span>
                  <h2>书籍、封面与笔记</h2>
                  <p>{moduleStatus.bookno}</p>
                  <p>
                    未来接口将包含稳定 ID、封面资产、修订与确认回执。当前{' '}
                    {notes.length} 条本地笔记未发送。
                  </p>
                </div>
                <div className="foundation-card">
                  <span className="pill">ICLOUD · 未启用</span>
                  <h2>多设备阅读</h2>
                  <p>{moduleStatus.icloud}</p>
                  <p>不会同步运行中的数据库；容器和 entitlement 尚未配置。</p>
                </div>
              </div>
            </section>
          )}
          {screen === 'tools' && (
            <section className="page-section">
              <div className="eyebrow">DOCUMENT TOOLS</div>
              <h1>文档处理</h1>
              <div className="foundation-card">
                <h2>转换与 OCR</h2>
                <p>{moduleStatus.conversion}</p>
                <p>
                  DOCX → PDF、EPUB → PDF、文本 PDF → DOCX
                  等候选方向需要分别评估，当前没有转换引擎。
                </p>
                <button disabled>转换尚未支持</button>
              </div>
              <h2>保留的多格式方向</h2>
              <p>
                以下来自 Koodo 基线的候选格式清单，当前真实文件阅读均未实现：
              </p>
              <div className="formats">
                {candidateFormats.map((f) => (
                  <span className="pill" key={f}>
                    {f}
                  </span>
                ))}
              </div>
            </section>
          )}
          {screen === 'about' && (
            <section className="page-section">
              <div className="eyebrow">OPEN SOURCE FOUNDATION</div>
              <h1>PDFno · 0.1.0</h1>
              <p className="lead">Copyright © 2026 PDFno contributors</p>
              <h2>已经实现</h2>
              <p>
                React/Electron 框架，自制英日样本、目录和搜索、原文快照、Unicode
                偏移、mock 事件、本地笔记与版本校验、原生能力查询。
              </p>
              <h2>尚未实现</h2>
              <p>
                真实 PDF/EPUB/漫画阅读、BYOK、翻译和语法生成、词典、Bookno
                API、iCloud、OCR 与转换。Koodo
                保留为候选基础；引擎许可澄清后再确定接入路线。
              </p>
              <h2>来源与许可</h2>
              <p>
                Koodo Reader 90e659f 提供架构及多格式方向参考。Kookit
                分发许可未确认，其代码和资产未包含在此版本。UPDF
                仅作为信息架构参考，未使用其品牌素材。Bookno 私有代码未复制。
              </p>
              <p>
                本程序依据 GNU Affero General Public License v3
                或更新版本分发，不提供任何保证；你可以按该许可证传播和修改。
              </p>
              <p>
                <a
                  href="https://github.com/lyx5710317/pdfno"
                  target="_blank"
                  rel="noreferrer"
                >
                  获取对应源码
                </a>{' '}
                ·{' '}
                <a
                  href="https://github.com/lyx5710317/pdfno/blob/main/LICENSE"
                  target="_blank"
                  rel="noreferrer"
                >
                  阅读完整许可证
                </a>
              </p>
              <p className="subtle">
                Electron
                阻止外部窗口；请在系统浏览器访问以上源码地址。完整许可证随源码提供。
              </p>
            </section>
          )}
        </main>
      </div>
      <footer className="statusbar">
        <span>PDFno / 自制 demo text · 真实阅读引擎未接入</span>
        <span>本地保存 ≠ 云端同步 · AI：mock</span>
      </footer>
    </div>
  );
}
