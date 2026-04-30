import { useState, useEffect, useMemo } from 'react';
import { useSearchParams } from 'react-router-dom';
import { User, Category, Report } from '../types';
import { api } from '../api';
import CategorySidebar from '../components/CategorySidebar';
import ReportCard from '../components/ReportCard';
import UploadModal from '../components/UploadModal';
import EditReportModal from '../components/EditReportModal';

const COLORS = ['#4A90E2', '#34A853', '#EA4335', '#FBBC05', '#9C27B0', '#FF6D00', '#00BCD4', '#607D8B'];

interface Props {
  user: User;
  onLogout: () => void;
}

function SubCatTab({ sub, active, userEmail, onSelect, onUpdated }: {
  sub: Category; active: boolean; userEmail: string;
  onSelect: () => void;
  onUpdated: (cat: Category) => void;
}) {
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(sub.name);
  const [color, setColor] = useState(sub.color);
  const [isPrivate, setIsPrivate] = useState(sub.is_private ?? false);
  const [saving, setSaving] = useState(false);

  async function handleSave() {
    if (!name.trim()) return;
    setSaving(true);
    try {
      const updated = await api.put<Category>(`/api/categories/${sub.id}`, {
        name: name.trim(),
        color,
        is_private: isPrivate,
      });
      onUpdated(updated);
      setEditing(false);
    } finally {
      setSaving(false);
    }
  }

  function handleCancel() {
    setName(sub.name);
    setColor(sub.color);
    setIsPrivate(sub.is_private ?? false);
    setEditing(false);
  }

  if (editing) {
    return (
      <div className="subcategory-tab-edit">
        <input
          autoFocus
          className="subcategory-edit-input"
          value={name}
          onChange={e => setName(e.target.value)}
          onKeyDown={e => { if (e.key === 'Enter') handleSave(); if (e.key === 'Escape') handleCancel(); }}
        />
        <div className="color-row" style={{ marginTop: 6, gap: 5 }}>
          {COLORS.map(c => (
            <button key={c} className={`color-swatch ${color === c ? 'selected' : ''}`}
              style={{ background: c, width: 18, height: 18 }} onClick={() => setColor(c)} />
          ))}
        </div>
        <label className="private-toggle" style={{ marginTop: 8 }}>
          <input type="checkbox" checked={isPrivate} onChange={e => setIsPrivate(e.target.checked)} />
          <span>Private (only visible to you)</span>
        </label>
        <div style={{ display: 'flex', gap: 4, marginTop: 8 }}>
          <button className="btn-inline btn-submit" style={{ padding: '2px 10px', fontSize: 12 }}
            onClick={handleSave} disabled={saving || !name.trim()}>{saving ? '…' : 'Save'}</button>
          <button className="btn-inline btn-cancel" style={{ padding: '2px 8px', fontSize: 12 }}
            onClick={handleCancel}>✕</button>
        </div>
      </div>
    );
  }

  const isOwner = sub.created_by === userEmail;

  return (
    <div className="subcategory-tab-wrap">
      <button
        className={`subcategory-tab ${active ? 'active' : ''} ${sub.is_private ? 'private' : ''}`}
        style={{ borderColor: active ? sub.color : 'transparent' }}
        onClick={onSelect}
      >
        <span className="category-dot" style={{ background: sub.color, width: 6, height: 6 }} />
        {sub.name}
        {sub.is_private && <span className="lock-icon" title="Private">🔒</span>}
      </button>
      {isOwner && (
        <button className="btn-edit-subcat" onClick={e => { e.stopPropagation(); setEditing(true); }} title="Edit">
          ✎
        </button>
      )}
    </div>
  );
}

export default function Home({ user, onLogout }: Props) {
  const [categories, setCategories] = useState<Category[]>([]);
  const [reports, setReports] = useState<Report[]>([]);
  const [searchParams, setSearchParams] = useSearchParams();
  const [selectedCategory, setSelectedCategory] = useState<string | null>(
    searchParams.get('cat')
  );
  const [selectedSubCategory, setSelectedSubCategory] = useState<string | null>(
    searchParams.get('sub')
  );
  const [query, setQuery] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editingReport, setEditingReport] = useState<Report | null>(null);
  const [addingSub, setAddingSub] = useState(false);
  const [newSubName, setNewSubName] = useState('');
  const [newSubPrivate, setNewSubPrivate] = useState(false);
  const [savingSub, setSavingSub] = useState(false);

  useEffect(() => {
    api.get<Category[]>('/api/categories').then(setCategories).catch(console.error);
    api.get<Report[]>('/api/reports').then(setReports).catch(console.error);
  }, []);

  // Sync filter state → URL so back-navigation restores the view
  useEffect(() => {
    const p: Record<string, string> = {};
    if (selectedCategory) p.cat = selectedCategory;
    if (selectedSubCategory) p.sub = selectedSubCategory;
    setSearchParams(p, { replace: true });
  }, [selectedCategory, selectedSubCategory, setSearchParams]);

  const categoryMap = useMemo(
    () => Object.fromEntries(categories.map(c => [c.id, c])),
    [categories]
  );

  const subCategories = useMemo(
    () => selectedCategory ? categories.filter(c => c.parent_id === selectedCategory) : [],
    [categories, selectedCategory]
  );

  function handleSelectCategory(id: string | null) {
    setSelectedCategory(id);
    setSelectedSubCategory(null);
    setAddingSub(false);
  }

  const filtered = useMemo(() => {
    let list = reports;
    if (selectedCategory) {
      if (selectedSubCategory) {
        list = list.filter(r => r.category_id === selectedSubCategory);
      } else {
        const subIds = subCategories.map(c => c.id);
        list = list.filter(r => r.category_id === selectedCategory || subIds.includes(r.category_id));
      }
    }
    if (query) {
      const q = query.toLowerCase();
      list = list.filter(r =>
        r.title.toLowerCase().includes(q) ||
        (r.description ?? '').toLowerCase().includes(q)
      );
    }
    return list;
  }, [reports, selectedCategory, selectedSubCategory, subCategories, query]);

  async function handleDelete(id: string) {
    await api.del(`/api/reports/${id}`);
    setReports(prev => prev.filter(r => r.id !== id));
  }

  function handleReportUpdated(updated: Report) {
    setReports(prev => prev.map(r => r.id === updated.id ? updated : r));
  }

  async function handleLogout() {
    await api.post('/auth/logout', {}).catch(() => {});
    onLogout();
  }

  async function handleCreateSubCategory() {
    if (!newSubName.trim() || !selectedCategory) return;
    setSavingSub(true);
    try {
      const parentColor = categoryMap[selectedCategory]?.color ?? '#4A90E2';
      const cat = await api.post<Category>('/api/categories', {
        name: newSubName.trim(),
        color: parentColor,
        parent_id: selectedCategory,
        is_private: newSubPrivate,
      });
      setCategories(prev => [...prev, cat].sort((a, b) => a.name.localeCompare(b.name)));
      setNewSubName('');
      setNewSubPrivate(false);
      setAddingSub(false);
      setSelectedSubCategory(cat.id);
    } finally {
      setSavingSub(false);
    }
  }

  const parentCat = selectedCategory ? categoryMap[selectedCategory] : null;
  const sectionTitle = selectedSubCategory
    ? `${parentCat?.name ?? ''} › ${categoryMap[selectedSubCategory]?.name ?? ''}`
    : selectedCategory
    ? (parentCat?.name ?? 'Category')
    : 'All Reports';

  return (
    <>
      <header className="header">
        <div className="header-logo">
          <span>🪟</span>
          <span>Mosaic</span>
        </div>
        <div className="header-spacer" />
        <div className="header-user">
          {user.picture && <img src={user.picture} alt={user.name} referrerPolicy="no-referrer" />}
          <span>{user.name}</span>
          <button className="btn-logout" onClick={handleLogout}>Sign out</button>
        </div>
      </header>

      <div className="layout">
        <CategorySidebar
          categories={categories}
          reports={reports}
          selectedId={selectedCategory}
          onSelect={handleSelectCategory}
          onCategoryCreated={cat => setCategories(prev => [...prev, cat].sort((a, b) => a.name.localeCompare(b.name)))}
          onCategoryUpdated={cat => setCategories(prev => prev.map(c => c.id === cat.id ? cat : c).sort((a, b) => a.name.localeCompare(b.name)))}
        />

        <main className="main">
          <div className="toolbar">
            <input
              className="search-input"
              placeholder="Search reports…"
              value={query}
              onChange={e => setQuery(e.target.value)}
            />
            <button className="btn-add" onClick={() => setShowModal(true)}>
              + Add Report
            </button>
          </div>

          {selectedCategory && (
            <div className="subcategory-tabs">
              <button
                className={`subcategory-tab ${selectedSubCategory === null ? 'active' : ''}`}
                style={{ borderColor: selectedSubCategory === null ? parentCat?.color : 'transparent' }}
                onClick={() => setSelectedSubCategory(null)}
              >
                All
              </button>
              {subCategories.map(sub => (
                <SubCatTab
                  key={sub.id}
                  sub={sub}
                  active={selectedSubCategory === sub.id}
                  userEmail={user.email}
                  onSelect={() => setSelectedSubCategory(sub.id)}
                  onUpdated={cat => setCategories(prev =>
                    prev.map(c => c.id === cat.id ? cat : c).sort((a, b) => a.name.localeCompare(b.name))
                  )}
                />
              ))}
              {addingSub ? (
                <div className="subcategory-add-form">
                  <input
                    autoFocus
                    className="subcategory-add-input"
                    placeholder="Sub-category name"
                    value={newSubName}
                    onChange={e => setNewSubName(e.target.value)}
                    onKeyDown={e => { if (e.key === 'Enter') handleCreateSubCategory(); if (e.key === 'Escape') { setAddingSub(false); setNewSubPrivate(false); } }}
                  />
                  <label className="private-toggle-inline" title="Only visible to you">
                    <input type="checkbox" checked={newSubPrivate} onChange={e => setNewSubPrivate(e.target.checked)} />
                    🔒
                  </label>
                  <button className="btn-inline btn-submit" style={{ padding: '4px 10px', fontSize: 12 }}
                    onClick={handleCreateSubCategory} disabled={savingSub || !newSubName.trim()}>
                    {savingSub ? '…' : 'Add'}
                  </button>
                  <button className="btn-inline btn-cancel" style={{ padding: '4px 10px', fontSize: 12 }}
                    onClick={() => { setAddingSub(false); setNewSubPrivate(false); }}>✕</button>
                </div>
              ) : (
                <button className="subcategory-tab subcategory-tab-add" onClick={() => setAddingSub(true)}>
                  + sub-category
                </button>
              )}
            </div>
          )}

          <div className="section-title">{sectionTitle} ({filtered.length})</div>

          <div className="report-grid">
            {filtered.length === 0 ? (
              <div className="empty-state">
                <h3>{query ? 'No results' : 'No reports yet'}</h3>
                <p>{query ? 'Try a different search term.' : 'Add your first report using the button above.'}</p>
              </div>
            ) : (
              filtered.map(r => (
                <ReportCard
                  key={r.id}
                  report={r}
                  category={categoryMap[r.category_id]}
                  user={user}
                  onDelete={handleDelete}
                  onEdit={setEditingReport}
                />
              ))
            )}
          </div>
        </main>
      </div>

      {showModal && (
        <UploadModal
          categories={categories}
          onClose={() => setShowModal(false)}
          onCreated={report => setReports(prev => [report, ...prev])}
          onCategoryCreated={cat => setCategories(prev => [...prev, cat].sort((a, b) => a.name.localeCompare(b.name)))}
        />
      )}

      {editingReport && (
        <EditReportModal
          report={editingReport}
          categories={categories}
          onClose={() => setEditingReport(null)}
          onUpdated={updated => { handleReportUpdated(updated); setEditingReport(null); }}
        />
      )}
    </>
  );
}
