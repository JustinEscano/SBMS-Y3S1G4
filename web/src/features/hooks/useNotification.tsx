import { useEffect, useState, useCallback } from "react";
import { notificationService } from "../services/notificationService";
import type { Notification } from "../types/notificationTypes";

export const useNotifications = (userId?: string, pollInterval = 30000) => {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error] = useState<string | null>(null);

  const fetchNotifications = useCallback(async () => {
    setLoading(true);
    try {
      const data = userId
        ? await notificationService.getByUserId(userId)
        : await notificationService.getAll();
      setNotifications(data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [userId]);

  useEffect(() => {
    fetchNotifications();
    const interval = setInterval(fetchNotifications, pollInterval);
    return () => clearInterval(interval);
  }, [fetchNotifications, pollInterval]);


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

  const markAllAsRead = useCallback(async () => {
    try {
      const unread = notifications.filter(n => !n.read);
      await Promise.all(
        unread.map(n => notificationService.markAsRead(n.id).catch(console.error))
      );
      setNotifications(prev => prev.map(n => ({ ...n, read: true })));
    } catch (err: any) {
      console.error("Failed to mark all notifications as read:", err);
    }
  }, [notifications]);

  useEffect(() => {
    fetchNotifications();
    const interval = setInterval(fetchNotifications, pollInterval);
    return () => clearInterval(interval);
  }, [fetchNotifications, pollInterval]);

  return {
    notifications,
    loading,
    error,
    fetchNotifications,
    markAsRead,
    markAsUnread,
    markAllAsRead,
  };
};
