import React from "react";
import PageLayout from "./PageLayout";
import "./LLMChatPage.css";

const LLMChatPage: React.FC = () => {
  return (
    <PageLayout initialSection={{ parent: "LLM" }}>
      <div className="orb-chat-container">
        <div className="orb-greeting">
          <h2>Hello, I am Orb!</h2>
          <p>Let me know if you want something.</p>
        </div>

        <div className="orb-suggestions">
          {[
            "Suggest energy-saving actions",
            "Highest energy-consuming devices?",
            "Lowest temperature recorded today?",
            "Schedule weekly maintenance check for Generat...",
            "Next filter change for HVAC?",
            "Is the elevator usage in Building A abnormal?",
            "Which devices are likely to fail?",
          ].map((text, index) => (
            <button key={index} className="orb-suggestion-button">
              {text}
            </button>
          ))}
        </div>
      </div>

      {/* Floating input bar outside scrollable container */}
      <div className="orb-input-floating">
        {/* First row: full-width input */}
        <div className="orb-input-row">
          <input
            type="text"
            placeholder="Ask Orb..."
            className="orb-input"
          />
        </div>

        {/* Second row: buttons */}
        <div className="orb-button-row">
          <div className="orb-left-buttons">
            <button title="Attach a file..." className="orb-icon-button">📎</button>
            <button title="Settings" className="orb-icon-button">⚙️</button>
          </div>
          <div className="orb-right-button">
            <button title="Send prompt" className="orb-send-button">➤</button>
          </div>
        </div>
      </div>

    </PageLayout>
  );
};

export default LLMChatPage;
