import { useEffect, useState, useCallback } from "react";
import { notificationService } from "../services/notificationService";
import type { Notification } from "../types/notificationTypes";

export const useNotifications = (userId?: string, pollInterval = 30000) => {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState<boolean>(true);

  // ✅ Normalize notification metadata
  const normalizeNotification = useCallback((notif: Notification): Notification => {
    const createdAt = notif.metadata?.created_at;
    const date = createdAt ? new Date(createdAt) : new Date();
    return {
      ...notif,
      metadata: {
        user_name: notif.metadata?.user_name ?? "",
        category_display: notif.metadata?.category_display ?? "",
        created_at: isNaN(date.getTime())
          ? new Date().toISOString()
          : (createdAt ?? ""),
      },
    };
  }, []);

  // ✅ Fetch notifications
  const fetchNotifications = useCallback(async () => {
    setLoading(true);
    try {
      const data = userId
        ? await notificationService.getByUserId(userId)
        : await notificationService.getAll();

      const normalizedData = data.map(normalizeNotification);
      setNotifications(normalizedData);
    } catch (err: any) {
      console.error(err);
      setNotifications([]);
    } finally {
      setLoading(false);
    }
  }, [userId, normalizeNotification]);

  // BUG FIX: Removed `userId` from deps — it was already captured inside
  // `fetchNotifications` via useCallback. Having it here AND there caused a
  // double-fetch every time userId changed (once from fetchNotifications
  // reference changing, once from userId itself). Now only fetchNotifications
  // and pollInterval drive the effect.
  useEffect(() => {
    fetchNotifications();
    const interval = setInterval(fetchNotifications, pollInterval);
    return () => clearInterval(interval);
  }, [fetchNotifications, pollInterval]);

  // ✅ Mark as read
  const markAsRead = useCallback(async (id: string) => {
    try {
      await notificationService.markAsRead(id);
      setNotifications(prev =>
        prev.map(n => (n.id === id ? { ...n, read: true } : n))
      );
    } catch (err: any) {
      console.error(`Failed to mark notification ${id} as read:`, err);
    }
  }, []);

  // ✅ Mark as unread
  const markAsUnread = useCallback(async (id: string) => {
    try {
      await notificationService.markAsUnread(id);
      setNotifications(prev =>
        prev.map(n => (n.id === id ? { ...n, read: false } : n))
      );
    } catch (err: any) {
      console.error(`Failed to mark notification ${id} as unread:`, err);
    }
  }, []);

  // ✅ Mark all as read
  const markAllAsRead = useCallback(async () => {
    try {
      const unread = notifications.filter(n => !n.read);
      await Promise.all(
        unread.map(n => notificationService.markAsRead(n.id).catch(console.error))
      );
      setNotifications(prev => prev.map(n => ({ ...n, read: true })));
      fetchNotifications(); // Sync with backend
    } catch (err: any) {
      console.error("Failed to mark all notifications as read:", err);
    }
  }, [notifications, fetchNotifications]);

  // ✅ Delete a single notification
  const deleteNotification = useCallback(async (id: string) => {
    try {
      await notificationService.delete(id);
      setNotifications(prev => prev.filter(n => n.id !== id));
    } catch (err: any) {
      console.error(`Failed to delete notification ${id}:`, err);
    }
  }, []);

  return {
    notifications,
    loading,
    fetchNotifications,
    markAsRead,
    markAsUnread,
    markAllAsRead,
    deleteNotification, // ✅ expose it
  };
};
