import React, { useState, useEffect, useMemo, useRef } from "react";
import { useNavigate } from "react-router-dom";
import type { Room, MaintenanceRequest, User, Equipment } from "../types/dashboardTypes";
import RoomModal from "../components/roomModal";
import { roomService } from "../services/roomService";
import { maintenanceService } from "../services/maintenanceService";
import { userService } from "../services/userService";
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
  const [maintenanceRequests, setRequests] = useState<MaintenanceRequest[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [equipments, setEquipments] = useState<Equipment[]>([]);

  const popupRef = useRef<HTMLDivElement>(null);
  const navigate = useNavigate();

  /** Fetch Rooms */
  useEffect(() => {
    roomService.getAll().then(setRooms).catch(console.error);
  }, []);

  /** Fetch Maintenance Requests */
  useEffect(() => {
    maintenanceService.getAll().then(setRequests).catch(console.error);
  }, []);

  /** Fetch Users */
  useEffect(() => {
    userService.getAll().then(setUsers).catch(console.error);
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

  /** Maintenance Requests → only pending */
  const pendingRequests = useMemo(
    () => maintenanceRequests.filter((req) => req.status.toLowerCase() === "pending"),
    [maintenanceRequests]
  );

  /** Map User ID → Username */
  const getUsername = (userId: string) => users.find((u) => u.id === userId)?.username ?? "Unknown";
  const getEquipmentName = (userId: string) => equipments.find((u) => u.id === userId)?.name ?? "Unknown";


  return (
    <PageLayout initialSection={{ parent: "Dashboard" }}>
      <div className="page-header">
        <h1>Dashboard &gt; Rooms</h1>
        <div className="header-actions">
          <div className="action-square blue">📊</div>
          <div className="action-square green">🔌</div>
          <div className="action-square purple">📁</div>
          <div
            className="action-square yellow relative"
            onClick={() => setShowRequests(!showRequests)}
          >
            🛠️
            {pendingRequests.length > 0 && (
              <span className="maintenance-badge">{pendingRequests.length}</span>
            )}
          </div>

          {showRequests && (
            <div ref={popupRef} className="maintenance-popup">
              <h3 className="maintenance-list-title">Maintenance Requests</h3>
              <ul className="maintenance-list">
                {pendingRequests.length > 0 ? (
                  pendingRequests.map((req) => (
                    <li
                      key={req.id}
                      className="maintenance-item"
                      onClick={() =>
                        navigate(`/dashboard/maintenance?search=${encodeURIComponent(req.issue)}`)
                      }
                    >
                      <div className="maintenance-issue">
                        <strong>{req.issue}</strong>
                      </div>
                      <div className="maintenance-equiptment">
                        Equipment: {getEquipmentName(req.equipment)}
                      </div>
                      <div className="maintenance-user">
                        User: {getUsername(req.user)}
                      </div>
                      <div className="maintenance-date">
                        Scheduled: {new Date(req.scheduled_date).toLocaleDateString()}
                      </div>
                    </li>
                  ))
                ) : (
                  <li className="maintenance-empty">No pending requests</li>
                )}
              </ul>
            </div>
          )}
        </div>
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
