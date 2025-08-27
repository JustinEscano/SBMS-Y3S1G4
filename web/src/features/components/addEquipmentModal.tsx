import React, { useState } from "react";
import type { Equipment } from "../types/equipmentTypes";
import type { Room } from "../types/roomTypes";
import "./Modal.css";

interface AddEquipmentModalProps {
  // rooms is an array of room identifiers or room names (strings).
  // If you have objects like { id, name } pass room IDs/labels accordingly.
  rooms: Room[];
  onSubmit: (data: Omit<Equipment, "id" | "created_at">) => void;
  onClose: () => void;
}

const AddEquipmentModal: React.FC<AddEquipmentModalProps> = ({ rooms, onSubmit, onClose }) => {
  // ensure formData includes `room` so Omit<Equipment,"id"|"created_at"> is satisfied
  const [formData, setFormData] = useState<Omit<Equipment, "id" | "created_at">>({
    name: "",
    status: "Active",
    room_id: "",
    room: "",
    type: "",
    qr_code: "",
  });

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    // if the user selected a room_id we also set the `room` display value to the same string
    if (name === "room_id") {
      setFormData(prev => ({ ...prev, room_id: value, room: value }));
    } else {
      setFormData(prev => ({ ...prev, [name]: value } as any));
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <div className="modal-backdrop">
      <div className="modal">
        <div className="modal-header">
          <h2>Add Equipment</h2>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>

        <form onSubmit={handleSubmit} className="modal-content">
          <label>
            Name:
            <input name="name" value={formData.name} onChange={handleChange} required />
          </label>

          <label>
            Type:
            <input name="type" value={formData.type} onChange={handleChange} required />
          </label>

          <label>
            QR Code:
            <input name="qr_code" value={formData.qr_code} onChange={handleChange} />
          </label>

          <label>
            Status:
            <select name="status" value={formData.status} onChange={handleChange}>
              <option value="Active">Active</option>
              <option value="Inactive">Inactive</option>
            </select>
          </label>

          <label>
            Room:
            <select name="room_id" value={formData.room_id} onChange={handleChange} required>
              <option value="">-- Select Room --</option>
              {rooms.map((room) => (
                <option key={room.id} value={room.id}>
                {room.name}
                </option>
              ))}
            </select>
          </label>

          <div className="modal-actions">
            <button type="submit">Add</button>
            <button type="button" onClick={onClose}>Cancel</button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default AddEquipmentModal;
