import React, { useState } from "react";
import type { Equipment } from "../types/equipmentTypes";
import "./Modal.css";

interface EditEquipmentModalProps {
  equipment: Equipment;
  onSubmit: (data: Partial<Equipment>) => void;
  onClose: () => void;
}

const EditEquipmentModal: React.FC<EditEquipmentModalProps> = ({ equipment, onSubmit, onClose }) => {
  const [formData, setFormData] = useState<Partial<Equipment>>({
    ...equipment,
    room: equipment.room ?? "",
    room_id: equipment.room_id ?? "",
  });

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <div className="modal-backdrop">
      <div className="modal">
        <div className="modal-header">
          <h2>Edit Equipment</h2>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>

        <form onSubmit={handleSubmit} className="modal-content">
          <label>
            Name:
            <input name="name" value={formData.name || ""} onChange={handleChange} />
          </label>

          <label>
            Type:
            <input name="type" value={formData.type || ""} onChange={handleChange} />
          </label>

          <label>
            QR Code:
            <input name="qr_code" value={formData.qr_code || ""} onChange={handleChange} />
          </label>

          <label>
            Status:
            <select name="status" value={formData.status || "Active"} onChange={handleChange}>
              <option value="Active">Active</option>
              <option value="Inactive">Inactive</option>
            </select>
          </label>

          {/* Room field - read-only */}
          <label>
            Room:
            <input name="room" value={formData.room || ""} disabled />
          </label>

          <div className="modal-actions">
            <button type="submit">Save</button>
            <button type="button" onClick={onClose}>Cancel</button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default EditEquipmentModal;