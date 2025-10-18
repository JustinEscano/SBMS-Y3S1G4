import React from "react";
import PageLayout from "./PageLayout";
import NotificationCard from "./NotificationCard";
import "../components/Notifications.css";
import { useNotifications } from "../hooks/useNotification";
import type { Notification } from "../types/notificationTypes";

const NotificationPage: React.FC = () => {
  const userId = localStorage.getItem("user_id");
  const {
    notifications,
    loading,
    markAsUnread,
    markAsRead,
    markAllAsRead,
    deleteNotification,
  } = useNotifications(userId || undefined);

  return (
    <PageLayout initialSection={{ parent: "Notification" }}>
      {loading ? (
        <p>Loading notifications...</p>
      ) : notifications.length === 0 ? (
        <p>No notifications found.</p>
      ) : (
        <>
          <div className="notif-actions left">
            <button className="mark-all-btn" onClick={markAllAsRead}>
              Mark All as Read
            </button>
          </div>

          <div className="notif-grid">
            {notifications.map((notif: Notification) => (
              <NotificationCard
                key={notif.id}
                notif={notif}
                onMarkRead={markAsRead}
                onMarkUnread={markAsUnread}
                onDelete={deleteNotification}
              />
            ))}
          </div>
        </>
      )}
    </PageLayout>
  );
};

export default NotificationPage;
