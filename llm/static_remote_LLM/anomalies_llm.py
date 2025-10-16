# Simplified LLM-powered anomalies endpoint
# This will replace the complex anomalies/detect endpoint

def detect_anomalies_llm():
    """
    Anomaly detection with LLM-powered analysis - SIMPLIFIED
    """
    try:
        data = request.get_json() or {}
        user_id = data.get('user_id', 'anonymous')
        username = data.get('username', 'anonymous')
        
        logger.info(f"Anomaly detection request from {username}")
        
        # Initialize analyzer
        analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="anomaly_detection",
            document_template="anomaly_report"
        )
        
        # Fetch alerts from database
        alerts_df = analyzer.db_adapter.get_alerts_with_equipment_info(days_back=7)
        
        if alerts_df is None or alerts_df.empty:
            return jsonify({
                "status": "success",
                "answer": "No anomalies detected in the past 7 days. All systems operating normally.",
                "timestamp": datetime.now(timezone.utc).isoformat()
            })
        
        # Calculate statistics
        total_alerts = len(alerts_df)
        unresolved = alerts_df[alerts_df['is_resolved'] == False] if 'is_resolved' in alerts_df.columns else alerts_df
        unresolved_count = len(unresolved)
        
        # Group by severity
        severity_counts = alerts_df['severity_level'].value_counts().to_dict() if 'severity_level' in alerts_df.columns else {}
        
        # Group by type
        type_counts = alerts_df['alert_type'].value_counts().to_dict() if 'alert_type' in alerts_df.columns else {}
        
        # Prepare LLM context
        llm_context = f"""You are a system anomaly analyst. Analyze these alerts and provide recommendations.

ANOMALY DATA:
- Total Alerts (7 days): {total_alerts}
- Unresolved: {unresolved_count}
- By Severity: {severity_counts}
- By Type: {type_counts}

TOP ALERT TYPES:
"""
        for alert_type, count in list(type_counts.items())[:5]:
            llm_context += f"• {alert_type}: {count} occurrences\n"
        
        llm_context += f"""\n\nProvide 3 recommendations using this format:

**1. CRITICAL ISSUES:**
What anomalies need immediate attention?

**2. PATTERN ANALYSIS:**
What patterns do you see in the alerts?

**3. PREVENTIVE ACTIONS:**
What can we do to prevent these anomalies?

Be concise (2-3 sentences each)."""
        
        # Call LLM
        try:
            from langchain_ollama import OllamaLLM
            llm = OllamaLLM(model="incept5/llama3.1-claude:latest", temperature=0.7)
            llm_analysis = llm.invoke(llm_context)
            logger.info(f"LLM anomaly analysis generated for {username}")
        except Exception as llm_error:
            logger.warning(f"LLM call failed: {llm_error}")
            llm_analysis = f"""**1. CRITICAL ISSUES:**
{unresolved_count} unresolved alerts need attention.

**2. PATTERN ANALYSIS:**
Most common: {list(type_counts.keys())[0] if type_counts else 'No pattern'} with {list(type_counts.values())[0] if type_counts else 0} occurrences.

**3. PREVENTIVE ACTIONS:**
Monitor alert trends and address root causes proactively."""
        
        # Prepare alert list
        alerts_list = []
        for _, row in alerts_df.head(10).iterrows():
            alerts_list.append({
                "type": row.get('alert_type'),
                "message": row.get('message'),
                "severity": row.get('severity_level'),
                "timestamp": row['created_at'].isoformat() if pd.notna(row.get('created_at')) else None,
                "is_resolved": bool(row.get('is_resolved'))
            })
        
        response = {
            "status": "success",
            "answer": llm_analysis,
            "anomaly_data": {
                "total_alerts": total_alerts,
                "unresolved_count": unresolved_count,
                "severity_counts": severity_counts,
                "type_counts": type_counts,
                "alerts": alerts_list
            },
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Anomaly detection error: {e}\n{traceback.format_exc()}")
        return jsonify({
            "status": "error",
            "error": f"Anomaly detection failed: {str(e)}",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500
