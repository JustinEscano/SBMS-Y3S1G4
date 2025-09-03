import React, { useState, useEffect, useMemo } from "react";
import type { Room } from "../types/dashboardTypes";
import RoomModal from "../components/roomModal";
import { roomService } from "../services/roomService";
import PageLayout from "../pages/PageLayout";
import Pagination from "../components/Pagination"; // ✅ shared component
import "../pages/PageStyle.css";

type RoomModalMode = "add" | "edit" | "delete";

const ITEMS_PER_PAGE = 5;

const DashboardScreen: React.FC = () => {
  const [rooms, setRooms] = useState<Room[]>([]);
  const [search, setSearch] = useState("");
  const [modalMode, setModalMode] = useState<RoomModalMode | null>(null);
  const [selectedRoom, setSelectedRoom] = useState<Room | undefined>(undefined);

  const [currentPage, setCurrentPage] = useState(1);

  // Fetch rooms
  useEffect(() => {
    const fetchRooms = async () => {
      const data = await roomService.getAll();
      setRooms(data);
    };
    fetchRooms();
  }, []);

  // Reset pagination on new search
  useEffect(() => {
    setCurrentPage(1);
  }, [search]);

  // Filtered rooms
  const filteredRooms = useMemo(() => {
    return rooms.filter((r) =>
      r.name.toLowerCase().includes(search.toLowerCase())
    );
  }, [rooms, search]);

  // Paginated rooms
  const totalPages = Math.ceil(filteredRooms.length / ITEMS_PER_PAGE);
  const paginatedRooms = useMemo(() => {
    const start = (currentPage - 1) * ITEMS_PER_PAGE;
    return filteredRooms.slice(start, start + ITEMS_PER_PAGE);
  }, [filteredRooms, currentPage]);

  // CRUD handlers
  const handleSubmit = async (data: Partial<Room>) => {
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
    setModalMode(null);
    setSelectedRoom(undefined);
  };

  return (
    <PageLayout initialSection={{ parent: "Dashboard" }}>
      <h1>Dashboard &gt; Rooms</h1>

      <div className="content-container">
        {/* Stat Boxes */}
        <div className="stats-boxes">
          <div className="stat-box">
            <div className="stat-icon">🏫</div>
            <div className="stat-info">
              <p className="stat-number">{rooms.length}</p>
              <p className="stat-label">Total Rooms</p>
            </div>
          </div>
          <div className="stat-box">
            <div className="stat-icon">📚</div>
            <div className="stat-info">
              <p className="stat-number">
                {rooms.filter((r) => r.type === "Classroom").length}
              </p>
              <p className="stat-label">Classrooms</p>
            </div>
          </div>
          <div className="stat-box">
            <div className="stat-icon">👔</div>
            <div className="stat-info">
              <p className="stat-number">
                {rooms.filter((r) => r.type === "Office").length}
              </p>
              <p className="stat-label">Offices</p>
            </div>
          </div>
          <div className="stat-box">
            <div className="stat-icon">🔬</div>
            <div className="stat-info">
              <p className="stat-number">
                {rooms.filter((r) => r.type === "Lab").length}
              </p>
              <p className="stat-label">Labs</p>
            </div>
          </div>
        </div>

        {/* Table Controls */}
        <div className="table-controls">
          <input
            type="text"
            placeholder="Search rooms..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        {/* Rooms Table */}
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
            {paginatedRooms.map((room) => (
              <tr key={room.id}>
                <td>{room.name}</td>
                <td>{room.floor}</td>
                <td>{room.capacity}</td>
                <td>{room.type}</td>
                <td>
                  <button
                    className="edit-btn"
                    onClick={() => {
                      setModalMode("edit");
                      setSelectedRoom(room);
                    }}
                  >
                    Edit
                  </button>
                  <button
                    className="delete-btn"
                    onClick={() => {
                      setModalMode("delete");
                      setSelectedRoom(room);
                    }}
                  >
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {paginatedRooms.length === 0 && (
              <tr>
                <td colSpan={5}>No rooms found</td>
              </tr>
            )}
          </tbody>
        </table>

        {/* Add Room Button */}
        <button
          className="add-btn-main"
          onClick={() => {
            setModalMode("add");
            setSelectedRoom(undefined);
          }}
        >
          + Add Room
        </button>

        {/* Pagination */}
        <Pagination
          currentPage={currentPage}
          totalPages={totalPages}
          onPageChange={setCurrentPage}
          showRange
        />

        {/* Room Modal */}
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
