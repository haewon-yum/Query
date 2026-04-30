import { useNavigate } from 'react-router-dom';
import { Report, Category, User } from '../types';

interface Props {
  report: Report;
  category?: Category;
  user: User;
  onDelete: (id: string) => void;
  onEdit: (report: Report) => void;
}

export default function ReportCard({ report, category, user, onDelete, onEdit }: Props) {
  const navigate = useNavigate();
  const isOwner = user.email === report.uploader;

  function handleDelete(e: React.MouseEvent) {
    e.stopPropagation();
    if (confirm(`Delete "${report.title}"?`)) {
      onDelete(report.id);
    }
  }

  function handleEdit(e: React.MouseEvent) {
    e.stopPropagation();
    onEdit(report);
  }

  const date = new Date(report.created_at).toLocaleDateString('en-US', {
    month: 'short', day: 'numeric', year: 'numeric',
  });

  return (
    <div
      className="report-card"
      onClick={() => navigate(`/view/${report.id}`, {
        state: { from: window.location.pathname + window.location.search },
      })}
    >
      <div className="report-card-header">
        <div className="report-card-title">{report.title}</div>
        {isOwner && (
          <div className="report-card-actions">
            <button className="btn-edit-card" onClick={handleEdit} title="Edit">✎</button>
            <button className="btn-delete-card" onClick={handleDelete} title="Delete">✕</button>
          </div>
        )}
      </div>

      {report.description && (
        <div className="report-card-desc">{report.description}</div>
      )}

      <div className="report-card-meta">
        {category && (
          <span className="category-badge">
            <span className="category-dot" style={{ background: category.color }} />
            {category.name}
          </span>
        )}
        <span title={report.uploader}>{report.uploader.split('@')[0]}</span>
        <span>·</span>
        <span>{date}</span>
        <span style={{ marginLeft: 'auto', fontSize: 11, opacity: 0.6 }}>
          {report.source_type === 'gdrive' ? '🔗 Drive' : '⬆ Upload'}
        </span>
      </div>
    </div>
  );
}
