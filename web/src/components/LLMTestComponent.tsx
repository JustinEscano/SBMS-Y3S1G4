import React, { useState } from 'react';
import LLMService from '../service/LLMService';

const LLMTestComponent: React.FC = () => {
  const [testResult, setTestResult] = useState<string>('');
  const [isLoading, setIsLoading] = useState(false);

  const testLLMConnection = async () => {
    setIsLoading(true);
    setTestResult('Testing...');

    try {
      // Test health check first
      const health = await LLMService.checkHealth();
      setTestResult(`Health Check: ${health.status} - ${health.message}`);

      if (health.status === 'healthy') {
        // Test a simple query
        const response = await LLMService.queryLLM({
          query: 'How many records are there?'
        });
        setTestResult(prev => prev + `\n\nQuery Test: ${response.answer}`);
      }
    } catch (error: any) {
      setTestResult(`Error: ${error.message}`);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div style={{ padding: '20px', backgroundColor: '#2a2a2a', color: 'white', borderRadius: '8px', margin: '20px' }}>
      <h3>LLM Connection Test</h3>
      <button 
        onClick={testLLMConnection} 
        disabled={isLoading}
        style={{
          padding: '10px 20px',
          backgroundColor: '#0066cc',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: isLoading ? 'not-allowed' : 'pointer'
        }}
      >
        {isLoading ? 'Testing...' : 'Test LLM Connection'}
      </button>
      
      {testResult && (
        <pre style={{ 
          marginTop: '20px', 
          padding: '10px', 
          backgroundColor: '#1a1a1a', 
          borderRadius: '4px',
          whiteSpace: 'pre-wrap'
        }}>
          {testResult}
        </pre>
      )}
    </div>
  );
};

export default LLMTestComponent;