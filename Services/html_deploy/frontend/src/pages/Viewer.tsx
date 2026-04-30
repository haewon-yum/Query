import { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate, useLocation } from 'react-router-dom';
import { Report, Category } from '../types';
import { api } from '../api';

export default function Viewer() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const location = useLocation();
  const from = (location.state as { from?: string })?.from ?? '/';
  const iframeRef = useRef<HTMLIFrameElement>(null);

  const [report, setReport] = useState<Report | null>(null);
  const [category, setCategory] = useState<Category | null>(null);
  const [copied, setCopied] = useState(false);
  const [copiedMsg, setCopiedMsg] = useState('✓ Copied');
  const [error, setError] = useState('');

  useEffect(() => {
    if (!id) return;
    Promise.all([
      api.get<Report>(`/api/reports/${id}`),
      api.get<Category[]>('/api/categories'),
    ])
      .then(([r, cats]) => {
        setReport(r);
        setCategory(cats.find(c => c.id === r.category_id) ?? null);
      })
      .catch(() => setError('Report not found.'));
  }, [id]);

  // Receive section deep-link requests from the injected iframe script
  useEffect(() => {
    function onMessage(e: MessageEvent) {
      if (e.data?.type === 'mosaic-copy-link' && id) {
        const anchor = e.data.anchor as string;
        const url = `${window.location.origin}/view/${id}#${anchor}`;
        navigator.clipboard.writeText(url);
        window.history.replaceState(null, '', `#${anchor}`);
        setCopiedMsg('✓ Section link copied');
        setCopied(true);
        setTimeout(() => setCopied(false), 2500);
      }
    }
    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, [id]);

  // After iframe loads, scroll to hash if present in the URL
  function handleIframeLoad() {
    const hash = window.location.hash;
    if (hash) {
      setTimeout(() => {
        iframeRef.current?.contentWindow?.postMessage(
          { type: 'mosaic-scroll-to', anchor: hash.slice(1) },
          '*'
        );
      }, 80);
    }
  }

  function handleShare() {
    navigator.clipboard.writeText(window.location.href);
    setCopiedMsg('✓ Copied');
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  if (error) {
    return (
      <div className="viewer-page">
        <div className="viewer-header">
          <button className="btn-back" onClick={() => navigate(from)}>← Back</button>
          <span style={{ color: 'var(--text-secondary)' }}>{error}</span>
        </div>
      </div>
    );
  }

  const date = report
    ? new Date(report.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
    : '';

  return (
    <div className="viewer-page">
      <div className="viewer-header">
        <button className="btn-back" onClick={() => navigate(from)}>← Back</button>

        <div className="viewer-title">{report?.title ?? 'Loading…'}</div>

        {report && (
          <div className="viewer-meta">
            {category && (
              <span className="category-badge">
                <span className="category-dot" style={{ background: category.color }} />
                {category.name}
              </span>
            )}
            <span>{report.uploader.split('@')[0]}</span>
            <span>·</span>
            <span>{date}</span>
          </div>
        )}

        <button className={`btn-share ${copied ? 'copied' : ''}`} onClick={handleShare}>
          {copied ? copiedMsg : '🔗 Share'}
        </button>
      </div>

      {id && (
        <iframe
          ref={iframeRef}
          className="viewer-frame"
          src={`/api/serve/${id}`}
          sandbox="allow-scripts allow-same-origin allow-popups allow-forms"
          title={report?.title ?? 'Report'}
          onLoad={handleIframeLoad}
        />
      )}
    </div>
  );
}
