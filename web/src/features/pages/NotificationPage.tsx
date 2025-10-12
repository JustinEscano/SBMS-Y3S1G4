import React from "react";
import PageLayout from "./PageLayout";
import NotificationCard from "./NotificationCard";
import "../components/Notifications.css";
import { useNotifications } from "../hooks/useNotification";
import type { Notification } from "../types/notificationTypes";
import { notificationService } from "../services/notificationService";

const NotificationPage: React.FC = () => {
  const userId = localStorage.getItem("user_id");
  const { notifications, loading, markAsUnread, markAsRead, markAllAsRead } = useNotifications(userId || undefined);

  const handleDelete = async (id: string) => {
    try {
      await notificationService.delete(id);
      // TODO: refetch notifications after delete
    } catch (err) {
      console.error("Failed to delete notification:", err);
    }
  };

  return (
    <PageLayout initialSection={{ parent: "Notification" }}>
      {loading ? (
        <p>Loading notifications...</p>
      ) : notifications.length === 0 ? (
        <p>No notifications found.</p>
      ) : (
        <>
          {/* Mark All as Read Button */}
          <div className="notif-actions left">
            <button className="mark-all-btn" onClick={markAllAsRead}>
              Mark All as Read
            </button>
          </div>

          <div className="notif-grid">
            {notifications.map((notif: Notification) => (
              <NotificationCard
                key={notif.id}
                notif={{
                  id: notif.id,
                  title: notif.title,
                  message: notif.message,
                  created_at: notif.created_at,
                  read: notif.read,
                }}
                onMarkRead={markAsRead}
                onMarkUnread={markAsUnread}
                onDelete={handleDelete}
              />
            ))}
          </div>
        </>
      )}
    </PageLayout>
  );
};

export default NotificationPage;