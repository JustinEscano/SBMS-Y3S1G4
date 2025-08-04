import axiosInstance from '../../service/AppService';
import type { Room } from '../types/roomTypes';

export const getAllRooms = async (): Promise<Room[]> => {
  const res = await axiosInstance.get<Room[]>('/api/rooms/');
  return res.data;
};

export const getRoomById = async (id: string): Promise<Room> => {
  const res = await axiosInstance.get<Room>(`/api/rooms/${id}/`);
  return res.data;
};

export const createRoom = async (roomData: Partial<Room>): Promise<Room> => {
  const res = await axiosInstance.post<Room>('/api/rooms/', roomData);
  return res.data;
};

export const updateRoom = async (
  id: string,
  roomData: Partial<Room>
): Promise<Room> => {
  const res = await axiosInstance.put<Room>(`/api/rooms/${id}/`, roomData);
  return res.data;
};

export const deleteRoom = async (id: string): Promise<void> => {
  await axiosInstance.delete(`/api/rooms/${id}/`);
};
