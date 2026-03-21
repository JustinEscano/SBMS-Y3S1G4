// HelpSupportPage.tsx - New page for /help-support
import React from "react";
import PageLayout from "./PageLayout";
import { MessageSquare, BookOpen, Video } from "lucide-react";

const HelpSupportPage: React.FC = () => {
  return (
    <PageLayout initialSection={{ parent: "Help & Support" }}>
      <div className="max-w-4xl mx-auto py-8">
        <div className="text-center mb-10">
          <h2 className="text-3xl font-bold text-white mb-3">How can we help?</h2>
          <p className="text-gray-400 text-lg">Choose a category below to get assistance with your SBMS experience.</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <button className="bg-[#0f172a] border border-gray-700/50 rounded-2xl p-8 flex flex-col items-center justify-center hover:bg-[#1e293b] hover:border-blue-500/50 transition-all group">
            <div className="w-16 h-16 rounded-full bg-blue-500/10 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform">
              <MessageSquare className="w-8 h-8 text-blue-400" />
            </div>
            <span className="text-lg font-semibold text-white mb-2">Contact Support</span>
            <span className="text-sm text-gray-400 text-center">Chat with our dedicated support team.</span>
          </button>

          <button className="bg-[#0f172a] border border-gray-700/50 rounded-2xl p-8 flex flex-col items-center justify-center hover:bg-[#1e293b] hover:border-purple-500/50 transition-all group">
            <div className="w-16 h-16 rounded-full bg-purple-500/10 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform">
              <BookOpen className="w-8 h-8 text-purple-400" />
            </div>
            <span className="text-lg font-semibold text-white mb-2">Documentation</span>
            <span className="text-sm text-gray-400 text-center">Browse detailed guides and FAQs.</span>
          </button>

          <button className="bg-[#0f172a] border border-gray-700/50 rounded-2xl p-8 flex flex-col items-center justify-center hover:bg-[#1e293b] hover:border-green-500/50 transition-all group">
            <div className="w-16 h-16 rounded-full bg-green-500/10 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform">
              <Video className="w-8 h-8 text-green-400" />
            </div>
            <span className="text-lg font-semibold text-white mb-2">Video Tutorials</span>
            <span className="text-sm text-gray-400 text-center">Watch step-by-step walkthroughs.</span>
          </button>
        </div>
        
        <div className="mt-12 bg-gradient-to-r from-blue-900/20 to-purple-900/20 border border-blue-500/20 rounded-2xl p-8 text-center">
          <h3 className="text-xl font-semibold text-white mb-2">Still need help?</h3>
          <p className="text-gray-400 mb-6">Our engineers are available 24/7 to help resolve technical issues.</p>
          <button className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors">
            Open a Ticket
          </button>
        </div>
      </div>
    </PageLayout>
  );
};

export default HelpSupportPage;