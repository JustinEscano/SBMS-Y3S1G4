import React, { useState, useEffect } from "react";
import type { Room } from "../types/dashboardTypes";
import "./Modal.css";

export type RoomModalMode = "add" | "edit" | "delete";

interface RoomModalProps {
  mode: RoomModalMode;
  room?: Room;
  onClose: () => void;
  onSubmit: (data: Partial<Room>) => void;
}

const RoomModal: React.FC<RoomModalProps> = ({ mode, room, onClose, onSubmit }) => {
  const [formData, setFormData] = useState({
    name: "",
    floor: "",
    capacity: "",
    type: "",
    occupancy: "",
  });

  // Pre-fill form for edit/delete
  useEffect(() => {
    if ((mode === "edit" || mode === "delete") && room) {
      setFormData({
        name: room.name,
        floor: room.floor.toString(),
        capacity: room.capacity?.toString() ?? "",
        type: room.type ?? "",
        occupancy: room.occupancy ?? "vacant"
      });
    }
  }, [mode, room]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (mode === "add") {
      onSubmit({
        name: formData.name,
        floor: Number(formData.floor),
        capacity: Number(formData.capacity) || 0,
        type: formData.type,
        occupancy: formData.occupancy as "vacant" | "occupied" | "reserved",
      });
    } else if (mode === "edit" && room) {
      onSubmit({
        id: room.id,
        name: formData.name,
        floor: Number(formData.floor),
        capacity: Number(formData.capacity) || 0,
        type: formData.type,
        occupancy: formData.occupancy as "vacant" | "occupied" | "reserved",
      });
    } else if (mode === "delete" && room) {
      onSubmit({ id: room.id });
    }
  };

  return (
    <div className="modal-backdrop" style={{ zIndex: 900 }}> {/* stays behind dropdowns */}
      <div className="modal" style={{ zIndex: 1000 }}>
        <div className="modal-header">
          <h2>
            {mode === "add" && "Add Room"}
            {mode === "edit" && "Edit Room"}
            {mode === "delete" && "Delete Room"}
          </h2>
          <button className="modal-close" onClick={onClose}>
            &times;
          </button>
        </div>

        {mode === "delete" ? (
          <div className="modal-content">
            <p>
              Are you sure you want to delete <strong>{room?.name}</strong> on Floor{" "}
              {room?.floor}?
            </p>
            <div className="modal-actions">
              <button onClick={handleSubmit} className="delete-btn">
                Delete
              </button>
              <button onClick={onClose}>Cancel</button>
            </div>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="modal-content">
            <label>Room Name:</label>
            <input
              type="text"
              name="name"
              value={formData.name}
              onChange={handleChange}
              required
            />

            <label>Floor:</label>
            <input
              type="number"
              name="floor"
              value={formData.floor}
              onChange={handleChange}
              required
            />

            <label>Capacity:</label>
            <input
              type="number"
              name="capacity"
              value={formData.capacity}
              onChange={handleChange}
            />

            <label>Type:</label>
              <select name="type" value={formData.type} onChange={handleChange} required>
                <option value="">Select type</option>
                <option value="office">Office</option>
                <option value="lab">Laboratory</option>
                <option value="meeting">Meeting Room</option>
                <option value="storage">Storage</option>
                <option value="corridor">Corridor</option>
                <option value="utility">Utility</option>
            </select>

            <label>Occupancy:</label>
            <select name="occupancy" value={formData.occupancy} onChange={handleChange}>
              <option value="vacant">Vacant</option>
              <option value="occupied">Occupied</option>
              <option value="reserved">Reserved</option>
            </select>

            <div className="modal-actions">
              <button type="submit">{mode === "add" ? "Add" : "Save"}</button>
              <button type="button" onClick={onClose}>
                Cancel
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};

export default RoomModal;
