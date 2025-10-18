export interface Notification {
  id: string;
  title: string;
  message: string;
  read: boolean;
  type?: string;  // Matches 'type'
  metadata?: {    // ← This might be missing or unused
    user_name: string;
    category_display: string;
    created_at: string;  // ← Here, not root 'date'
  };
  // No 'date' or 'createdAt' at root?
}