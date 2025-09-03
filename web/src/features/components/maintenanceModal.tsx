import React, { useState, useEffect } from "react";
import type { MaintenanceRequest, Equipment, User } from "../types/dashboardTypes";
import "./Modal.css";
import "./maintenanceOnly.css"

export type MaintenanceModalMode = "add" | "edit" | "delete";

interface MaintenanceModalProps {
  mode: MaintenanceModalMode;
  request?: MaintenanceRequest;
  equipments: Equipment[];
  users: User[];
  onClose: () => void;
  onSubmit: (data: Partial<MaintenanceRequest>) => void;
}

const MaintenanceModal: React.FC<MaintenanceModalProps> = ({
  mode,
  request,
  equipments,
  users,
  onClose,
  onSubmit,
}) => {
  const [formData, setFormData] = useState({
    user: "",
    equipment: "",
    issue: "",
    status: "" as MaintenanceRequest["status"],
    scheduled_date: "",
    resolved_at: "",
  });

  useEffect(() => {
    if ((mode === "edit" || mode === "delete") && request) {
      setFormData({
        user: request.user ?? "",
        equipment: request.equipment ?? "",
        issue: request.issue,
        status: request.status,
        scheduled_date: request.scheduled_date,
        resolved_at: request.resolved_at ?? "",
      });
    }
  }, [mode, request]);

  const handleChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>
  ) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (mode === "add") {
      onSubmit({
        user: formData.user,
        equipment: formData.equipment,
        issue: formData.issue,
        status: formData.status,
        scheduled_date: formData.scheduled_date,
        resolved_at: formData.resolved_at || null,
      });
    } else if (mode === "edit" && request) {
      onSubmit({
        id: request.id,
        user: formData.user,
        equipment: formData.equipment,
        issue: formData.issue,
        status: formData.status,
        scheduled_date: formData.scheduled_date,
        resolved_at: formData.resolved_at || null,
      });
    } else if (mode === "delete" && request) {
      onSubmit({ id: request.id });
    }
  };

  // Find names for delete modal
  const selectedEquipment = equipments.find((eq) => eq.id === formData.equipment);

  return (
    <div className="modal-backdrop">
      <div className="modal">
        <div className="modal-header">
          <h2>
            {mode === "add" && "Add Maintenance Request"}
            {mode === "edit" && "Edit Maintenance Request"}
            {mode === "delete" && "Delete Maintenance Request"}
          </h2>
          <button className="modal-close" onClick={onClose}>
            &times;
          </button>
        </div>

        {mode === "delete" ? (
          <div className="modal-content">
            <p>
              Are you sure you want to delete request for{" "}
              <strong>{selectedEquipment?.name ?? "Unknown Equipment"}</strong>{" "}
              issue <strong>{request?.issue}</strong>?
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
            <label>User:</label>
            <select
              name="user"
              value={formData.user}
              onChange={handleChange}
              required
            >
              <option value="">Select user</option>
              {users.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.username}
                </option>
              ))}
            </select>

            <label>Equipment:</label>
            <select
              name="equipment"
              value={formData.equipment}
              onChange={handleChange}
              required
            >
              <option value="">Select equipment</option>
              {equipments.map((eq) => (
                <option key={eq.id} value={eq.id}>
                  {eq.name}
                </option>
              ))}
            </select>

            <label>Issue:</label>
            <textarea
              name="issue"
              value={formData.issue}
              onChange={handleChange}
              rows={3}
              required
            />

            <label>Status:</label>
            <select
              name="status"
              value={formData.status}
              onChange={handleChange}
              required
            >
              <option value="">Select status</option>
              <option value="Pending">Pending</option>
              <option value="In Progress">In Progress</option>
              <option value="Resolved">Resolved</option>
            </select>

            <label>Scheduled Date:</label>
            <input
              type="date"
              name="scheduled_date"
              value={formData.scheduled_date}
              onChange={handleChange}
              required
            />

            <label>Resolved At:</label>
            <input
              type="datetime-local"
              name="resolved_at"
              value={formData.resolved_at}
              onChange={handleChange}
            />

            <div className="modal-actions">
              <button type="submit" className="save-btn">
                {mode === "add" && "Add"}
                {mode === "edit" && "Save"}
              </button>
              <button onClick={onClose}>Cancel</button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};

export default MaintenanceModal;
