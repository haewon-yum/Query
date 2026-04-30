import { useState } from 'react';
import { Category, Report } from '../types';
import { api } from '../api';

const COLORS = ['#4A90E2', '#34A853', '#EA4335', '#FBBC05', '#9C27B0', '#FF6D00', '#00BCD4', '#607D8B'];

interface Props {
  categories: Category[];
  reports: Report[];
  selectedId: string | null;
  onSelect: (id: string | null) => void;
  onCategoryCreated: (cat: Category) => void;
  onCategoryUpdated: (cat: Category) => void;
}

function CategoryRow({ cat, count, selected, onSelect, onUpdated }: {
  cat: Category; count: number; selected: boolean;
  onSelect: () => void; onUpdated: (cat: Category) => void;
}) {
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(cat.name);
  const [color, setColor] = useState(cat.color);
  const [saving, setSaving] = useState(false);

  async function handleSave() {
    if (!name.trim()) return;
    setSaving(true);
    try {
      const updated = await api.put<Category>(`/api/categories/${cat.id}`, { name: name.trim(), color });
      onUpdated(updated);
      setEditing(false);
    } finally {
      setSaving(false);
    }
  }

  function handleCancel() {
    setName(cat.name);
    setColor(cat.color);
    setEditing(false);
  }

  if (editing) {
    return (
      <div style={{ padding: '6px 0' }}>
        <input
          autoFocus
          value={name}
          onChange={e => setName(e.target.value)}
          onKeyDown={e => { if (e.key === 'Enter') handleSave(); if (e.key === 'Escape') handleCancel(); }}
          style={{ width: '100%', padding: '6px 8px', border: '1px solid var(--border)', borderRadius: 6, fontSize: 13, outline: 'none' }}
        />
        <div className="color-row" style={{ marginTop: 8 }}>
          {COLORS.map(c => (
            <button key={c} className={`color-swatch ${color === c ? 'selected' : ''}`}
              style={{ background: c }} onClick={() => setColor(c)} />
          ))}
        </div>
        <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
          <button className="btn-inline btn-submit" onClick={handleSave} disabled={saving || !name.trim()}>
            {saving ? '…' : 'Save'}
          </button>
          <button className="btn-inline btn-cancel" onClick={handleCancel}>Cancel</button>
        </div>
      </div>
    );
  }

  return (
    <div className={`sidebar-item-wrap ${selected ? 'active' : ''}`}>
      <button className={`sidebar-item ${selected ? 'active' : ''}`} onClick={onSelect}
        style={{ flex: 1, border: 'none', background: 'none', textAlign: 'left' }}>
        <span className="category-dot" style={{ background: cat.color }} />
        <span style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {cat.name}
        </span>
        <span className="count">{count}</span>
      </button>
      <button className="btn-edit-cat" onClick={e => { e.stopPropagation(); setEditing(true); }} title="Edit">
        ✎
      </button>
    </div>
  );
}

export default function CategorySidebar({ categories, reports, selectedId, onSelect, onCategoryCreated, onCategoryUpdated }: Props) {
  const [adding, setAdding] = useState(false);
  const [name, setName] = useState('');
  const [color, setColor] = useState(COLORS[0]);
  const [saving, setSaving] = useState(false);

  // only top-level categories in the sidebar
  const topLevel = categories.filter(c => !c.parent_id);

  const countFor = (id: string) => {
    const subIds = categories.filter(c => c.parent_id === id).map(c => c.id);
    return reports.filter(r => r.category_id === id || subIds.includes(r.category_id)).length;
  };

  async function handleCreate() {
    if (!name.trim()) return;
    setSaving(true);
    try {
      const cat = await api.post<Category>('/api/categories', { name: name.trim(), color });
      onCategoryCreated(cat);
      setName('');
      setColor(COLORS[0]);
      setAdding(false);
    } finally {
      setSaving(false);
    }
  }

  return (
    <aside className="sidebar">
      <div className="sidebar-section">
        <div className="sidebar-label">Views</div>
        <button className={`sidebar-item ${selectedId === null ? 'active' : ''}`} onClick={() => onSelect(null)}>
          <span>📋</span>
          <span>All Reports</span>
          <span className="count">{reports.length}</span>
        </button>
      </div>

      <div className="sidebar-section">
        <div className="sidebar-label">Categories</div>
        {topLevel.map(cat => (
          <CategoryRow
            key={cat.id}
            cat={cat}
            count={countFor(cat.id)}
            selected={selectedId === cat.id}
            onSelect={() => onSelect(cat.id)}
            onUpdated={onCategoryUpdated}
          />
        ))}

        {adding ? (
          <div style={{ padding: '8px 0' }}>
            <input
              autoFocus
              placeholder="Category name"
              value={name}
              onChange={e => setName(e.target.value)}
              onKeyDown={e => { if (e.key === 'Enter') handleCreate(); if (e.key === 'Escape') setAdding(false); }}
              style={{ width: '100%', padding: '6px 8px', border: '1px solid var(--border)', borderRadius: 6, fontSize: 13, outline: 'none' }}
            />
            <div className="color-row" style={{ marginTop: 8 }}>
              {COLORS.map(c => (
                <button key={c} className={`color-swatch ${color === c ? 'selected' : ''}`}
                  style={{ background: c }} onClick={() => setColor(c)} title={c} />
              ))}
            </div>
            <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
              <button className="btn-inline btn-submit" onClick={handleCreate} disabled={saving || !name.trim()}>
                {saving ? '…' : 'Add'}
              </button>
              <button className="btn-inline btn-cancel" onClick={() => setAdding(false)}>Cancel</button>
            </div>
          </div>
        ) : (
          <button className="btn-new-cat" onClick={() => setAdding(true)}>+ New category</button>
        )}
      </div>
    </aside>
  );
}
