import React from "react";
import { Link } from "react-router-dom";
import { PenSquareIcon, TrashIcon, EyeIcon } from "lucide-react";
import "../components/Notifications.css";

interface NotificationCardProps {
  notif: {
    id: string;
    title: string;
    content?: string;
    created_at: string;
    read: boolean;
  };
  onMarkRead?: (id: string) => void;
  onDelete?: (id: string) => void;
}

const NotificationCard: React.FC<NotificationCardProps> = ({ notif, onMarkRead, onDelete }) => {
  const formatDate = (date: Date) => date.toLocaleDateString();

  const handleMarkRead = (e: React.MouseEvent) => {
    e.preventDefault(); // prevent link navigation
    onMarkRead?.(notif.id);
  };

  const handleDelete = (e: React.MouseEvent) => {
    e.preventDefault();
    onDelete?.(notif.id);
  };

  return (
    <Link to={`/notif/${notif.id}`} className={`notif-card ${notif.read ? "read" : "unread"}`}>
      <div className="notif-card-body">
        <div className="notif-card-header">
          <h3 className="notif-card-title">{notif.title || "Title"}</h3>
          <span className="notif-card-date">{formatDate(new Date(notif.created_at))}</span>
        </div>
        <div className="notif-card-divider"></div>
        <p className="notif-card-content">{notif.content || "No message"}</p>
        <div className="notif-card-actions">
          <div className="action-icons">
            <PenSquareIcon className="icon" color="#CCE9EF" />
            <button className="mark-read-btn" onClick={handleMarkRead}>
              <EyeIcon className="icon" color={notif.read ? "#888" : "#00f"} />
            </button>
            <button className="delete-btn" onClick={handleDelete}>
              <TrashIcon className="icon" />
            </button>
          </div>
        </div>
      </div>
    </Link>
  );
};

export default NotificationCard;
