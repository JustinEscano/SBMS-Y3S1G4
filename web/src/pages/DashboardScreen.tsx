import { useAuth } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';

function DashboardScreen() {
  const { logout, role } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <div style={{ display: 'flex', height: '100vh' }}>
      {/* Sidebar */}
      <div style={{ width: '200px', background: '#222', color: '#fff', padding: '20px' }}>
        <h3>Admin Panel</h3>
        <ul style={{ listStyle: 'none', padding: 0 }}>
          <li style={{ margin: '10px 0' }}>Dashboard</li>
          <li style={{ margin: '10px 0' }}>Users</li>
          <li style={{ margin: '10px 0' }}>Logs</li>
          <li style={{ margin: '10px 0' }}>Equipment</li>
        </ul>
      </div>

      {/* Main content */}
      <div style={{ flex: 1, padding: '40px' }}>
        <h1>Welcome, Admin</h1>
        <p>Your role is: <strong>{role}</strong></p>
        
        <div style={{ marginTop: '30px' }}>
          <p>This is your dashboard. You can manage rooms, equipment, users, and view logs here.</p>
        </div>

        <button onClick={handleLogout} style={{ marginTop: '40px', padding: '10px 20px' }}>
          Logout
        </button>
      </div>
    </div>
  );
}

export default DashboardScreen;