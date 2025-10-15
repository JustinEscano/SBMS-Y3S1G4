import { useEffect, useState, useCallback } from "react";
import { notificationService } from "../services/notificationService";
import type { Notification } from "../types/notificationTypes";

export const useNotifications = (userId?: string, pollInterval = 30000) => {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState<boolean>(true);

  // Utility to normalize dates (fallback to now if invalid/missing)
  const normalizeNotification = useCallback((notif: Notification): Notification => {
    const createdAt = notif.metadata?.created_at;
    const date = createdAt ? new Date(createdAt) : new Date(); // Defaults to Oct 15, 2025
    return {
      ...notif,
      metadata: {
        user_name: notif.metadata?.user_name ?? "",
        category_display: notif.metadata?.category_display ?? "",
        created_at: isNaN(date.getTime()) ? new Date().toISOString() : (createdAt ?? ""),
      },
    };
  }, []);

  const fetchNotifications = useCallback(async () => {
    setLoading(true);
    try {
      const data = userId
        ? await notificationService.getByUserId(userId)
        : await notificationService.getAll();
      
      // Normalize dates and log (now accesses nested)
      const normalizedData = data.map(normalizeNotification);+
      
      setNotifications(normalizedData);
    } catch (err: any) {
      console.error(err);
      setNotifications([]); // Fallback to empty on error
    } finally {
      setLoading(false);
    }
  }, [userId, normalizeNotification]);

  useEffect(() => {
    fetchNotifications();
    const interval = setInterval(fetchNotifications, pollInterval);
    return () => clearInterval(interval);
  }, [fetchNotifications, pollInterval, userId]); // Added userId dep

  const markAsRead = useCallback(async (id: string) => {
    try {
      await notificationService.markAsRead(id);
      setNotifications(prev =>
        prev.map(n => (n.id === id ? { ...n, read: true } : n)) // Preserves metadata
      );
    } catch (err: any) {
      console.error(`Failed to mark notification ${id} as read:`, err);
    }
  }, []);

  const markAsUnread = useCallback(async (id: string) => {
    try {
      await notificationService.markAsUnread(id);
      setNotifications(prev =>
        prev.map(n => (n.id === id ? { ...n, read: false } : n)) // Preserves metadata
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
      setNotifications(prev => prev.map(n => ({ ...n, read: true }))); // Preserves metadata
      fetchNotifications(); // Refetch to sync
    } catch (err: any) {
      console.error("Failed to mark all notifications as read:", err);
    }
  }, [notifications]);

  return {
    notifications,
    loading,
    fetchNotifications,
    markAsRead,
    markAsUnread,
    markAllAsRead,
  };
};