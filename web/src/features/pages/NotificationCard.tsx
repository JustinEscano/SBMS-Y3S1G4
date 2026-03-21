import React, { useState } from "react";
import { TrashIcon, MailIcon, MailOpenIcon } from "lucide-react";
import NotificationModal from "../components/notificationModal";
import "../components/Notifications.css";
import type { Notification } from "../types/notificationTypes";

interface NotificationCardProps {
  notif: Notification;
  onMarkUnread?: (id: string) => void;
  onMarkRead?: (id: string) => void;
  onDelete?: (id: string) => void;
}

const NotificationCard: React.FC<NotificationCardProps> = ({ notif, onMarkUnread, onMarkRead, onDelete }) => {
  const [isModalOpen, setIsModalOpen] = useState(false);

  // Safe formatDate (string input, fallback to today)
  const formatDate = (dateInput?: string | null): string => {
    if (!dateInput) return new Date("2025-10-15").toLocaleDateString();
    const date = new Date(dateInput);
    return isNaN(date.getTime()) 
      ? "No date" 
      : date.toLocaleDateString('en-US', { 
          year: 'numeric', 
          month: 'numeric', 
          day: 'numeric' 
        });
  };

  const handleMarkRead = (e: React.MouseEvent) => {
    e.stopPropagation();
    e.preventDefault();
    if (notif.read) {
      onMarkUnread?.(notif.id);
    } else {
      onMarkRead?.(notif.id);
    }
  };

  const handleDelete = (e: React.MouseEvent) => {
    e.stopPropagation();
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
        onClick={handleModalOpen}
        role="button"
        tabIndex={0}
      >
        <div className="notif-card-body">
          <div className="notif-card-header">
            <h3 className="notif-card-title">{notif.title || "Untitled Notification"}</h3>
            <span className="notif-card-date">
              {formatDate(notif.metadata?.created_at)}
            </span>
          </div>
          <div className="notif-card-divider"></div>
          <p className="notif-card-content">{notif.message || "No message content."}</p>
          
          <div className="notif-card-actions">
            <div className="action-icons">
              {/* Optional Edit icon if needed:
              <button className="action-btn edit-btn" title="Edit">
                <PenSquareIcon size={18} />
              </button>
              */}
              <button 
                className="action-btn mark-read-btn" 
                onClick={handleMarkRead}
                title={notif.read ? "Mark as unread" : "Mark as read"}
              >
                {notif.read ? <MailIcon size={18} /> : <MailOpenIcon size={18} />}
              </button>
              <button 
                className="action-btn delete-btn" 
                onClick={handleDelete}
                title="Delete notification"
              >
                <TrashIcon size={18} />
              </button>
            </div>
          </div>
        </div>
      </div>

      {isModalOpen && (
        <NotificationModal
          notifModal={notif}
          onClose={() => setIsModalOpen(false)}
        />
      )}
    </>
  );
};

export default NotificationCard;