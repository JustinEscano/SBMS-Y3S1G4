import React from "react";
import PageLayout from "../pages/PageLayout";
import { useEquipment } from "../hooks/useEquipment";
import type { Equipment } from "../types/equipmentTypes";

const HVACPage: React.FC = () => {
  const { equipment, loading } = useEquipment();
  const [search, setSearch] = React.useState("");
  const hvac = equipment.filter((e: Equipment) => e.type === "HVAC");

  const filtered = hvac.filter(e => e.name.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <PageLayout initialSection={{ parent: "Dashboard", child: "HVAC" }}>
      <h1>Dashboard {">"} HVAC</h1>

      <div className="content-container">
        {/* Stat boxes */}
        <div className="stats-boxes">
          <div className="stat-box">
            <div className="stat-icon">❄️</div>
            <div className="stat-info">
              <p className="stat-number">{hvac.length}</p>
              <p className="stat-label">Total HVAC Units</p>
            </div>
          </div>
          <div className="stat-box">
            <div className="stat-icon">✅</div>
            <div className="stat-info">
              <p className="stat-number">
                {hvac.filter(e => e.status === "Active").length}
              </p>
              <p className="stat-label">Active Units</p>
            </div>
          </div>
          <div className="stat-box">
            <div className="stat-icon">❌</div>
            <div className="stat-info">
              <p className="stat-number">
                {hvac.filter(e => e.status !== "Active").length}
              </p>
              <p className="stat-label">Inactive Units</p>
            </div>
          </div>
        </div>

            {/* HVAC Equipment Table */}
            <div className="hvac-table">
            <h2>HVAC Equipment Summary</h2>

                {/* Search + Filter */}
                <div className="table-controls">
                    <input
                    type="text"
                    placeholder="Search equipment name"
                    value={search}
                    onChange={e => setSearch(e.target.value)}
                    />
                    <select>
                    <option>Status</option>
                    <option>Active</option>
                    <option>Inactive</option>
                    </select>
                    <button>Search</button>
                    </div>


                    {loading ? (
                        <p>Loading HVAC data...</p>
                        ) : (
                    <table>
                        <thead>
                            <tr>
                            <th>ID</th>
                            <th>Room</th>
                            <th>Name</th>
                            <th>Status</th>
                            <th>QR Code</th>
                            <th>Created</th>
                            </tr>
                        </thead>
                        <tbody>
                            {filtered.map((eq) => (
                            <tr key={eq.id}>
                                <td>{eq.id}</td>
                                <td>{eq.room}</td>
                                <td>{eq.name}</td>
                                <td>{eq.status}</td>
                                <td>{eq.qr_code}</td>
                                <td>{new Date(eq.created_at).toLocaleDateString()}</td>
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

export default HVACPage;