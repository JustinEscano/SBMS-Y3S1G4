// src/pages/DashboardScreen.tsx
import React, { useMemo, useState, useRef, useEffect } from "react";
import PageLayout from "./PageLayout";
import Pagination from "../components/Pagination";
import RoomModal from "../components/roomModal";
import type { Room } from "../types/dashboardTypes";
import { roomService } from "../services/roomService";
import { useRooms } from "../hooks/useRooms";
import "../pages/PageStyle.css";

type RoomModalMode = "add" | "edit" | "delete" | null;
const ITEMS_PER_PAGE = 5;

const DashboardScreen: React.FC = () => {
  const { rooms, loading } = useRooms();
  const [localRooms, setLocalRooms] = useState<Room[]>([]);
  const [search, setSearch] = useState("");
  const [modalMode, setModalMode] = useState<RoomModalMode>(null);
  const [selectedRoom, setSelectedRoom] = useState<Room | undefined>();
  const [currentPage, setCurrentPage] = useState(1);

  const [showRequests, setShowRequests] = useState(false);
  const popupRef = useRef<HTMLDivElement>(null);

  /** Sync hook rooms → local state */
  useEffect(() => {
    if (!loading) setLocalRooms(rooms);
  }, [rooms, loading]);

  /** Reset pagination on search change */
  useEffect(() => setCurrentPage(1), [search]);

  /** Close popup when clicking outside */
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (popupRef.current && !popupRef.current.contains(e.target as Node)) {
        setShowRequests(false);
      }
    };
    if (showRequests) document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, [showRequests]);

  /** Filter + Paginate Rooms */
  const filteredRooms = useMemo(
    () =>
      localRooms.filter((r) =>
        r.name.toLowerCase().includes(search.toLowerCase())
      ),
    [localRooms, search]
  );
  const totalPages = Math.ceil(filteredRooms.length / ITEMS_PER_PAGE);
  const paginatedRooms = useMemo(() => {
    const start = (currentPage - 1) * ITEMS_PER_PAGE;
    return filteredRooms.slice(start, start + ITEMS_PER_PAGE);
  }, [filteredRooms, currentPage]);

  /** CRUD Handlers */
  const handleSubmit = async (data: Partial<Room>) => {
    try {
      if (modalMode === "add") {
        const newRoom = await roomService.create(data);
        setLocalRooms((prev) => [...prev, newRoom]);
      } else if (modalMode === "edit" && data.id) {
        const updated = await roomService.update(data.id, data);
        setLocalRooms((prev) =>
          prev.map((r) => (r.id === data.id ? { ...r, ...updated } : r))
        );
      } else if (modalMode === "delete" && data.id) {
        await roomService.remove(data.id);
        setLocalRooms((prev) => prev.filter((r) => r.id !== data.id));
      }
    } catch (err) {
      console.error("Room operation failed:", err);
    } finally {
      setModalMode(null);
      setSelectedRoom(undefined);
    }
  };

  return (
    <PageLayout initialSection={{ parent: "Dashboard" }}>
      <div className="page-header">
        <h1>
          <span className="title">Dashboard</span>
          <span className="divider">|</span>
          <span className="breadcrumb">Dashboard &gt; Rooms</span>
        </h1>
      </div>

      <div className="content-container">
        {/* Stats */}
        <div className="stats-boxes">
          <div className="stats-box">
            <div className="stat-icon">🏫</div>
            <div className="stat-info">
              <p className="stat-number">{localRooms.length}</p>
              <p className="stat-label">Total Rooms</p>
            </div>
          </div>
          <div className="stats-box">
            <div className="stat-icon">👔</div>
            <div className="stat-info">
              <p className="stat-number">
                {localRooms.filter((r) => r.type.toLowerCase() === "office").length}
              </p>
              <p className="stat-label">Offices</p>
            </div>
          </div>
          <div className="stats-box">
            <div className="stat-icon">📢</div>
            <div className="stat-info">
              <p className="stat-number">
                {localRooms.filter((r) => r.type.toLowerCase() === "meeting").length}
              </p>
              <p className="stat-label">Meeting Rooms</p>
            </div>
          </div>
        </div>

        <h2> Room Table </h2>

        {/* Filters */}
        <div className="table-controls">
          <input
            type="text"
            placeholder="Search rooms..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        {/* Table */}
        <table>
          <thead>
            <tr>
              <th className="table-title">Device Summary</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Name</td>
              <td>Floor</td>
              <td>Capacity</td>
              <td>Type</td>
              <td>Actions</td>
            </tr>
            {paginatedRooms.length > 0 ? (
              paginatedRooms.map((room) => (
                <tr key={room.id}>
                  <td>{room.name}</td>
                  <td>{room.floor}</td>
                  <td>{room.capacity}</td>
                  <td>
                    <span className={`type-color type-color-${room.type.toLowerCase()}`}>
                      {room.type.toUpperCase()}
                    </span>
                  </td>
                  <td>
                    <button
                      className="edt-btn"
                      onClick={() => {
                        setModalMode("edit");
                        setSelectedRoom(room);
                      }}
                    >
                      Edit
                    </button>
                    <button
                      className="dlt-btn"
                      onClick={() => {
                        setModalMode("delete");
                        setSelectedRoom(room);
                      }}
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={6}>No rooms found</td>
              </tr>
            )}
          </tbody>
        </table>

        <button
          className="add-btn-main"
          onClick={() => {
            setModalMode("add");
            setSelectedRoom(undefined);
          }}
        >
          + Add Room
        </button>

        <Pagination
          currentPage={currentPage}
          totalPages={totalPages}
          onPageChange={setCurrentPage}
          showRange
        />

        {/* Modal */}
        {modalMode && (
          <RoomModal
            mode={modalMode}
            room={selectedRoom}
            onClose={() => {
              setModalMode(null);
              setSelectedRoom(undefined);
            }}
            onSubmit={handleSubmit}
          />
        )}
      </div>
    </PageLayout>
  );
};

export default DashboardScreen;
