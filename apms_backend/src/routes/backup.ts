// backup.ts
const API_URL = "http://localhost:4000/api/robot";

async function runBackup() {
  console.log("🤖 [Backup] Looking for active jobs...");
  try {
    // 1. Check for any job that is currently "DISPATCHED" (Moving...)
    const res = await fetch(`${API_URL}/jobs?status=DISPATCHED`);
    const jobs = await res.json();

    if (jobs.length > 0) {
      const jobId = jobs[0].job_id;
      console.log(`📦 [Backup] Found active Job: ${jobId}. Faking hardware movement...`);
      
      // 2. Wait 4 seconds to make the video look realistic
      setTimeout(async () => {
        console.log("✅ [Backup] Sending 'COMPLETED' signal to backend...");
        
        await fetch(`${API_URL}/dispense-success`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            job_id: jobId,
            drug_found: "MILGA", // You can change this to match the order
            status: "COMPLETED"
          })
        });
        
        console.log("🎉 [Backup] Done! The Flutter App should say 'Dispensed' now.");
      }, 4000);

    } else {
      console.log("❌ [Backup] No active jobs found. Click 'Process Selection' in the Flutter App first!");
    }
  } catch (error: any) { // <-- The TypeScript Error Fix
    console.error("Connection Error:", error.message);
  }
}

runBackup();