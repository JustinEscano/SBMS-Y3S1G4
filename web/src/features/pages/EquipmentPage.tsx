import React, { useMemo, useState } from "react";
import PageLayout from "./PageLayout";
import { useEquipment } from "../hooks/useEquipment";
import { useRooms } from "../hooks/useRooms";
import EquipmentModal from "../components/equipmentModal";
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

type EquipmentWithRoom = Equipment & { roomName?: string; floor?: number | "" };

interface GenericEquipmentPageProps {
  pageType: PageType;
  icon: string;
}

const GenericEquipmentPage: React.FC<GenericEquipmentPageProps> = ({ pageType, icon }) => {
  const {
    equipment,
    loading,
    addEquipment,
    updateEquipment,
    deleteEquipment,
  } = useEquipment();

  const { rooms } = useRooms();

  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<"All" | EquipmentStatus>("All");
  const [modalType, setModalType] = useState<ModalType>(null);
  const [selected, setSelected] = useState<Equipment | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [, setErrorMsg] = useState<string | null>(null);

  // Ensure allowedTypes is always defined
  const allowedTypes = PAGE_TYPE_MAP[pageType] ?? [];

  const filteredByType: Equipment[] = useMemo(() => {
    return equipment
      .filter((e) => allowedTypes.includes(e.type))
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
  }, [equipment, allowedTypes]);

  const mappedEquipment: EquipmentWithRoom[] = useMemo(() => {
    return filteredByType.map((eq) => {
      const room = rooms.find((r: Room) => r.id === eq.room);
      return { ...eq, roomName: room?.name ?? eq.room, floor: room?.floor ?? "" };
    });
  }, [filteredByType, rooms]);

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

  const totalPages = Math.max(1, Math.ceil(filteredEquipment.length / ITEMS_PER_PAGE));
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

  const formatPayload = (data: Partial<Equipment>): Partial<Equipment> => ({
    name: data.name ?? "",
    type: data.type as EquipmentType,
    status: (data.status as EquipmentStatus) ?? "offline",
    qr_code: data.qr_code ?? "",
    room: data.room,
  });

  const handleAdd = async (data: Partial<Equipment>) => {
    try {
      await addEquipment(formatPayload(data));
      closeModal();
    } catch (err: any) {
      setErrorMsg(err?.response?.data ? JSON.stringify(err.response.data) : err?.message || "Failed to create.");
    }
  };

  const handleEdit = async (data: Partial<Equipment>) => {
    if (!selected) return;
    try {
      await updateEquipment(selected.id, { ...formatPayload(data), id: selected.id });
      closeModal();
    } catch (err: any) {
      setErrorMsg(err?.response?.data ? JSON.stringify(err.response.data) : err?.message || "Failed to update.");
    }
  };

  const handleDelete = async () => {
    if (!selected) return;
    try {
      await deleteEquipment(selected.id);
      closeModal();
    } catch (err: any) {
      setErrorMsg(err?.response?.data ? JSON.stringify(err.response.data) : err?.message || "Failed to delete.");
    }
  };

  return (
    <PageLayout initialSection={{ parent: "Dashboard", child: pageType }}>
      <div className="page-header">
        <h1>
          <span className="title">Dashboard</span>
          <span className="divider">|</span>
          <span className="breadcrumb">Dashboard &gt; {pageType.charAt(0).toUpperCase() + pageType.slice(1)}</span>
        </h1>
      </div>

      <div className="content-container">
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

        <h2> {pageType.charAt(0).toUpperCase() + pageType.slice(1)} Table </h2>

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

        {loading ? (
          <p>Loading equipment...</p>
        ) : (
          <>
            <table>
              <thead>
                <tr>
                  <th className="table-title">Device Summary</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>Room</td>
                  <td>Floor</td>
                  <td>Name</td>
                  <td>Type</td>
                  <td>Status</td>
                  <td>QR Code</td>
                  <td>Created</td>
                  <td>Actions</td>
                </tr>
                {paginatedEquipment.length > 0 ? (
                  paginatedEquipment.map((eq) => (
                    <tr key={eq.id}>
                      <td>{eq.roomName}</td>
                      <td>{eq.floor}</td>
                      <td>{eq.name}</td>
                      <td>{eq.type}</td>
                      <td>
                        <span className={`status-color status-color-${eq.status.toLowerCase()}`}>
                          {eq.status.toUpperCase()}
                        </span>
                      </td>
                      <td>{eq.qr_code}</td>
                      <td>{new Date(eq.created_at).toLocaleDateString()}</td>
                      <td>
                        <button className="edt-btn" onClick={() => openModal("edit", eq)}>Edit</button>
                        <button className="dlt-btn" onClick={() => openModal("delete", eq)}>Delete</button>
                      </td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={8}>No equipment found</td>
                  </tr>
                )}
              </tbody>
            </table>

            <button className="add-btn-main" onClick={() => openModal("add")}>
              + Add Equipment
            </button>

            <Pagination
              currentPage={currentPage}
              totalPages={totalPages}
              onPageChange={setCurrentPage}
              showRange
            />
          </>
        )}
      </div>

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
