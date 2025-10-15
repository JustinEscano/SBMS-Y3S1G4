import React, { useState } from "react";
import { PenSquareIcon, TrashIcon, EyeIcon } from "lucide-react";
import NotificationModal from "../components/notificationModal";
import "../components/Notifications.css";
import type { Notification } from "../types/notificationTypes";  // Import for type consistency

// Use full Notification type for props (ensures metadata)
interface NotificationCardProps {
  notif: Notification;  // Now matches hook output
  onMarkUnread?: (id: string) => void;
  onMarkRead?: (id: string) => void;
  onDelete?: (id: string) => void;
}

const NotificationCard: React.FC<NotificationCardProps> = ({ notif, onMarkUnread, onMarkRead, onDelete }) => {
  const [isModalOpen, setIsModalOpen] = useState(false);

  // Safe formatDate (string input, fallback to today: Oct 15, 2025)
  const formatDate = (dateInput?: string | null): string => {
    if (!dateInput) return new Date("2025-10-15").toLocaleDateString();  // Fallback to current date
    const date = new Date(dateInput);
    return isNaN(date.getTime()) 
      ? "No date" 
      : date.toLocaleDateString('en-US', { 
          year: 'numeric', 
          month: 'numeric', 
          day: 'numeric' 
        });  // e.g., "10/14/2025" from log dates
  };

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
            <span className="notif-card-date">
              {formatDate(notif.metadata?.created_at)}  {/* Nested access */}
            </span>
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
            ...notif,  // Spread full notif (includes metadata, read, etc.)
            // Override if needed; metadata is already there with created_at
          }}
          onClose={() => setIsModalOpen(false)}
        />
      )}
    </>
  );
};

export default NotificationCard;