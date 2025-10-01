export interface Notification {
  id: string;
  title: string;
  message: string;
  read: boolean;
  created_at: string;
  user: { id: string; username: string } | string; // <-- make this explicit
}