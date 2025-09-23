import React, { useState, useEffect, useMemo, useRef } from "react";
import type { Room, Equipment } from "../types/dashboardTypes";
import RoomModal from "../components/roomModal";
import { roomService } from "../services/roomService";
import { equipmentService } from "../services/equipmentService";
import PageLayout from "../pages/PageLayout";
import Pagination from "../components/Pagination";
import "../pages/PageStyle.css";

type RoomModalMode = "add" | "edit" | "delete";
const ITEMS_PER_PAGE = 5;

const DashboardScreen: React.FC = () => {
  const [rooms, setRooms] = useState<Room[]>([]);
  const [search, setSearch] = useState("");
  const [modalMode, setModalMode] = useState<RoomModalMode | null>(null);
  const [selectedRoom, setSelectedRoom] = useState<Room | undefined>();
  const [currentPage, setCurrentPage] = useState(1);

  const [showRequests, setShowRequests] = useState(false);
  const [equipments, setEquipments] = useState<Equipment[]>([]);

  const popupRef = useRef<HTMLDivElement>(null);

  /** Fetch Rooms */
  useEffect(() => {
    roomService.getAll().then(setRooms).catch(console.error);
  }, []);

  /** Fetch Equipments */
  useEffect(() => {
    equipmentService.getAll().then(setEquipments).catch(console.error);
  }, []);

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
    () => rooms.filter((r) => r.name.toLowerCase().includes(search.toLowerCase())),
    [rooms, search]
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
        setRooms((prev) => [...prev, newRoom]);
      } else if (modalMode === "edit" && data.id) {
        const updated = await roomService.update(data.id, data);
        setRooms((prev) =>
          prev.map((r) => (r.id === data.id ? { ...r, ...updated } : r))
        );
      } else if (modalMode === "delete" && data.id) {
        await roomService.remove(data.id);
        setRooms((prev) => prev.filter((r) => r.id !== data.id));
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
        <h1>Dashboard &gt; Rooms</h1>
      </div>

      <div className="content-container">
        <div className="stats-boxes">
          <div className="stats-box">
            <div className="stat-icon">🏫</div>
            <div className="stat-info">
              <p className="stat-number">{rooms.length}</p>
              <p className="stat-label">Total Rooms</p>
            </div>
          </div>
          <div className="stats-box">
            <div className="stat-icon">👔</div>
            <div className="stat-info">
              <p className="stat-number">
                {rooms.filter((r) => r.type.toLowerCase() === "office").length}
              </p>
              <p className="stat-label">Offices</p>
            </div>
          </div>
          <div className="stats-box">
            <div className="stat-icon">🔬</div>
            <div className="stat-info">
              <p className="stat-number">
                {rooms.filter((r) => r.type.toLowerCase() === "lab").length}
              </p>
              <p className="stat-label">Laboratory</p>
            </div>
          </div>
          <div className="stats-box">
            <div className="stat-icon">📢</div>
            <div className="stat-info">
              <p className="stat-number">
                {rooms.filter((r) => r.type.toLowerCase() === "meeting").length}
              </p>
              <p className="stat-label">Meeting Room</p>
            </div>
          </div>
          <div className="stats-box">
            <div className="stat-icon">📦</div>
            <div className="stat-info">
              <p className="stat-number">
                {rooms.filter((r) => r.type.toLowerCase() === "storage").length}
              </p>
              <p className="stat-label">Storage</p>
            </div>
          </div>
          <div className="stats-box">
            <div className="stat-icon">🚪</div>
            <div className="stat-info">
              <p className="stat-number">
                {rooms.filter((r) => r.type.toLowerCase() === "corridor").length}
              </p>
              <p className="stat-label">Corridor</p>
            </div>
          </div>
        </div>

        <div className="table-controls">
          <input
            type="text"
            placeholder="Search rooms..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Floor</th>
              <th>Capacity</th>
              <th>Type</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {paginatedRooms.length > 0 ? (
              paginatedRooms.map((room) => (
                <tr key={room.id}>
                  <td>{room.name}</td>
                  <td>{room.floor}</td>
                  <td>{room.capacity}</td>
                  <td><span className={`type-color type-color-${room.type.toLowerCase()}`}>{room.type.toUpperCase()}</span></td>
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
