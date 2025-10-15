import { useEffect, useState, useCallback } from "react";
import { notificationService } from "../services/notificationService";
import type { Notification } from "../types/notificationTypes";

export const useNotifications = (userId?: string, pollInterval = 30000) => {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  // 🔹 Fetch notifications
  const fetchNotifications = useCallback(async () => {
    setLoading(true);
    try {
      const data = userId
        ? await notificationService.getByUserId(userId)
        : await notificationService.getAll();
      setNotifications(data);
      setError(null);
    } catch (err: any) {
      console.error("Failed to fetch notifications:", err);
      setError("Failed to load notifications");
    } finally {
      setLoading(false);
    }
  }, [userId]);

  // 🔹 Poll periodically
  useEffect(() => {
    fetchNotifications();
    const interval = setInterval(fetchNotifications, pollInterval);
    return () => clearInterval(interval);
  }, [fetchNotifications, pollInterval]);

  // 🔹 Helper to sync sidebar instantly
  const triggerSidebarUpdate = () => {
    localStorage.setItem("notificationsUpdated", Date.now().toString());
  };

  // 🔹 Mark read/unread
  const markAsRead = useCallback(async (id: string) => {
    try {
      await notificationService.markAsRead(id);
      setNotifications(prev =>
        prev.map(n => (n.id === id ? { ...n, read: true } : n))
      );
      triggerSidebarUpdate();
    } catch (err) {
      console.error(`Failed to mark notification ${id} as read:`, err);
    }
  }, []);

  const markAsUnread = useCallback(async (id: string) => {
    try {
      await notificationService.markAsUnread(id);
      setNotifications(prev =>
        prev.map(n => (n.id === id ? { ...n, read: false } : n))
      );
      triggerSidebarUpdate();
    } catch (err) {
      console.error(`Failed to mark notification ${id} as unread:`, err);
    }
  }, []);

  // 🔹 Mark all as read
  const markAllAsRead = useCallback(async () => {
    try {
      const unread = notifications.filter(n => !n.read);
      await Promise.all(
        unread.map(n => notificationService.markAsRead(n.id).catch(console.error))
      );
      setNotifications(prev => prev.map(n => ({ ...n, read: true })));
      triggerSidebarUpdate();
    } catch (err) {
      console.error("Failed to mark all notifications as read:", err);
    }
  }, [notifications]);

  // 🔹 Delete notification
  const deleteNotification = useCallback(async (id: string) => {
    try {
      await notificationService.delete(id);
      setNotifications(prev => prev.filter(n => n.id !== id));
      triggerSidebarUpdate();
    } catch (err) {
      console.error(`Failed to delete notification ${id}:`, err);
    }
  }, []);

  return {
    notifications,
    loading,
    error,
    fetchNotifications,
    markAsRead,
    markAsUnread,
    markAllAsRead,
    deleteNotification,
  };
};
