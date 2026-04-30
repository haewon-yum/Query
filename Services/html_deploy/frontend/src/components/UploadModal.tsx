import { useState, useRef } from 'react';
import { Category, Report } from '../types';
import { api } from '../api';

interface Props {
  categories: Category[];
  onClose: () => void;
  onCreated: (report: Report) => void;
  onCategoryCreated: (cat: Category) => void;
}

const COLORS = ['#4A90E2', '#34A853', '#EA4335', '#FBBC05', '#9C27B0', '#FF6D00', '#00BCD4'];

export default function UploadModal({ categories, onClose, onCreated, onCategoryCreated }: Props) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [categoryId, setCategoryId] = useState(categories[0]?.id ?? '');
  const [file, setFile] = useState<File | null>(null);
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  const [addingCat, setAddingCat] = useState(false);
  const [newCatName, setNewCatName] = useState('');
  const [newCatColor, setNewCatColor] = useState(COLORS[0]);
  const [savingCat, setSavingCat] = useState(false);

  async function handleCreateCategory() {
    if (!newCatName.trim()) return;
    setSavingCat(true);
    try {
      const cat = await api.post<Category>('/api/categories', { name: newCatName.trim(), color: newCatColor });
      onCategoryCreated(cat);
      setCategoryId(cat.id);
      setAddingCat(false);
      setNewCatName('');
    } finally {
      setSavingCat(false);
    }
  }

  function handleFile(f: File | null) {
    if (!f) return;
    if (!f.name.toLowerCase().endsWith('.html')) {
      setError('Only .html files are accepted.');
      return;
    }
    setError('');
    setFile(f);
    if (!title.trim()) setTitle(f.name.replace(/\.html$/i, ''));
  }

  async function handleSubmit() {
    if (!title.trim()) return setError('Title is required.');
    if (!categoryId) return setError('Select a category.');
    if (!file) return setError('Select an HTML file to upload.');

    setSaving(true);
    setError('');
    try {
      const form = new FormData();
      form.append('title', title.trim());
      form.append('description', description.trim());
      form.append('category_id', categoryId);
      form.append('file', file);

      const res = await fetch('/api/reports/upload', {
        method: 'POST',
        credentials: 'include',
        body: form,
      });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error((body as { detail?: string }).detail ?? `HTTP ${res.status}`);
      }
      const report: Report = await res.json();
      onCreated(report);
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
        <h2>Add Report</h2>

        {error && <div className="error-msg">{error}</div>}

        <div
          className="drop-zone"
          onDragOver={e => e.preventDefault()}
          onDrop={e => { e.preventDefault(); handleFile(e.dataTransfer.files[0] ?? null); }}
          onClick={() => fileRef.current?.click()}
        >
          {file ? (
            <span className="drop-zone-file">📄 {file.name}</span>
          ) : (
            <span className="drop-zone-hint">Drop .html file here or <u>browse</u></span>
          )}
          <input
            ref={fileRef}
            type="file"
            accept=".html"
            style={{ display: 'none' }}
            onChange={e => handleFile(e.target.files?.[0] ?? null)}
          />
        </div>

        <div className="form-group">
          <label>Title *</label>
          <input
            autoFocus
            placeholder="e.g. Stonekey Launch Analysis – Apr 2026"
            value={title}
            onChange={e => setTitle(e.target.value)}
          />
        </div>

        <div className="form-group">
          <label>Description</label>
          <textarea
            placeholder="Brief summary of what this report covers"
            value={description}
            onChange={e => setDescription(e.target.value)}
            rows={2}
          />
        </div>

        <div className="form-group">
          <label>Category *</label>
          {addingCat ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              <input
                autoFocus
                placeholder="Category name"
                value={newCatName}
                onChange={e => setNewCatName(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && handleCreateCategory()}
              />
              <div className="color-row">
                {COLORS.map(c => (
                  <button key={c} className={`color-swatch ${newCatColor === c ? 'selected' : ''}`}
                    style={{ background: c }} onClick={() => setNewCatColor(c)} />
                ))}
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <button className="btn-submit" style={{ flex: 1, padding: '7px' }}
                  onClick={handleCreateCategory} disabled={savingCat || !newCatName.trim()}>
                  {savingCat ? 'Creating…' : 'Create'}
                </button>
                <button className="btn-cancel" style={{ padding: '7px 14px' }}
                  onClick={() => setAddingCat(false)}>Cancel</button>
              </div>
            </div>
          ) : (
            <div style={{ display: 'flex', gap: 8 }}>
              <select style={{ flex: 1 }} value={categoryId} onChange={e => setCategoryId(e.target.value)}>
                {categories.length === 0 && <option value="">— select a category —</option>}
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
              <button className="btn-cancel" style={{ whiteSpace: 'nowrap', padding: '8px 12px' }}
                onClick={() => setAddingCat(true)}>+ New</button>
            </div>
          )}
        </div>

        <div className="modal-actions">
          <button className="btn-cancel" onClick={onClose}>Cancel</button>
          <button className="btn-submit" onClick={handleSubmit} disabled={saving}>
            {saving ? 'Uploading…' : 'Add Report'}
          </button>
        </div>
      </div>
    </div>
  );
}
