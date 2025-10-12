import React from "react";
import type { Notification } from "../types/notificationTypes";
import "./Modal.css";

interface NotificationModalProps {
  notifModal: Notification | null;
  onClose: () => void;
}

const NotificationModal: React.FC<NotificationModalProps> = ({ notifModal, onClose }) => {
  if (!notifModal) return null;

  const formatDate = (date: string) =>
    new Date(date).toLocaleString(undefined, {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });

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
              <strong>Date:</strong> <i>{formatDate(notifModal.created_at)}</i>
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
