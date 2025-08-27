import React from "react";
import PageLayout from "./PageLayout";
import { useMaintenanceRequests } from "../hooks/useMaintenance";
import type { MaintenanceRequest } from "../types/maintenanceTypes";

const MaintenancePage: React.FC = () => {
  const { requests, loading } = useMaintenanceRequests();
  const [search, setSearch] = React.useState("");

  const filtered = requests.filter((r: MaintenanceRequest) =>
    r.issue.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <PageLayout initialSection={{ parent: "Dashboard", child: "Maintenance Requests" }}>
      <h1>Dashboard {">"} Maintenance Requests</h1>

      <div className="content-container">
        {/* Stat Boxes */}
        <div className="stats-boxes">
          <div className="stat-box">
            <div className="stat-icon">🛠️</div>
            <div className="stat-info">
              <p className="stat-number">{requests.length}</p>
              <p className="stat-label">Total Requests</p>
            </div>
          </div>
          <div className="stat-box">
            <div className="stat-icon">⏳</div>
            <div className="stat-info">
              <p className="stat-number">
                {requests.filter(r => r.status === "Pending").length}
              </p>
              <p className="stat-label">Pending</p>
            </div>
          </div>
          <div className="stat-box">
            <div className="stat-icon">✅</div>
            <div className="stat-info">
              <p className="stat-number">
                {requests.filter(r => r.status === "Resolved").length}
              </p>
              <p className="stat-label">Resolved</p>
            </div>
          </div>
        </div>

        {/* Maintenance Requests Table */}
        <div className="requests-table">
          <h2>Maintenance Request Summary</h2>

          {/* Search & Filter */}
          <div className="table-controls">
            <input
              type="text"
              placeholder="Search by issue"
              value={search}
              onChange={e => setSearch(e.target.value)}
            />
            <select>
              <option>Status</option>
              <option>Pending</option>
              <option>In Progress</option>
              <option>Resolved</option>
            </select>
            <button>Search</button>
          </div>

          {loading ? (
            <p>Loading maintenance requests...</p>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>User</th>
                  <th>Equipment</th>
                  <th>Issue</th>
                  <th>Status</th>
                  <th>Scheduled</th>
                  <th>Resolved</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((req) => (
                  <tr key={req.id}>
                    <td>{req.id}</td>
                    <td>{req.user}</td>
                    <td>{req.equipment}</td>
                    <td>{req.issue}</td>
                    <td>{req.status}</td>
                    <td>{new Date(req.scheduled_date).toLocaleDateString()}</td>
                    <td>
                      {req.resolved_at
                        ? new Date(req.resolved_at).toLocaleDateString()
                        : "—"}
                    </td>
                    <td>{new Date(req.created_at).toLocaleDateString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </PageLayout>
  );
};

export default MaintenancePage;
