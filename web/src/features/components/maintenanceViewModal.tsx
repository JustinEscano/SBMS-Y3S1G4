import React, { useState } from "react";
import type { MaintenanceRequest, User, Attachment } from "../types/dashboardTypes";
import { maintenanceService } from "../services/maintenanceService";
import "./Modal.css";
import "./maintenanceOnly.css";

interface MaintenanceViewModalProps {
  request: MaintenanceRequest;
  users: User[];
  onClose: () => void;
  onRefresh: () => void; // to reconcile with backend
  updateRequest?: (id: string, data: Partial<MaintenanceRequest>) => Promise<MaintenanceRequest>;
}

const MaintenanceViewModal: React.FC<MaintenanceViewModalProps> = ({
  request,
  users,
  onClose,
  onRefresh,
  updateRequest,
}) => {
  if (!request) return null;

  const reportedBy = users.find((u) => u.id === request.user);

  const [page, setPage] = useState<1 | 2>(1);
  const [response, setResponse] = useState(request.response ?? "");
  const [assignedTo, setAssignedTo] = useState(request.assigned_to ?? "");
  const [attachments, setAttachments] = useState<Attachment[]>(request.attachments ?? []);
  const [newFile, setNewFile] = useState<File | null>(null);

  // --- Respond (optimistic update) ---
  const handleRespond = (): void => {
    const payload: { response: string; assigned_to?: string } = {
      response: response,
      assigned_to: assignedTo || undefined,
    };

    // 1. Close instantly
    onClose();

    // 2. Optimistic patch (if parent supports it)
    updateRequest?.(request.id!, { ...request, ...payload });

    // 3. Background request (slow server, ~10s)
    maintenanceService
      .respond(request.id!, payload)
      .then(() => onRefresh()) // reconcile with server truth
      .catch((err) => {
        console.error("❌ Failed to respond:", err);
        onRefresh(); // rollback
      });

    // 4. Local reset
    setPage(1);
    setResponse("");
    setAssignedTo("");
    setNewFile(null);
  };

  // --- Upload (optimistic with temp file) ---
  const handleUpload = (): void => {
    if (!newFile) return;

    const tempAttachment: Attachment = {
      id: `temp-${Date.now()}`,
      file: URL.createObjectURL(newFile),
      file_name: newFile.name,
      maintenance_request: request.id!,
      file_type: newFile.type,
      uploaded_at: new Date().toISOString(),
    };

    // 1. Optimistic: show new file instantly
    setAttachments((prev) => [...prev, tempAttachment]);

    const fileToUpload = newFile;
    setNewFile(null);

    // 2. Close instantly
    onClose();

    // 3. Background request
    maintenanceService
      .uploadAttachment(request.id!, fileToUpload)
      .then((realAttachment) => {
        // Replace temp with real one
        setAttachments((prev) =>
          prev.map((a) => (a.id === tempAttachment.id ? realAttachment : a))
        );
        onRefresh();
      })
      .catch((err) => {
        console.error("❌ Failed to upload attachment:", err);
        onRefresh();
      });
  };

  return (
    <div className="modal-backdrop">
      <div className="modal">
        <div className="modal-header">
          <h2>Maintenance Request</h2>
          <button className="modal-close" onClick={onClose}>
            &times;
          </button>
        </div>

        <div className="modal-content">
          <p>
            <strong>Reported by:</strong> {reportedBy?.username || "Unknown"}
          </p>

          {/* Page 1: Attachments */}
          {page === 1 && (
            <div className="section">
              <h3>Attachments</h3>
              {attachments.length ? (
                <ul>
                  {attachments.map((att) => (
                    <li key={att.id}>
                      <a href={att.file} target="_blank" rel="noopener noreferrer">
                        {att.file_name}
                      </a>
                    </li>
                  ))}
                </ul>
              ) : (
                <p>No attachments</p>
              )}

              <div style={{ marginTop: "10px" }}>
                <input
                  type="file"
                  onChange={(e) => setNewFile(e.target.files?.[0] ?? null)}
                />
                <button
                  onClick={handleUpload}
                  disabled={!newFile}
                  style={{ marginLeft: "5px" }}
                >
                  Upload
                </button>
              </div>

              <div className="modal-actions">
                <button className="btn btn-primary" onClick={() => setPage(2)}>
                  Next
                </button>
                <button className="btn btn-secondary" onClick={onClose}>
                  Close
                </button>
              </div>
            </div>
          )}

          {/* Page 2: Respond & Assign */}
          {page === 2 && (
            <div className="section">
              <h3>Respond & Assign</h3>

              <label>
                Response:
                <textarea
                  value={response}
                  onChange={(e) => setResponse(e.target.value)}
                  rows={3}
                  placeholder="Add your response..."
                />
              </label>

              <label>
                Assign to:
                <select
                  value={assignedTo}
                  onChange={(e) => setAssignedTo(e.target.value)}
                >
                  <option value="">Unassigned</option>
                  {users.map((u) => (
                    <option key={u.id} value={u.id}>
                      {u.username}
                    </option>
                  ))}
                </select>
              </label>

              <div className="modal-actions">
                <button className="btn btn-primary" onClick={handleRespond}>
                  Submit
                </button>
                <button className="btn btn-secondary" onClick={() => setPage(1)}>
                  Back
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default MaintenanceViewModal;
