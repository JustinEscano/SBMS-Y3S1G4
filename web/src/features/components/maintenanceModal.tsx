import React, { useEffect, useState } from "react";
import type { MaintenanceRequest, Equipment, User } from "../types/dashboardTypes";

export type MaintenanceModalMode = "add" | "edit" | "delete";

interface MaintenanceModalProps {
  mode: MaintenanceModalMode;
  request?: MaintenanceRequest;
  equipments: Equipment[];
  users: User[];
  onClose: () => void;
  onSubmit: (data: Partial<MaintenanceRequest> & { id?: string; comments?: string; newAttachments?: File[] }) => Promise<MaintenanceRequest | void>;
}

const STATUS_OPTIONS: MaintenanceRequest["status"][] = ["pending", "in_progress", "resolved"];

const MaintenanceModal: React.FC<MaintenanceModalProps> = ({ mode, request, equipments, users, onClose, onSubmit }) => {
  const [page, setPage] = useState<1 | 2>(1);
  const [formData, setFormData] = useState({
    user: "",
    equipment: "",
    issue: "",
    status: "pending" as MaintenanceRequest["status"],
    scheduled_date: "",
    resolved_at: "",
    assigned_to: "",
  });
  const [comments, setComments] = useState("");
  const [attachments, setAttachments] = useState<File[]>([]);
  const [submitting, setSubmitting] = useState(false);

  // Initialize form data based on mode
  useEffect(() => {
    if ((mode === "edit" || mode === "delete") && request) {
      setFormData({
        user: request.user || "",
        equipment: request.equipment || "",
        issue: request.issue || "",
        status: request.status || "pending",
        scheduled_date: request.scheduled_date ? request.scheduled_date.split("T")[0] : "",
        resolved_at: request.resolved_at ? request.resolved_at.replace("Z", "") : "",
        assigned_to: request.assigned_to || "",
      });
      setComments(request.comments || "");
    } else if (mode === "add") {
      resetForm();
    }
  }, [mode, request]);

  const resetForm = () => {
    setFormData({
      user: "",
      equipment: "",
      issue: "",
      status: "pending",
      scheduled_date: "",
      resolved_at: "",
      assigned_to: "",
    });
    setComments("");
    setAttachments([]);
    setPage(1);
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      setAttachments(prev => [...prev, ...Array.from(e.target.files as FileList)]);
    }
  };

  const handleSubmit = async () => {
    if (submitting) return;
    setSubmitting(true);
    try {
      const payload: Partial<MaintenanceRequest> & { id?: string; newAttachments?: File[] } = {
        ...formData,
        comments,
        id: request?.id,
        newAttachments: attachments,
        resolved_at: formData.resolved_at ? new Date(formData.resolved_at).toISOString() : undefined,
        assigned_to: formData.assigned_to || undefined,
      };
      await onSubmit(payload);
      resetForm();
      onClose();
    } catch (err) {
      console.error(err);
    } finally {
      setSubmitting(false);
    }
  };

  // Helpers for delete confirmation
  const getUser = (id?: string) => users.find(u => u.id === id)?.username || "-";
  const getEquipment = (id?: string) => equipments.find(e => e.id === id)?.name || "-";

  return (
    <div className="modal-backdrop">
      <div className="modal">
        <div className="modal-header">
          <h2>
            {mode === "add" && "Add Maintenance Request"}
            {mode === "edit" && "Edit Maintenance Request"}
            {mode === "delete" && "Delete Maintenance Request"}
          </h2>
          <button className="modal-close" onClick={onClose}>&times;</button>
        </div>

        <div className="modal-content">
          {/* Delete Confirmation */}
          {mode === "delete" && request && (
            <>
              <p>
                Are you sure you want to delete the maintenance request for <strong>{getEquipment(request.equipment)}</strong> assigned to <strong>{getUser(request.user)}</strong>?
              </p>
              <div className="modal-actions">
                <button className="btn btn-danger" onClick={handleSubmit} disabled={submitting}>Delete</button>
                <button className="btn btn-secondary" onClick={onClose}>Cancel</button>
              </div>
            </>
          )}

          {/* Add Modal Wizard */}
          {mode === "add" && page === 1 && (
            <>
              <label>
                Equipment
                <select name="equipment" value={formData.equipment} onChange={handleChange} required>
                  <option value="">Select Equipment</option>
                  {equipments.map(eq => <option key={eq.id} value={eq.id}>{eq.name}</option>)}
                </select>
              </label>

              <label>
                User
                <select name="user" value={formData.user} onChange={handleChange} required>
                  <option value="">Select User</option>
                  {users.map(u => <option key={u.id} value={u.id}>{u.username || "Unknown User"}</option>)}
                </select>
              </label>

              <label>
                Issue
                <textarea name="issue" value={formData.issue} onChange={handleChange} required />
              </label>

              <label>
                Status
                <select name="status" value={formData.status} onChange={handleChange} required>
                  {STATUS_OPTIONS.map(s => <option key={s} value={s}>{s}</option>)}
                </select>
              </label>

              <label>
                Scheduled Date
                <input type="date" name="scheduled_date" value={formData.scheduled_date} onChange={handleChange} />
              </label>

              <label>
                Resolved At
                <input type="datetime-local" name="resolved_at" value={formData.resolved_at} onChange={handleChange} />
              </label>

              <div className="modal-actions">
                <button className="btn btn-primary" onClick={() => setPage(2)}>Next</button>
                <button className="btn btn-secondary" onClick={onClose}>Cancel</button>
              </div>
            </>
          )}

          {/* Add Modal Page 2 */}
          {mode === "add" && page === 2 && (
            <>
              <label>
                Assigned To
                <select name="assigned_to" value={formData.assigned_to} onChange={handleChange}>
                  <option value="">Select Assignee</option>
                  {users.map(u => <option key={u.id} value={u.id}>{u.username || "Unknown User"}</option>)}
                </select>
              </label>

              <label>
                Comments
                <textarea name="comments" value={comments} onChange={e => setComments(e.target.value)} placeholder="Add comments..." />
              </label>

              <label>
                Attachments
                <input type="file" multiple onChange={handleFileChange} />
                {attachments.length > 0 && (
                  <ul>
                    {attachments.map((f, i) => <li key={i}>{f.name}</li>)}
                  </ul>
                )}
              </label>

              <div className="modal-actions">
                <button className="btn btn-primary" onClick={handleSubmit} disabled={submitting}>Submit</button>
                <button className="btn btn-secondary" onClick={() => setPage(1)}>Back</button>
              </div>
            </>
          )}

          {/* Edit Modal */}
          {mode === "edit" && request && (
            <>
              <label>
                Equipment
                <select name="equipment" value={formData.equipment} onChange={handleChange}>
                  <option value="">Select Equipment</option>
                  {equipments.map(eq => <option key={eq.id} value={eq.id}>{eq.name}</option>)}
                </select>
              </label>

              <label>
                User
                <select name="user" value={formData.user} onChange={handleChange}>
                  <option value="">Select User</option>
                  {users.map(u => <option key={u.id} value={u.id}>{u.username || "Unknown User"}</option>)}
                </select>
              </label>

              <label>
                Issue
                <textarea name="issue" value={formData.issue} onChange={handleChange} />
              </label>

              <label>
                Status
                <select name="status" value={formData.status} onChange={handleChange}>
                  {STATUS_OPTIONS.map(s => <option key={s} value={s}>{s}</option>)}
                </select>
              </label>

              <label>
                Scheduled Date
                <input type="date" name="scheduled_date" value={formData.scheduled_date} onChange={handleChange} />
              </label>

              <label>
                Resolved At
                <input type="datetime-local" name="resolved_at" value={formData.resolved_at} onChange={handleChange} />
              </label>

              <label>
                Comments
                <textarea name="comments" value={comments} onChange={e => setComments(e.target.value)} />
              </label>

              <div className="modal-actions">
                <button className="btn btn-primary" onClick={handleSubmit} disabled={submitting}>Save</button>
                <button className="btn btn-secondary" onClick={onClose}>Cancel</button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

export default MaintenanceModal;
