import React, { useMemo, useState, useCallback, useEffect } from "react";
import PageLayout from "../pages/PageLayout";
import Pagination from "../components/Pagination";
import MaintenanceModal from "../components/maintenanceModal";
import type { MaintenanceModalMode } from "../components/maintenanceModal";
import MaintenanceViewModal from "../components/maintenanceViewModal";
import { useMaintenanceRequests } from "../hooks/useMaintenance";
import { useEquipment } from "../hooks/useEquipment";
import { userService } from "../services/userService";
import { maintenanceService } from "../services/maintenanceService";
import type { MaintenanceRequest, User } from "../types/dashboardTypes";
import "../pages/PageStyle.css";

type MaintenanceFormData = Partial<MaintenanceRequest> & {
  id?: string;
  newAttachments?: File[];
  comments?: string;
};

const ITEMS_PER_PAGE = 5;

const STATUS_MAP: Record<string, "pending" | "in_progress" | "resolved"> = {
  pending: "pending",
  in_progress: "in_progress",
  resolved: "resolved",
};

type ModalType = MaintenanceModalMode | "view" | null;

const MaintenancePage: React.FC = () => {
  const { requests, loading, error, updateRequest, deleteRequest, refetch } = useMaintenanceRequests();
  const { equipment } = useEquipment();

  const [users, setUsers] = useState<User[]>([]);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [modalType, setModalType] = useState<ModalType>(null);
  const [selectedRequest, setSelectedRequest] = useState<MaintenanceRequest | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [, setErrorMsg] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const formatDate = (dateStr?: string) => {
    if (!dateStr) return "-";
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return "-";

    const yyyy = d.getFullYear();
    const mm = String(d.getMonth() + 1).padStart(2, "0");
    const dd = String(d.getDate()).padStart(2, "0");
    const hh = String(d.getHours()).padStart(2, "0");
    const min = String(d.getMinutes()).padStart(2, "0");

    return `${yyyy}-${mm}-${dd} ${hh}:${min}`;
  };

  // Fetch users
  useEffect(() => {
    const fetchUsers = async () => {
      try {
        const data = await userService.getAll();
        setUsers(data);
      } catch (err) {
        console.error("Failed to fetch users:", err);
      }
    };
    fetchUsers();
  }, []);

  // Modal handlers
  const openModal = useCallback((type: ModalType, request?: MaintenanceRequest) => {
    setModalType(type);
    setSelectedRequest(request ?? null);
    setErrorMsg(null);
  }, []);

  const closeModal = useCallback(() => {
    setModalType(null);
    setSelectedRequest(null);
    setErrorMsg(null);
  }, []);

  // Filtering + pagination
  const filteredRequests = useMemo(() => {
    const term = search.toLowerCase();
    return requests.filter((r) => {
      const matchesSearch = (r.issue ?? "").toLowerCase().includes(term);
      const matchesStatus =
        statusFilter === "all" ||
        (r.status ?? "").toLowerCase() === statusFilter.toLowerCase();
      return matchesSearch && matchesStatus;
    });
  }, [requests, search, statusFilter]);

  const totalPages = Math.max(1, Math.ceil(filteredRequests.length / ITEMS_PER_PAGE));
  const paginatedRequests = filteredRequests.slice(
    (currentPage - 1) * ITEMS_PER_PAGE,
    currentPage * ITEMS_PER_PAGE
  );

  const getUser = useCallback(
    (id?: string) => (id ? users.find((u) => u.id === id)?.username || id : "-"),
    [users]
  );
  const getEquipment = useCallback(
    (id?: string) => (id ? equipment.find((e) => e.id === id)?.name || id : "-"),
    [equipment]
  );

  const handleAdd = async (data: MaintenanceFormData): Promise<void> => {
  setSubmitting(true);

  // Optimistic: close modal right away
  closeModal();

  // Optimistic: add placeholder request
  const tempId = `temp-${Date.now()}`;
  const optimisticRequest: MaintenanceRequest = {
    id: tempId,
    user: data.user!,
    equipment: data.equipment!,
    issue: data.issue || "",
    status: data.status ? STATUS_MAP[data.status.toLowerCase()] : "pending",
    scheduled_date: data.scheduled_date || new Date().toISOString().split("T")[0],
    resolved_at: data.resolved_at,
    assigned_to: data.assigned_to,
    comments: data.comments || "",
    attachments: []
  };

  updateRequest(tempId, optimisticRequest); // put into state immediately

  try {
    const created = await maintenanceService.create(optimisticRequest);

    if (data.newAttachments?.length) {
      for (const file of data.newAttachments) {
        await maintenanceService.uploadAttachment(created.id!, file);
      }
    }

    // Replace temp with real one
    updateRequest(tempId, created);
  } catch (err) {
    console.error("Failed to create request:", err);
    // Rollback: refetch from server
    await refetch();
  } finally {
    setSubmitting(false);
  }
};

// EDIT
const handleEdit = async (data: MaintenanceFormData): Promise<void> => {
  if (!selectedRequest) return;

  setSubmitting(true);
  closeModal();

  const payload: Partial<MaintenanceRequest> = {
    issue: data.issue,
    status: data.status ? STATUS_MAP[data.status.toLowerCase()] : selectedRequest.status,
    scheduled_date: data.scheduled_date || selectedRequest.scheduled_date,
    resolved_at: data.resolved_at,
    assigned_to: data.assigned_to,
    comments: data.comments,
  };

  // Optimistic update
  updateRequest(selectedRequest.id, { ...selectedRequest, ...payload });

  try {
    await maintenanceService.update(selectedRequest.id, payload);

    if (data.newAttachments?.length) {
      for (const file of data.newAttachments) {
        await maintenanceService.uploadAttachment(selectedRequest.id, file);
      }
    }
  } catch (err) {
    console.error("Failed to update request:", err);
    await refetch(); // rollback
  } finally {
    setSubmitting(false);
  }
};

// DELETE
const handleDelete = async (): Promise<void> => {
  if (!selectedRequest) return;

  setSubmitting(true);
  closeModal();

  // Optimistic: remove from UI immediately
  updateRequest(selectedRequest.id, null as any); // or filter out manually

  try {
    await deleteRequest(selectedRequest.id);
  } catch (err) {
    console.error("Failed to delete request:", err);
    await refetch(); // rollback
  } finally {
    setSubmitting(false);
  }
};


  return (
    <PageLayout initialSection={{ parent: "Dashboard", child: "Maintenance" }}>
      <h1>Dashboard &gt; Maintenance Requests</h1>

      <div className="content-container">
        {/* Controls */}
        <div className="table-controls">
          <input
            type="text"
            placeholder="Search requests..."
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setCurrentPage(1);
            }}
          />
          <select
            value={statusFilter}
            onChange={(e) => {
              setStatusFilter(e.target.value);
              setCurrentPage(1);
            }}
            style={{ marginLeft: "10px" }}
          >
            <option value="all">All</option>
            <option value="pending">Pending</option>
            <option value="in_progress">In Progress</option>
            <option value="resolved">Resolved</option>
          </select>
        </div>

        {/* Table */}
        {loading ? (
          <p>Loading maintenance requests...</p>
        ) : error ? (
          <p style={{ color: "red" }}>{error}</p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>User</th>
                <th>Equipment</th>
                <th>Issue</th>
                <th>Status</th>
                <th>Scheduled</th>
                <th>Resolved</th>
                <th>Assigned To</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {paginatedRequests.length ? (
                paginatedRequests.map((req) => (
                  <tr key={req.id}>
                    <td>{getUser(req.user)}</td>
                    <td>{getEquipment(req.equipment)}</td>
                    <td>{req.issue}</td>
                    <td>
                      <span
                        className={`status-color status-color-${(req.status ?? "").toLowerCase()}`}
                      >
                        {(req.status ?? "").toUpperCase()}
                      </span>
                    </td>
                    <td>{req.scheduled_date || "-"}</td>
                    <td>{formatDate(req.resolved_at) || "-"}</td>
                    <td>{getUser(req.assigned_to)}</td>
                    <td>
                      <button className="view-btn" onClick={() => openModal("view", req)}>
                        View
                      </button>
                      <button className="edt-btn" onClick={() => openModal("edit", req)}>
                        Edit
                      </button>
                      <button className="dlt-btn" onClick={() => openModal("delete", req)}>
                        Delete
                      </button>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={8}>No maintenance requests found</td>
                </tr>
              )}
            </tbody>
          </table>
        )}

        <button className="add-btn-main" onClick={() => openModal("add")}>
          + Add Maintenance Request
        </button>
        <Pagination
          currentPage={currentPage}
          totalPages={totalPages}
          onPageChange={setCurrentPage}
          showRange
        />

        {/* Modals */}
        {modalType === "view" && selectedRequest ? (
          <MaintenanceViewModal
            request={selectedRequest}
            users={users}
            onClose={closeModal}
            onRefresh={refetch}
            updateRequest={updateRequest} 
          />
        ) : modalType ? (
          <MaintenanceModal
            mode={modalType as MaintenanceModalMode}
            request={selectedRequest ?? undefined}
            equipments={equipment}
            users={users}
            onClose={closeModal}
            onSubmit={
              modalType === "add" ? handleAdd : modalType === "edit" ? handleEdit : handleDelete
            }
          />
        ) : null}
      </div>

      {submitting && (
        <div
          style={{
            position: "fixed",
            top: 0,
            left: 0,
            width: "100%",
            height: "100%",
            backgroundColor: "rgba(0,0,0,0.5)",
            zIndex: 999999,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            color: "#fff",
            fontSize: "1.2rem",
          }}
        >
          <div className="spinner" />
          <p>Processing…</p>
        </div>
      )}
    </PageLayout>
  );
};

export default MaintenancePage;
