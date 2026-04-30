export interface User {
  email: string;
  name: string;
  picture: string;
}

export interface Category {
  id: string;
  name: string;
  description?: string;
  color: string;
  parent_id?: string;
  is_private?: boolean;
  created_by: string;
  created_at: string;
}

export interface Report {
  id: string;
  title: string;
  description?: string;
  category_id: string;
  source_type: 'gdrive' | 'upload';
  source_ref: string;
  original_filename?: string;
  uploader: string;
  created_at: string;
  updated_at: string;
  tags: string[];
}
