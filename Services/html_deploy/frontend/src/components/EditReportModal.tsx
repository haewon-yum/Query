import { useState, useRef } from 'react';
import { Category, Report } from '../types';
import { api } from '../api';

interface Props {
  report: Report;
  categories: Category[];
  onClose: () => void;
  onUpdated: (report: Report) => void;
}

export default function EditReportModal({ report, categories, onClose, onUpdated }: Props) {
  const [title, setTitle] = useState(report.title);
  const [description, setDescription] = useState(report.description ?? '');
  const [categoryId, setCategoryId] = useState(report.category_id);
  const [file, setFile] = useState<File | null>(null);
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  function handleFile(f: File | null) {
    if (!f) return;
    if (!f.name.toLowerCase().endsWith('.html')) {
      setError('Only .html files are accepted.');
      return;
    }
    setError('');
    setFile(f);
  }

  async function handleSubmit() {
    if (!title.trim()) return setError('Title is required.');
    if (!categoryId) return setError('Select a category.');

    const titleChanged = title.trim() !== report.title;
    const descChanged = description.trim() !== (report.description ?? '');
    const catChanged = categoryId !== report.category_id;
    const metaChanged = titleChanged || descChanged || catChanged;

    if (!metaChanged && !file) {
      onClose();
      return;
    }

    setSaving(true);
    setError('');
    try {
      let updated: Report = report;

      if (metaChanged) {
        const patch: Record<string, string> = {};
        if (titleChanged) patch.title = title.trim();
        if (descChanged) patch.description = description.trim();
        if (catChanged) patch.category_id = categoryId;
        updated = await api.put<Report>(`/api/reports/${report.id}`, patch);
      }

      if (file) {
        const form = new FormData();
        form.append('file', file);
        const res = await fetch(`/api/reports/${report.id}/replace`, {
          method: 'POST',
          credentials: 'include',
          body: form,
        });
        if (!res.ok) {
          const body = await res.json().catch(() => ({}));
          throw new Error((body as { detail?: string }).detail ?? `HTTP ${res.status}`);
        }
        updated = await res.json();
      }

      onUpdated(updated);
      onClose();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal">
        <h2>Edit Report</h2>
        {error && <div className="error-msg">{error}</div>}

        {report.source_type === 'upload' && (
          <div
            className="drop-zone"
            onDragOver={e => e.preventDefault()}
            onDrop={e => { e.preventDefault(); handleFile(e.dataTransfer.files[0] ?? null); }}
            onClick={() => fileRef.current?.click()}
          >
            {file ? (
              <span className="drop-zone-file">📄 {file.name}</span>
            ) : (
              <span className="drop-zone-hint">
                Replace HTML (optional) — drop here or <u>browse</u>
                {report.original_filename && (
                  <span className="drop-zone-current">Current: {report.original_filename}</span>
                )}
              </span>
            )}
            <input ref={fileRef} type="file" accept=".html" style={{ display: 'none' }}
              onChange={e => handleFile(e.target.files?.[0] ?? null)} />
          </div>
        )}

        <div className="form-group">
          <label>Title *</label>
          <input value={title} onChange={e => setTitle(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && handleSubmit()} />
        </div>

        <div className="form-group">
          <label>Description</label>
          <textarea value={description} onChange={e => setDescription(e.target.value)} rows={2} />
        </div>

        <div className="form-group">
          <label>Category *</label>
          <select value={categoryId} onChange={e => setCategoryId(e.target.value)}>
            {categories.filter(c => !c.parent_id).map(parent => {
              const children = categories.filter(c => c.parent_id === parent.id);
              return children.length > 0 ? (
                <optgroup key={parent.id} label={parent.name}>
                  <option value={parent.id}>{parent.name} (general)</option>
                  {children.map(c => <option key={c.id} value={c.id}>↳ {c.name}</option>)}
                </optgroup>
              ) : (
                <option key={parent.id} value={parent.id}>{parent.name}</option>
              );
            })}
          </select>
        </div>

        <div className="modal-actions">
          <button className="btn-cancel" onClick={onClose}>Cancel</button>
          <button className="btn-submit" onClick={handleSubmit} disabled={saving}>
            {saving ? 'Saving…' : 'Save Changes'}
          </button>
        </div>
      </div>
    </div>
  );
}
