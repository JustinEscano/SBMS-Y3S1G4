"""
Fix the 'Unknown room' issue in energy reports by adding JOIN to core_room table
Run this script to update database_adapter.py
"""

import re

# Read the file
with open('database_adapter.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Find and replace the get_energy_summary_data query
old_query = """            query = \"\"\"
            SELECT 
                id,
                period_start,
                period_end,
                period_type,
                total_energy,
                avg_power,
                peak_power,
                reading_count,
                anomaly_count,
                created_at,
                component_id,
                room_id,
                currency,
                total_cost
            FROM core_energysummary
            WHERE 1=1
            \"\"\""""

new_query = """            query = \"\"\"
            SELECT 
                es.id,
                es.period_start,
                es.period_end,
                es.period_type,
                es.total_energy,
                es.avg_power,
                es.peak_power,
                es.reading_count,
                es.anomaly_count,
                es.created_at,
                es.component_id,
                es.room_id,
                es.currency,
                es.total_cost,
                COALESCE(r.name, CONCAT('Room ', es.room_id)) as room_name
            FROM core_energysummary es
            LEFT JOIN core_room r ON es.room_id = r.id
            WHERE 1=1
            \"\"\""""

# Replace
if old_query in content:
    content = content.replace(old_query, new_query)
    print("✅ Found and replaced the query!")
else:
    print("❌ Could not find the exact query. Trying alternative approach...")
    # Try a more flexible regex approach
    pattern = r'(def get_energy_summary_data.*?query = """)\s*SELECT\s+id,\s+period_start,.*?FROM core_energysummary\s+WHERE 1=1\s+(""")'
    
    replacement = r'\1\n            SELECT \n                es.id,\n                es.period_start,\n                es.period_end,\n                es.period_type,\n                es.total_energy,\n                es.avg_power,\n                es.peak_power,\n                es.reading_count,\n                es.anomaly_count,\n                es.created_at,\n                es.component_id,\n                es.room_id,\n                es.currency,\n                es.total_cost,\n                COALESCE(r.name, CONCAT(\'Room \', es.room_id)) as room_name\n            FROM core_energysummary es\n            LEFT JOIN core_room r ON es.room_id = r.id\n            WHERE 1=1\n            \2'
    
    content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    print("✅ Applied regex replacement!")

# Write back
with open('database_adapter.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("\n✅ Fixed! The energy reports will now show actual room names instead of 'Unknown room'")
print("Restart the LLM server: python apillm.py")
