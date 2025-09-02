import React from "react";
import { Link } from "react-router-dom";
import { PenSquareIcon, TrashIcon } from "lucide-react";
import "../components/Notifications.css";

const NotificationCard: React.FC<{
  notif: { id: number; title: string; content: string; createdAt: string };
}> = ({ notif }) => {
  // Format date function
  const formatDate = (date: Date) => {
    return date.toLocaleDateString();
  };

  return (
    <Link to={`/notif/${notif.id}`} className="notif-card">
      <div className="notif-card-body">
        <div className="notif-card-header">
          <h3 className="notif-card-title">{notif.title || "Title"}</h3>
          <span className="notif-card-date">
            {formatDate(new Date(notif.createdAt))}
          </span>
        </div>
        <div className="notif-card-divider"></div>
        <p className="notif-card-content">{notif.content || "Notification Content"}</p>
        <div className="notif-card-actions">
          <div className="action-icons">
            <PenSquareIcon className="icon" color="#CCE9EF"/>
            <button className="delete-btn">
              <TrashIcon className="icon" />
            </button>
          </div>
        </div>
      </div>
    </Link>
  );
};

export default NotificationCard;