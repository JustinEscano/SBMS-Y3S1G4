import React from "react";
import PageLayout from "./PageLayout";

const NotificationPage: React.FC = () => {
  return (
    <PageLayout initialSection={{ parent: "Notification" }}>
      <h1>Notifications</h1>
      <p>Notification list and settings go here.</p>
    </PageLayout>
  );
};

export default NotificationPage;
