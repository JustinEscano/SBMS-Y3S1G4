import React, { useMemo, useState } from "react";
import PageLayout from "./PageLayout";
import { useEquipment } from "../hooks/useEquipment";
import { useRooms } from "../hooks/useRooms";
import EquipmentModal from "../components/equipmentModal";
import { equipmentService } from "../services/equipmentService";
import Pagination from "../components/Pagination";
import type { Equipment, EquipmentType, EquipmentStatus, Room } from "../types/dashboardTypes";
import "../pages/PageStyle.css";

import { PAGE_TYPES } from "../constants/constant";
import type { PageType } from "../constants/constant";

// Mapping of page type → allowed equipment types
export const PAGE_TYPE_MAP: Record<PageType, EquipmentType[]> = {
  [PAGE_TYPES.HVAC]: ["monitor", "esp32"],
  [PAGE_TYPES.LIGHTING]: ["actuator", "controller"],
  [PAGE_TYPES.SECURITY]: ["sensor"],
};

type ModalType = "add" | "edit" | "delete" | null;
const ITEMS_PER_PAGE = 5;

interface GenericEquipmentPageProps {
  pageType: PageType;
  icon: string;
}

type EquipmentWithRoom = Equipment & { roomName?: string; floor?: number | "" };

const GenericEquipmentPage: React.FC<GenericEquipmentPageProps> = ({ pageType, icon }) => {
  const { equipment, loading, refetch } = useEquipment();
  const { rooms } = useRooms();

  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<"All" | EquipmentStatus>("All");
  const [modalType, setModalType] = useState<ModalType>(null);
  const [selected, setSelected] = useState<Equipment | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  // Ensure allowedTypes is always defined
  const allowedTypes = PAGE_TYPE_MAP[pageType] ?? [];
  if (!allowedTypes.length) console.warn("Unknown pageType:", pageType);

  // Filter equipment by type
  const filteredByType: Equipment[] = useMemo(() => {
    return equipment
      .filter((e) => allowedTypes.includes(e.type))
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
  }, [equipment, allowedTypes]);

  // Attach room info
  const mappedEquipment: EquipmentWithRoom[] = useMemo(() => {
    return filteredByType.map((eq) => {
      const room = rooms.find((r: Room) => r.id === eq.room);
      return { ...eq, roomName: room?.name ?? eq.room, floor: room?.floor ?? "" };
    });
  }, [filteredByType, rooms]);

  // Search + status filter
  const filteredEquipment: EquipmentWithRoom[] = useMemo(() => {
    const term = search.toLowerCase();
    return mappedEquipment.filter((e) => {
      const floorStr = String(e.floor ?? "");
      const matchesSearch =
        (e.name ?? "").toLowerCase().includes(term) ||
        (e.status ?? "").toLowerCase().includes(term) ||
        (e.qr_code ?? "").toLowerCase().includes(term) ||
        (e.roomName ?? "").toLowerCase().includes(term) ||
        floorStr.toLowerCase().includes(term);
      const matchesStatus = statusFilter === "All" ? true : e.status === statusFilter;
      return matchesSearch && matchesStatus;
    });
  }, [mappedEquipment, search, statusFilter]);

  // Pagination
  const totalPages = Math.ceil(filteredEquipment.length / ITEMS_PER_PAGE);
  const paginatedEquipment = filteredEquipment.slice(
    (currentPage - 1) * ITEMS_PER_PAGE,
    currentPage * ITEMS_PER_PAGE
  );

  // Modal helpers
  const openModal = (mType: ModalType, eq?: Equipment) => {
    setModalType(mType);
    setSelected(eq ?? null);
    setErrorMsg(null);
  };
  const closeModal = () => {
    setModalType(null);
    setSelected(null);
    setErrorMsg(null);
  };

  // Backend payload formatter
  const formatPayload = (data: Partial<Equipment>): Partial<Equipment> => ({
    name: data.name ?? "",
    type: data.type as EquipmentType,
    status: (data.status as EquipmentStatus) ?? "offline",
    qr_code: data.qr_code ?? "",
    room: data.room,
  });

  const handleAdd = async (data: Partial<Equipment>) => {
    try {
      await equipmentService.create(formatPayload(data));
      await refetch();
      closeModal();
    } catch (err: any) {
      setErrorMsg(err?.response?.data ? JSON.stringify(err.response.data) : err?.message || "Failed to create.");
    }
  };

  const handleEdit = async (data: Partial<Equipment>) => {
    if (!selected) return;
    try {
      await equipmentService.update(selected.id, { ...formatPayload(data), id: selected.id });
      await refetch();
      closeModal();
    } catch (err: any) {
      setErrorMsg(err?.response?.data ? JSON.stringify(err.response.data) : err?.message || "Failed to update.");
    }
  };

  const handleDelete = async () => {
    if (!selected) return;
    try {
      await equipmentService.remove(selected.id);
      await refetch();
      closeModal();
    } catch (err: any) {
      setErrorMsg(err?.response?.data ? JSON.stringify(err.response.data) : err?.message || "Failed to delete.");
    }
  };

  // Debugging logs
  console.log("pageType:", pageType, "allowedTypes:", allowedTypes);
  console.log("equipment count:", filteredByType.length);

  return (
    <PageLayout initialSection={{ parent: "Dashboard", child: pageType }}>
      <h1>Dashboard &gt; {pageType.charAt(0).toUpperCase() + pageType.slice(1)}</h1>

      <div className="content-container">
        {/* Stats */}
        <div className="stats-boxes">
          <div className="stats-box">
            <div className="stat-icon">{icon}</div>
            <div className="stat-info">
              <p className="stat-number">{filteredByType.length}</p>
              <p className="stat-label">Total Units</p>
            </div>
          </div>
          <div className="stats-box">
            <div className="stat-icon">✅</div>
            <div className="stat-info">
              <p className="stat-number">{filteredByType.filter((e) => e.status === "online").length}</p>
              <p className="stat-label">Online Units</p>
            </div>
          </div>
          <div className="stats-box">
            <div className="stat-icon">❌</div>
            <div className="stat-info">
              <p className="stat-number">{filteredByType.filter((e) => e.status === "offline").length}</p>
              <p className="stat-label">Offline Units</p>
            </div>
          </div>
        </div>

        {/* Filters */}
        <div className="table-controls">
          <input
            type="text"
            placeholder="Search..."
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setCurrentPage(1);
            }}
          />
          <select
            value={statusFilter}
            onChange={(e) => {
              setStatusFilter(e.target.value as any);
              setCurrentPage(1);
            }}
          >
            <option value="All">All</option>
            <option value="online">Online</option>
            <option value="offline">Offline</option>
            <option value="maintenance">Maintenance</option>
            <option value="error">Error</option>
          </select>
        </div>

        {/* Table */}
        {loading ? (
          <p>Loading {pageType} data...</p>
        ) : (
          <>
            {errorMsg && <div className="error-banner">{errorMsg}</div>}

            <table>
              <thead>
                <tr>
                  <th>Room</th>
                  <th>Floor</th>
                  <th>Name</th>
                  <th>Type</th>
                  <th>Status</th>
                  <th>QR Code</th>
                  <th>Created</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {paginatedEquipment.map((eq) => (
                  <tr key={eq.id}>
                    <td>{eq.roomName}</td>
                    <td>{eq.floor}</td>
                    <td>{eq.name}</td>
                    <td>{eq.type}</td>
                    <td>{eq.status}</td>
                    <td>{eq.qr_code}</td>
                    <td>{new Date(eq.created_at).toLocaleDateString()}</td>
                    <td>
                      <button className="edt-btn" onClick={() => openModal("edit", eq)}>Edit</button>
                      <button className="dlt-btn" onClick={() => openModal("delete", eq)}>Delete</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>

            <button className="add-btn-main" onClick={() => openModal("add")}>
              + Add Equipment
            </button>
          </>
        )}
      </div>

      <Pagination
        currentPage={currentPage}
        totalPages={totalPages}
        onPageChange={setCurrentPage}
        showRange
      />

      {/* Shared Modal */}
      {modalType && (
        <EquipmentModal
          rooms={rooms}
          mode={modalType}
          equipment={selected || undefined}
          allowedTypes={allowedTypes}
          onClose={closeModal}
          onSubmit={
            modalType === "add"
              ? handleAdd
              : modalType === "edit"
              ? handleEdit
              : handleDelete
          }
        />
      )}
    </PageLayout>
  );
};

export default GenericEquipmentPage;