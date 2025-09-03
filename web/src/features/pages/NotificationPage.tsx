import React from "react";
import PageLayout from "./PageLayout";
import NotificationCard from './NotificationCard';
import "../components/Notifications.css";

const NotificationPage: React.FC = () => {
  const notifications = [
    { id: 1, title: 'Notification 1', content: 'This is the first notification.', createdAt: '2023-09-01' },
    { id: 2, title: 'Notification 2', content: 'This is the second notification.', createdAt: '2023-09-02' },
    { id: 3, title: 'Notification 3', content: 'This is the third notification.', createdAt: '2023-09-03' },
    { id: 4, title: 'Notification 4', content: 'This is the fourth notification.', createdAt: '2023-09-04' },
    { id: 5, title: 'Notification 5', content: 'This is the fifth notification.', createdAt: '2023-09-05' },
  ];

  const sortedNotifications = notifications.sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  );

  return (
    <PageLayout initialSection={{ parent: "Notification" }}>
      <div className="notif-grid">
        {sortedNotifications.map((notif) => (
          <div key={notif.id}>
            <NotificationCard notif={notif} />
          </div>
        ))}
      </div>
    </PageLayout>
  );
};

export default NotificationPage;
