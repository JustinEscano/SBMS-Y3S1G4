import React from "react";
import PageLayout from "./PageLayout";

const LLMChatPage: React.FC = () => {
  return (
    <PageLayout initialSection={{ parent: "LLM" }}>
      <h1>LLM Chat</h1>
      <p>Chat interface and tools go here.</p>
    </PageLayout>
  );
};

export default LLMChatPage;
