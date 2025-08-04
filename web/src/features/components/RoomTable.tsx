import React from 'react';
import { useRooms } from '../hooks/useRooms';

const RoomTable: React.FC = () => {
  const { rooms, loading } = useRooms();

  if (loading) return <p>Loading...</p>;

  return (
    <table>
      <thead>
        <tr>
          <th>Name</th>
          <th>Floor</th>
          <th>Capacity</th>
          <th>Type</th>
        </tr>
      </thead>
      <tbody>
        {rooms.map((room) => (
          <tr key={room.id}>
            <td>{room.name}</td>
            <td>{room.floor}</td>
            <td>{room.capacity}</td>
            <td>{room.type}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
};

export default RoomTable;