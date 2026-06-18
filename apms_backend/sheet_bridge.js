// sheet_bridge.js
const API_URL = "http://127.0.0.1:4000/api/robot";
const SHEET_CSV_URL = "https://docs.google.com/spreadsheets/d/e/2PACX-1vQsNpevj1Cus2dS_bhqh1dg1UoYRQtO8_GXCSiokmjHk8iU_nYqI0UsP1tx0cMnWHC_GqCsckY3nzno/pub?gid=0&single=true&output=csv"; 

let lastRowCount = 0;

console.log("🌉 Google Sheet Bridge Started... Watching for new drugs...");

setInterval(async () => {
  try {
    const response = await fetch(SHEET_CSV_URL);
    if (!response.ok) return; // لو في مشكلة من جوجل، سيبها وجرب المرة الجاية في صمت
    
    const text = await response.text();
    const rows = text.split('\n').filter(row => row.trim() !== ''); 
    
    if (lastRowCount === 0) {
      lastRowCount = rows.length;
      return;
    }

    if (rows.length > lastRowCount) {
      const newRow = rows[rows.length - 1]; 
      const drugName = newRow.split(',')[1]?.trim() || "MATCHED_DRUG"; 
      
      console.log(`\n🚨 [ALERT] Robot added new drug to Excel: ${drugName}`);
      
      const jobsRes = await fetch(`${API_URL}/jobs?status=DISPATCHED`);
      if (!jobsRes.ok) throw new Error("Backend not responding");
      const jobs = await jobsRes.json();

      if (jobs.length > 0) {
        console.log(`📦 Forwarding to Node DB for Job: ${jobs[0].job_id}...`);
        
        await fetch(`${API_URL}/dispense-success`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            job_id: jobs[0].job_id,
            drug_found: drugName,
            status: "COMPLETED"
          })
        });
        
        console.log("✅ Flutter App Updated to 'Dispensed'!");
      }
      lastRowCount = rows.length; 
    }
  } catch (error) {
    // لو النت فصل، هيطبع رسالة هادية جداً بدل الـ Errors الحمرا
    if (error.cause && (error.cause.code === 'UND_ERR_CONNECT_TIMEOUT' || error.cause.code === 'ENOTFOUND')) {
      console.log("⏳ Network lag detected... waiting for connection.");
    } else {
      console.log("⚠️ Minor fetch glitch, retrying in 3 seconds...");
    }
  }
}, 3000); // خليناها 3 ثواني عشان نريح الـ Request شوية