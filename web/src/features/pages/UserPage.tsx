// UsersPage.tsx
import React, { useMemo, useState, useEffect } from "react";
import PageLayout from "./PageLayout";
import Pagination from "../components/Pagination";
import UserDetailsModal from "../components/userDetailsModal"; // Handles all modes
import type { User } from "../types/dashboardTypes";
import { userService } from "../services/userService";
import { useAuth } from "../context/AuthContext"; // ← Added for token
import { useUser } from "../hooks/useUser"; // ← Added for current user

const ITEMS_PER_PAGE = 5;

const UsersPage: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [modalUser, setModalUser] = useState<User | null>(null);
  const [modalMode, setModalMode] = useState<"view" | "edit" | "delete">("view");
  const [currentPage, setCurrentPage] = useState(1);
  const [error, setError] = useState<string | null>(null);

  // ← Added: Get current user for filtering
  const { token } = useAuth();
  const { user: currentUser } = useUser(token);

  // Fetch all users
  useEffect(() => {
    const fetchUsers = async () => {
      try {
        setLoading(true);
        const data = await userService.getAll();
        setUsers(data);
      } catch (err) {
        console.error("Failed to fetch users:", err);
        setError("Failed to load users. Please try again.");
      } finally {
        setLoading(false);
      }
    };
    fetchUsers();
  }, []);

  /** Reset pagination on search change */
  useEffect(() => setCurrentPage(1), [search]);

  /** Filter + Paginate Users */
  const filteredUsers = useMemo(
    () =>
      users
        .filter((u) => {
          // Existing search filter
          const matchesSearch =
            u.username.toLowerCase().includes(search.toLowerCase()) ||
            u.email.toLowerCase().includes(search.toLowerCase());
          // ← Added: Exclude current user if loaded
          const isNotCurrentUser = !currentUser || u.id !== currentUser.id;
          return matchesSearch && isNotCurrentUser;
        }),
    [users, search, currentUser] // ← Added currentUser to deps
  );

  const totalPages = Math.ceil(filteredUsers.length / ITEMS_PER_PAGE);
  const paginatedUsers = useMemo(() => {
    const start = (currentPage - 1) * ITEMS_PER_PAGE;
    return filteredUsers.slice(start, start + ITEMS_PER_PAGE);
  }, [filteredUsers, currentPage]);

  /** Open modal in specific mode */
  const openModal = async (mMode: "view" | "edit" | "delete", userId?: string) => {
    try {
      let userDetails = null;
      if (userId && (mMode === "view" || mMode === "edit" || mMode === "delete")) {
        userDetails = await userService.getById(userId);
      }
      setModalUser(userDetails);
      setModalMode(mMode);
      setShowModal(true);
    } catch (err) {
      console.error("Failed to fetch user for modal:", err);
      setError("Failed to load user details.");
    }
  };

  /** Close modal */
  const closeModal = () => {
    setShowModal(false);
    setModalUser(null);
    setModalMode("view");
  };

  /** Handle Update (edit/add) */
  const handleUpdate = async (data: Partial<User>) => {
    try {
      setError(null);
      let updatedUser: User;
      if (modalMode === "edit" && data.id && modalUser) {
        updatedUser = await userService.update(modalUser.id, data);
        setUsers((prev) =>
          prev.map((u) => (u.id === modalUser!.id ? updatedUser : u))
        );
      }
      closeModal();
    } catch (err) {
      console.error("Update failed:", err);
      setError("Failed to update user. Please try again.");
    }
  };

  /** Handle Delete */
  const handleDelete = async (id: string) => {
    try {
      setError(null);
      await userService.remove(id);
      setUsers((prev) => prev.filter((u) => u.id !== id));
      closeModal();
    } catch (err) {
      console.error("Delete failed:", err);
      setError("Failed to delete user. Please try again.");
    }
  };

  if (loading) {
    return (
      <PageLayout initialSection={{ parent: "Admin" }}>
        <h2 className="text-xl font-semibold text-white mb-4">Users</h2>
        <p className="text-gray-400">Loading users...</p>
      </PageLayout>
    );
  }

  return (
    <PageLayout initialSection={{ parent: "Admin" }}>
      <div className="page-header">
        <h1>
          <span className="title">Users</span>
        </h1>
      </div>
      <div className="content-container">
        {/* Stats ← Note: These now exclude current user too */}
        <div className="stats-boxes">
          <div className="stats-box">
            <div className="stat-icon">👥</div>
            <div className="stat-info">
              <p className="stat-number">{filteredUsers.length}</p> {/* ← Updated to filtered */}
              <p className="stat-label">Total Users</p>
            </div>
          </div>
          <div className="stats-box">
            <div className="stat-icon">🔐</div>
            <div className="stat-info">
              <p className="stat-number">
                {filteredUsers.filter((u) => u.role?.toLowerCase() === "admin").length}
              </p>
              <p className="stat-label">Admins</p>
            </div>
          </div>
          <div className="stats-box">
            <div className="stat-icon">👤</div>
            <div className="stat-info">
              <p className="stat-number">
                {filteredUsers.filter((u) => u.role?.toLowerCase() === "client").length}
              </p>
              <p className="stat-label">Clients</p>
            </div>
          </div>
        </div>
        <h2>User Table</h2>
        {/* Filters */}
        <div className="table-controls">
          <input
            type="text"
            placeholder="Search users by name or email..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        {/* Table */}
        <div className="rooms-section">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody className="table">
              {paginatedUsers.length > 0 ? (
                paginatedUsers.map((user) => (
                  <tr key={user.id}>
                    <td>{user.username || 'N/A'}</td>
                    <td>{user.email || 'N/A'}</td>
                    <td>
                      <span className={`type-color type-color-${user.role?.toLowerCase() || 'office'}`}>
                        {user.role?.toUpperCase() || 'N/A'}
                      </span>
                    </td>
                    <td>
                      <button
                        className="edt-btn"
                        onClick={() => openModal("edit", user.id)}
                      >
                        Edit
                      </button>
                      <button
                        className="dlt-btn"
                        onClick={() => openModal("delete", user.id)}
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={4}>No users found</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
        <Pagination
          currentPage={currentPage}
          totalPages={totalPages}
          onPageChange={setCurrentPage}
          showRange
        />
        {error && (
          <div className="mb-4 p-3 bg-red-900/20 border border-red-500 text-red-300 rounded">
            {error}
            <button onClick={() => setError(null)} className="ml-2 underline">Dismiss</button>
          </div>
        )}
        {/* Unified Modal for All Operations */}
        <UserDetailsModal
          user={modalUser}
          isOpen={showModal}
          onClose={closeModal}
          mode={modalMode}
          onUpdate={handleUpdate}
          onDelete={handleDelete}
        />
      </div>
    </PageLayout>
  );
};

export default UsersPage;