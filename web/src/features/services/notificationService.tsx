import type { Notification } from "../types/notificationTypes.tsx";
import axiosInstance from "../../service/AppService.tsx";

const BASE_URL = "/api/notification/";

export const notificationService = {
  // Get all notifications (raw, from backend)
  getAll: async (): Promise<Notification[]> => {
    try {
      const res = await axiosInstance.get<Notification[]>(BASE_URL);
      return res.data;
    } catch (error: any) {
      console.error("Error fetching notifications:", error.response?.data || error);
      throw error;
    }
  },

  // Get notifications for a specific user (frontend filter)
  getByUserId: async (userId: string): Promise<Notification[]> => {
  try {
    const allNotifications = await notificationService.getAll();
    return allNotifications.filter((n) => {
      // If user is object with id
      if (typeof n.user === "object" && n.user !== null) {
        return n.user.id === userId;
      }
      // If user is just a string, compare directly
      return n.user === userId;
    });
  } catch (error: any) {
    console.error(`Error fetching notifications for user ${userId}:`, error.response?.data || error);
    throw error;
  }
},

  // Get unread notifications for a user
  getUnreadByUserId: async (userId: string): Promise<Notification[]> => {
    try {
      const userNotifications = await notificationService.getByUserId(userId);
      return userNotifications.filter((n) => !n.read);
    } catch (error: any) {
      console.error(`Error fetching unread notifications for user ${userId}:`, error.response?.data || error);
      throw error;
    }
  },

  // Create a notification (admin/system)
  create: async (payload: Partial<Notification>): Promise<Notification> => {
    try {
      const res = await axiosInstance.post<Notification>(BASE_URL, payload);
      return res.data;
    } catch (error: any) {
      console.error("Error creating notification:", error.response?.data || error);
      throw error;
    }
  },

  // Mark a notification as read
  markAsRead: async (id: string): Promise<Notification> => {
    try {
      const res = await axiosInstance.patch<Notification>(`${BASE_URL}${id}/`, { read: true });
      return res.data;
    } catch (error: any) {
      console.error(`Error marking notification ${id} as read:`, error.response?.data || error);
      throw error;
    }
  },

  // Mark a notification as unread
  markAsUnread: async (id: string): Promise<Notification> => {
    try {
      const res = await axiosInstance.patch<Notification>(`${BASE_URL}${id}/`, { read: false });
      return res.data;
    } catch (error: any) {
      console.error(`Error marking notification ${id} as unread:`, error.response?.data || error);
      throw error;
    }
  },

  // Mark all notifications as read (frontend fallback)
  markAllAsRead: async (): Promise<void> => {
    try {
      const unread = await notificationService.getAll();
      await Promise.all(
        unread.map((n) =>
          notificationService.markAsRead(n.id).catch((err) => {
            console.error(`Failed to mark notification ${n.id} as read:`, err);
          })
        )
      );
    } catch (error: any) {
      console.error("Error marking all notifications as read:", error.response?.data || error);
      throw error;
    }
  },

  // Delete a notification
  delete: async (id: string): Promise<void> => {
    try {
      await axiosInstance.delete(`${BASE_URL}${id}/`);
    } catch (error: any) {
      console.error(`Error deleting notification ${id}:`, error.response?.data || error);
      throw error;
    }
  },
};
