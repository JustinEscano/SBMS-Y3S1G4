import React, { useMemo, useState, useEffect } from "react";
import PageLayout from "./PageLayout";
import Pagination from "../components/Pagination";
import UserDetailsModal from "../components/userDetailsModal";
import type { User } from "../types/dashboardTypes";
import { userService } from "../services/userService";
import { useAuth } from "../context/AuthContext";
import { useUser } from "../hooks/useUser";
import { Users, Shield, UserCircle, Search, Plus, ChevronDown } from "lucide-react";

const ITEMS_PER_PAGE = 8;

const roleColors: Record<string, { bg: string; color: string }> = {
  admin:  { bg: 'rgba(167,139,250,0.15)', color: '#a78bfa' },
  client: { bg: 'rgba(52,211,153,0.15)',  color: '#34d399' },
  user:   { bg: 'rgba(59,130,246,0.15)',  color: '#60a5fa' },
  default:{ bg: 'rgba(100,116,139,0.15)', color: '#94a3b8' },
};

const getRoleStyle = (role?: string) => roleColors[(role || '').toLowerCase()] || roleColors.default;

const StatCard = ({ icon: Icon, label, value, color }: { icon: React.ElementType; label: string; value: number; color: string }) => (
  <div style={{ background: '#0f172a', border: '1px solid #1e293b', borderRadius: '16px', padding: '24px', position: 'relative', overflow: 'hidden' }}>
    <div style={{ position: 'absolute', top: -20, right: -20, width: '100px', height: '100px', borderRadius: '50%', background: color, opacity: 0.08, filter: 'blur(20px)' }} />
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', position: 'relative', zIndex: 1 }}>
      <div>
        <p style={{ fontSize: '12px', fontWeight: 600, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.06em', margin: '0 0 8px' }}>{label}</p>
        <p style={{ fontSize: '36px', fontWeight: 900, color: '#ffffff', margin: 0, lineHeight: 1 }}>{value}</p>
      </div>
      <div style={{ width: '52px', height: '52px', borderRadius: '14px', background: '#080b14', border: '1px solid #1e293b', display: 'flex', alignItems: 'center', justifyContent: 'center', color }}>
        <Icon size={24} />
      </div>
    </div>
  </div>
);

const UsersPage: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [showModal, setShowModal] = useState(false);
  const [modalUser, setModalUser] = useState<User | null>(null);
  const [modalMode, setModalMode] = useState<"view" | "edit" | "delete" | "add">("view");
  const [currentPage, setCurrentPage] = useState(1);
  const [roleFilter, setRoleFilter] = useState("all");
  const [error, setError] = useState<string | null>(null);

  const { token } = useAuth();
  const { user: currentUser } = useUser(token);

  useEffect(() => {
    const fetchUsers = async () => {
      try {
        setLoading(true);
        const data = await userService.getAll();
        setUsers(data);
      } catch (err) {
        console.error("Failed to fetch users:", err);
        setError("Failed to load users.");
      } finally {
        setLoading(false);
      }
    };
    fetchUsers();
  }, []);

  useEffect(() => setCurrentPage(1), [search]);

  const filteredUsers = useMemo(() =>
    users.filter(u => {
      const matchesSearch = u.username.toLowerCase().includes(search.toLowerCase()) || u.email.toLowerCase().includes(search.toLowerCase());
      const matchesRole = roleFilter === "all" || (u.role || "").toLowerCase() === roleFilter;
      const isNotCurrentUser = !currentUser || u.id !== currentUser.id;
      return matchesSearch && matchesRole && isNotCurrentUser;
    }),
    [users, search, roleFilter, currentUser]
  );

  const totalPages = Math.ceil(filteredUsers.length / ITEMS_PER_PAGE);
  const paginatedUsers = useMemo(() => {
    const start = (currentPage - 1) * ITEMS_PER_PAGE;
    return filteredUsers.slice(start, start + ITEMS_PER_PAGE);
  }, [filteredUsers, currentPage]);

  const openModal = async (mMode: "view" | "edit" | "delete" | "add", userId?: string) => {
    try {
      const userDetails = userId ? await userService.getById(userId) : null;
      setModalUser(userDetails);
      setModalMode(mMode);
      setShowModal(true);
    } catch { setError("Failed to load user details."); }
  };

  const closeModal = () => { setShowModal(false); setModalUser(null); setModalMode("view"); };

  const handleUpdate = async (data: Partial<User>) => {
    try {
      if (modalMode === "edit" && data.id && modalUser) {
        const updatedUser = await userService.update(modalUser.id, data);
        setUsers(prev => prev.map(u => u.id === modalUser!.id ? updatedUser : u));
      } else if (modalMode === "add") {
        // Assume userService.create exists for full functionality
        if ((userService as any).create) {
          const newUser = await (userService as any).create(data);
          setUsers(prev => [...prev, newUser]);
        } else {
          console.error("userService.create method not implemented");
        }
      }
      closeModal();
    } catch { setError("Failed to update user."); }
  };

  const handleDelete = async (id: string) => {
    try {
      await userService.remove(id);
      setUsers(prev => prev.filter(u => u.id !== id));
      closeModal();
    } catch { setError("Failed to delete user."); }
  };

  if (loading) return (
    <PageLayout initialSection={{ parent: "Admin" }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '200px', color: '#64748b', fontSize: '14px' }}>
        Loading users...
      </div>
    </PageLayout>
  );

  return (
    <PageLayout initialSection={{ parent: "Admin" }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '32px' }}>
        <div>
          <h1 style={{ fontSize: '28px', fontWeight: 800, color: '#ffffff', margin: 0, letterSpacing: '-0.02em' }}>User Management</h1>
          <p style={{ fontSize: '14px', color: '#64748b', margin: '4px 0 0' }}>Manage user accounts and permissions</p>
        </div>
        <button
          onClick={() => { setModalMode("add"); setModalUser(null); setShowModal(true); }}
          style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', padding: '10px 20px', borderRadius: '10px', fontSize: '14px', fontWeight: 600, cursor: 'pointer', border: 'none', background: '#3b82f6', color: '#fff', transition: 'background 0.2s', boxShadow: '0 4px 12px rgba(59,130,246,0.3)' }}
          onMouseEnter={e => e.currentTarget.style.background = '#2563eb'}
          onMouseLeave={e => e.currentTarget.style.background = '#3b82f6'}
        >
          <Plus size={16} /> Add User
        </button>
      </div>

      {error && (
        <div style={{ background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.3)', borderRadius: '10px', padding: '12px 16px', marginBottom: '20px', color: '#f87171', fontSize: '14px', display: 'flex', justifyContent: 'space-between' }}>
          <span>{error}</span>
          <button onClick={() => setError(null)} style={{ background: 'none', border: 'none', color: '#f87171', cursor: 'pointer', textDecoration: 'underline' }}>Dismiss</button>
        </div>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '16px', marginBottom: '32px' }}>
        <StatCard icon={Users} label="Total Users" value={filteredUsers.length} color="#60a5fa" />
        <StatCard icon={Shield} label="Admins" value={filteredUsers.filter(u => u.role?.toLowerCase() === "admin").length} color="#a78bfa" />
        <StatCard icon={UserCircle} label="Clients" value={filteredUsers.filter(u => u.role?.toLowerCase() === "client").length} color="#34d399" />
      </div>

      <h2 style={{ fontSize: '22px', fontWeight: 700, color: '#ffffff', margin: '0 0 16px' }}>User Accounts</h2>

      {/* Filters Section (separate card) */}
      <div style={{ background: '#141828', border: '1px solid #1d2540', borderRadius: '16px', padding: '16px 20px', marginBottom: '16px', display: 'flex', gap: '16px', alignItems: 'flex-end', flexWrap: 'wrap' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', flex: 1, minWidth: '200px' }}>
          <label style={{ fontSize: '12px', fontWeight: 700, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.06em' }}>Search</label>
          <div style={{ position: 'relative' }}>
            <Search size={16} style={{ position: 'absolute', left: '16px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
            <input type="text" placeholder="Search by name or email..." value={search}
              onChange={e => { setSearch(e.target.value); setCurrentPage(1); }}
              style={{ width: '100%', padding: '10px 16px 10px 42px', borderRadius: '8px', border: '1px solid #1d2540', background: 'transparent', color: '#e2e8f0', fontSize: '14px', outline: 'none', transition: 'all 0.2s', boxSizing: 'border-box' }}
            />
          </div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', flexShrink: 0 }}>
          <label style={{ fontSize: '12px', fontWeight: 700, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.06em' }}>Role</label>
          <div style={{ position: 'relative' }}>
            <select value={roleFilter} onChange={e => { setRoleFilter(e.target.value); setCurrentPage(1); }}
              style={{ padding: '10px 36px 10px 16px', borderRadius: '8px', border: '1px solid #1d2540', background: 'transparent', color: '#e2e8f0', fontSize: '14px', outline: 'none', appearance: 'none', height: '40px', cursor: 'pointer' }}>
              <option value="all" style={{ background: '#0a0e1a' }}>All Roles</option>
              <option value="admin" style={{ background: '#0a0e1a' }}>Admin</option>
              <option value="client" style={{ background: '#0a0e1a' }}>Client</option>
              <option value="user" style={{ background: '#0a0e1a' }}>User</option>
            </select>
            <ChevronDown size={14} style={{ position: 'absolute', right: '14px', top: '50%', transform: 'translateY(-50%)', color: '#64748b', pointerEvents: 'none' }} />
          </div>
        </div>
      </div>

      {/* Table Section (separate card) */}
      <div style={{ background: '#141828', border: '1px solid #1d2540', borderRadius: '16px', overflow: 'hidden' }}>
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>

            <thead>
              <tr style={{ background: '#0d1022', borderBottom: '1px solid #1d2540' }}>
                {['Username', 'Email', 'Role', 'Actions'].map(h => (
                  <th key={h} style={{ padding: '14px 20px', textAlign: 'center', fontSize: '12px', fontWeight: 700, color: '#f8fafc', textTransform: 'uppercase', letterSpacing: '0.06em' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {paginatedUsers.length > 0 ? paginatedUsers.map(user => (
                <tr key={user.id} style={{ borderBottom: '1px solid #1d2540' }}
                  onMouseEnter={e => (e.currentTarget.style.background = 'rgba(30,41,59,0.4)')}
                  onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                >
                  <td style={{ padding: '16px 20px', fontSize: '14px', color: '#e2e8f0', fontWeight: 500, textAlign: 'center' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px', justifyContent: 'center' }}>
                      <div style={{ width: '32px', height: '32px', borderRadius: '50%', background: 'rgba(59,130,246,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#60a5fa', fontSize: '12px', fontWeight: 700, flexShrink: 0 }}>
                        {(user.username || 'U').charAt(0).toUpperCase()}
                      </div>
                      {user.username || 'N/A'}
                    </div>
                  </td>
                  <td style={{ padding: '16px 20px', fontSize: '14px', color: '#94a3b8', textAlign: 'center' }}>{user.email || 'N/A'}</td>
                  <td style={{ padding: '16px 20px', textAlign: 'center' }}>
                    <span style={{ ...getRoleStyle(user.role), padding: '4px 12px', borderRadius: '999px', fontSize: '12px', fontWeight: 600 }}>
                      {(user.role || 'N/A').toUpperCase()}
                    </span>
                  </td>
                  <td style={{ padding: '16px 20px', textAlign: 'center' }}>
                    <div style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
                      <button onClick={() => openModal('edit', user.id)}
                        style={{ padding: '5px 14px', background: 'rgba(59,130,246,0.1)', border: '1px solid rgba(59,130,246,0.2)', color: '#60a5fa', borderRadius: '6px', fontSize: '12px', fontWeight: 600, cursor: 'pointer' }}
                      >Edit</button>
                      <button onClick={() => openModal('delete', user.id)}
                        style={{ padding: '5px 14px', background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.2)', color: '#f87171', borderRadius: '6px', fontSize: '12px', fontWeight: 600, cursor: 'pointer' }}
                      >Delete</button>
                    </div>
                  </td>
                </tr>
              )) : (
                <tr><td colSpan={4} style={{ padding: '48px 20px', textAlign: 'center', color: '#64748b', fontSize: '14px' }}>No users found.</td></tr>
              )}
            </tbody>
          </table>
        </div>

      </div>

      <div style={{ paddingTop: '16px', display: 'flex', justifyContent: 'center' }}>
        <Pagination currentPage={currentPage} totalPages={totalPages} onPageChange={setCurrentPage} showRange />
      </div>

      <UserDetailsModal user={modalUser} isOpen={showModal} onClose={closeModal} mode={modalMode} onUpdate={handleUpdate} onDelete={handleDelete} />
    </PageLayout>
  );
};

export default UsersPage;