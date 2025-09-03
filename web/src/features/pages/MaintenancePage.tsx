import React, { useState, useEffect, useMemo } from "react";
import type { MaintenanceRequest, Equipment, User } from "../types/dashboardTypes";
import MaintenanceModal from "../components/maintenanceModal";
import { maintenanceService } from "../services/maintenanceService";
import { equipmentService } from "../services/equipmentService";
import { userService } from "../services/userService";
import PageLayout from "../pages/PageLayout";
import Pagination from "../components/Pagination";
import "../pages/PageStyle.css";

type MaintenanceModalMode = "add" | "edit" | "delete";

const ITEMS_PER_PAGE = 5;

const MaintenancePage: React.FC = () => {
  const [requests, setRequests] = useState<MaintenanceRequest[]>([]);
  const [equipments, setEquipments] = useState<Equipment[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [search, setSearch] = useState("");
  const [modalMode, setModalMode] = useState<MaintenanceModalMode | null>(null);
  const [selectedRequest, setSelectedRequest] = useState<MaintenanceRequest | undefined>(undefined);
  const [currentPage, setCurrentPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState("all");

  useEffect(() => {
    const fetchData = async () => {
      const [reqs, eqs, usrs] = await Promise.all([
        maintenanceService.getAll(),
        equipmentService.getAll(),
        userService.getAll(),
      ]);
      setRequests(reqs);
      setEquipments(eqs);
      setUsers(usrs);
    };
    fetchData();
  }, []);

  useEffect(() => {
    setCurrentPage(1);
  }, [search, statusFilter]);

  const filteredRequests = useMemo(() => {
    return requests.filter((r) => {
      const matchesSearch = r.issue.toLowerCase().includes(search.toLowerCase());
      const matchesStatus = statusFilter === "all" || r.status === statusFilter;
      return matchesSearch && matchesStatus;
    });
  }, [requests, search, statusFilter]);

  const totalPages = Math.ceil(filteredRequests.length / ITEMS_PER_PAGE);
  const paginatedRequests = useMemo(() => {
    const start = (currentPage - 1) * ITEMS_PER_PAGE;
    return filteredRequests.slice(start, start + ITEMS_PER_PAGE);
  }, [filteredRequests, currentPage]);

  const handleSubmit = async (data: Partial<MaintenanceRequest>) => {
    // Simple status transformation - just this one change!
    const dataToSend = { ...data };
    if (dataToSend.status) {
      if (dataToSend.status === "Pending") dataToSend.status = "pending" as any;
      if (dataToSend.status === "In Progress") dataToSend.status = "in_progress" as any;
      if (dataToSend.status === "Resolved") dataToSend.status = "resolved" as any;
    }

    if (modalMode === "add") {
      const newReq = await maintenanceService.create(dataToSend);
      setRequests((prev) => [...prev, newReq]);
    } else if (modalMode === "edit" && data.id) {
      const updated = await maintenanceService.update(data.id, dataToSend);
      setRequests((prev) =>
        prev.map((r) => (r.id === data.id ? { ...r, ...updated } : r))
      );
    } else if (modalMode === "delete" && data.id) {
      await maintenanceService.remove(data.id);
      setRequests((prev) => prev.filter((r) => r.id !== data.id));
    }
    setModalMode(null);
    setSelectedRequest(undefined);
  };

  return (
    <PageLayout initialSection={{ parent: "Dashboard", child: "Maintenance" }}>
      <h1>Dashboard &gt; Maintenance Requests</h1>

      <div className="content-container">
        {/* Search + Filter */}
        <div className="table-controls">
          <input
            type="text"
            placeholder="Search requests..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />

          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            style={{ marginLeft: "10px" }}
          >
            <option value="all">All</option>
            <option value="Pending">Pending</option>
            <option value="In Progress">In Progress</option>
            <option value="Resolved">Resolved</option>
          </select>
        </div>

        {/* Table */}
        <table>
          <thead>
            <tr>
              <th>User</th>
              <th>Equipment</th>
              <th>Issue</th>
              <th>Status</th>
              <th>Scheduled</th>
              <th>Resolved</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {paginatedRequests.map((req) => (
              <tr key={req.id}>
                <td>{users.find((u) => u.id === req.user)?.username || req.user}</td>
                <td>{equipments.find((eq) => eq.id === req.equipment)?.name || req.equipment}</td>
                <td>{req.issue}</td>
                <td>{req.status}</td>
                <td>{req.scheduled_date}</td>
                <td>{req.resolved_at || "-"}</td>
                <td>
                  <button
                    className="edt-btn"
                    onClick={() => {
                      setModalMode("edit");
                      setSelectedRequest(req);
                    }}
                  >
                    Edit
                  </button>
                  <button
                    className="dlt-btn"
                    onClick={() => {
                      setModalMode("delete");
                      setSelectedRequest(req);
                    }}
                  >
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {paginatedRequests.length === 0 && (
              <tr>
                <td colSpan={7}>No maintenance requests found</td>
              </tr>
            )}
          </tbody>
        </table>

        {/* Add button */}
        <button
          className="add-btn-main"
          onClick={() => {
            setModalMode("add");
            setSelectedRequest(undefined);
          }}
        >
          + Add Maintenance Request
        </button>

        {/* Pagination */}
        <Pagination
          currentPage={currentPage}
          totalPages={totalPages}
          onPageChange={setCurrentPage}
          showRange
        />

        {/* Modal */}
        {modalMode && (
          <MaintenanceModal
            mode={modalMode}
            request={selectedRequest}
            equipments={equipments}
            users={users}
            onClose={() => {
              setModalMode(null);
              setSelectedRequest(undefined);
            }}
            onSubmit={handleSubmit}
          />
        )}
      </div>
    </PageLayout>
  );
};

export default MaintenancePage;