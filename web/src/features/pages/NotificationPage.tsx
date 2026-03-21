import React from "react";
import PageLayout from "./PageLayout";
import NotificationCard from "./NotificationCard";
import { useNotifications } from "../hooks/useNotification";
import type { Notification } from "../types/notificationTypes";
import { Bell, CheckCheck } from "lucide-react";

const NotificationPage: React.FC = () => {
  const userId = localStorage.getItem("user_id");
  const { notifications, loading, markAsUnread, markAsRead, markAllAsRead, deleteNotification } = useNotifications(userId || undefined);

  const unreadCount = notifications.filter(n => !n.read).length;

  return (
    <PageLayout initialSection={{ parent: "Notification" }}>
      {/* Page Header */}
      <div style={{ marginBottom: '32px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '16px', flexWrap: 'wrap' }}>
        <div>
          <h1 style={{ fontSize: '28px', fontWeight: 800, color: '#ffffff', margin: 0, letterSpacing: '-0.02em' }}>Notifications</h1>
          <p style={{ fontSize: '14px', color: '#64748b', margin: '4px 0 0' }}>
            {unreadCount > 0 ? `${unreadCount} unread notification${unreadCount !== 1 ? 's' : ''}` : 'All caught up!'}
          </p>
        </div>
        <button
          onClick={markAllAsRead}
          disabled={loading || notifications.length === 0 || unreadCount === 0}
          style={{
            display: 'inline-flex', alignItems: 'center', gap: '8px',
            padding: '10px 18px', borderRadius: '10px', border: '1px solid #1e293b',
            background: '#1e293b', color: unreadCount > 0 ? '#e2e8f0' : '#64748b',
            fontSize: '14px', fontWeight: 600, cursor: unreadCount > 0 ? 'pointer' : 'not-allowed',
          }}
        >
          <CheckCheck size={16} /> Mark All as Read
        </button>
      </div>

      {loading ? (
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '80px 20px', gap: '16px' }}>
          <div style={{ width: '40px', height: '40px', borderRadius: '50%', border: '3px solid #3b82f6', borderTopColor: 'transparent', animation: 'spin 1s linear infinite' }} />
          <p style={{ color: '#64748b', fontSize: '14px' }}>Loading notifications...</p>
        </div>
      ) : notifications.length === 0 ? (
        <div style={{ background: '#0f172a', border: '1px solid #1e293b', borderRadius: '16px', padding: '80px 20px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '16px' }}>
          <div style={{ width: '72px', height: '72px', borderRadius: '50%', background: 'rgba(59,130,246,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Bell size={32} color="#3b82f6" />
          </div>
          <div style={{ textAlign: 'center' }}>
            <h3 style={{ fontSize: '18px', fontWeight: 700, color: '#ffffff', margin: '0 0 8px' }}>You're all caught up!</h3>
            <p style={{ fontSize: '14px', color: '#64748b', margin: 0 }}>No new notifications to display at the moment.</p>
          </div>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
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
      )}
    </PageLayout>
  );
};

export default NotificationPage;
