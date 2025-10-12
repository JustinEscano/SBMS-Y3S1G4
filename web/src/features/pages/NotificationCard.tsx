import React, { useState } from "react";
import { PenSquareIcon, TrashIcon, EyeIcon } from "lucide-react";
import type { Notification } from "../types/notificationTypes";
import NotificationModal from "../components/notificationModal";
import "../components/Notifications.css";

interface NotificationCardProps {
  notif: {
    id: string;
    title: string;
    message?: string;
    created_at: string;
    read: boolean;
  };
  onMarkUnread?: (id: string) => void;
  onMarkRead?: (id: string) => void;
  onDelete?: (id: string) => void;
}

const NotificationCard: React.FC<NotificationCardProps> = ({ notif, onMarkUnread, onMarkRead, onDelete }) => {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const formatDate = (date: Date) => date.toLocaleDateString();

  const handleMarkRead = (e: React.MouseEvent) => {
    e.stopPropagation(); // Prevent modal trigger
    e.preventDefault(); // prevent link navigation
    if (notif.read) {
      onMarkUnread?.(notif.id);
    } else {
      onMarkRead?.(notif.id);
    }
  };

  const handleDelete = (e: React.MouseEvent) => {
    e.stopPropagation(); // Prevent modal trigger
    e.preventDefault();
    onDelete?.(notif.id);
  };

  const handleModalOpen = () => {
    setIsModalOpen(true);
    if (!notif.read) {
      onMarkRead?.(notif.id);
    }
  };

  return (
    <>
    <div
        className={`notif-card ${notif.read ? "read" : "unread"}`}
        onClick={handleModalOpen}>
      <div className="notif-card-body">
        <div className="notif-card-header">
          <h3 className="notif-card-title">{notif.title || "Title"}</h3>
          <span className="notif-card-date">{formatDate(new Date(notif.created_at))}</span>
        </div>
        <div className="notif-card-divider"></div>
        <p className="notif-card-content">{notif.message || "No message"}</p>
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
      </div>

      {isModalOpen && (
        <NotificationModal
          notifModal={{
            id: notif.id,
            user: "",
            title: notif.title,
            message: notif.message || "",
            created_at: notif.created_at,
            read: notif.read,
          }}
          onClose={() => setIsModalOpen(false)}
        />
      )}
      </>
  );
};

export default NotificationCard;
