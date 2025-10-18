import React from "react";
import type { Notification } from "../types/notificationTypes";
import "./Modal.css";

interface NotificationModalProps {
  notifModal: Notification | null;
  onClose: () => void;
}

const NotificationModal: React.FC<NotificationModalProps> = ({ notifModal, onClose }) => {
  if (!notifModal) return null;

  // Safe formatDate with fallback to today (Oct 15, 2025)
  const formatDate = (dateInput?: string | null): string => {
    if (!dateInput) return new Date("2025-10-15").toLocaleString(undefined, {  // Fallback to current date
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
    const date = new Date(dateInput);
    return isNaN(date.getTime()) 
      ? "No date" 
      : date.toLocaleString(undefined, {
          year: "numeric",
          month: "short",
          day: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        });  // e.g., "Oct 14, 2025, 3:51 PM" (from log dates, adjusted for locale)
  };

  return (
    <div className="modal-backdrop" style={{ zIndex: 900 }}>
      <div className="modal" style={{ zIndex: 1000 }}>
        <div className="modal-header">
          <h2>{notifModal.title || "Untitled"}</h2>
          <button className="modal-close" onClick={onClose}>
            &times;
          </button>
        </div>

        <div className="modal-content">
          <div className="notif-view">
            <p>
              <strong>Message:</strong>
              <br />
              {notifModal.message || "No message content available."}
            </p>
            <br />
            <p>
              <strong>Date:</strong> <i>{formatDate(notifModal.metadata?.created_at)}</i>
            </p>
          </div>

          <div className="modal-actions">
            <button onClick={onClose}>OK</button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default NotificationModal;