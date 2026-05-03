import { Router } from 'express';
import { authenticateToken } from '../middleware/auth';
import multer from 'multer';

const router = Router();
const PYTHON_AI_BASE_URL = 'http://127.0.0.1:5000/api';
const upload = multer({ storage: multer.memoryStorage() });

router.post('/ocr-prescription', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No image file provided' });
    const formData = new FormData();
    const blob = new Blob([new Uint8Array(req.file.buffer)], { type: req.file.mimetype });
    formData.append('file', blob, req.file.originalname);

    const response = await fetch('http://127.0.0.1:5001/upload', {
      method: 'POST', body: formData as any,
    });

    const ocrResult = await response.json() as any;
    const medicines = (ocrResult.medicine_names || []).map((name: string) => ({ name, qty: 1 }));
    res.json({ medicines, count: medicines.length });
  } catch (error) {
    res.status(500).json({ error: 'Failed to reach OCR Service on port 5001' });
  }
});

// 🌟 ALL AI ROUTES NOW PROXY INSTANTLY TO PYTHON (GET requests only)
router.use(authenticateToken);

router.get('/overview', async (req, res) => {
    try {
        const response = await fetch(`${PYTHON_AI_BASE_URL}/overview_stats`);
        res.json(await response.json());
    } catch (e) { res.status(500).json({ error: 'AI Gateway Error' }); }
});

router.get('/demand', async (req, res) => {
    try {
        const response = await fetch(`${PYTHON_AI_BASE_URL}/demand_forecast`);
        res.json(await response.json());
    } catch (e) { res.status(500).json({ error: 'AI Gateway Error' }); }
});

router.get('/smart-reorder', async (req, res) => {
    try {
        const response = await fetch(`${PYTHON_AI_BASE_URL}/smart_reorder`);
        res.json(await response.json());
    } catch (e) { res.status(500).json({ error: 'AI Gateway Error' }); }
});

router.get('/expiry-risk', async (req, res) => {
    try {
        const response = await fetch(`${PYTHON_AI_BASE_URL}/expiry_risk_prediction`);
        res.json(await response.json());
    } catch (e) { res.status(500).json({ error: 'AI Gateway Error' }); }
});

router.get('/dead-stock', async (req, res) => {
    try {
        const response = await fetch(`${PYTHON_AI_BASE_URL}/dead_stock`);
        res.json(await response.json());
    } catch (e) { res.status(500).json({ error: 'AI Gateway Error' }); }
});

router.get('/sales-trend', async (req, res) => {
    try {
        const response = await fetch(`${PYTHON_AI_BASE_URL}/sales_trend`);
        res.json(await response.json());
    } catch (e) { res.status(500).json({ error: 'Failed' }); }
});

router.get('/category-distribution', async (req, res) => {
    try {
        const response = await fetch(`${PYTHON_AI_BASE_URL}/category_distribution`);
        res.json(await response.json());
    } catch (e) { res.status(500).json({ error: 'Failed' }); }
});

router.get('/supplier-distribution', async (req, res) => {
    try {
        const response = await fetch(`${PYTHON_AI_BASE_URL}/supplier_distribution`);
        res.json(await response.json());
    } catch (e) { res.status(500).json({ error: 'Failed' }); }
});

router.get('/anomalies', async (req, res) => {
    try {
        const response = await fetch(`${PYTHON_AI_BASE_URL}/anomaly_detection`);
        res.json(await response.json());
    } catch (e) { res.status(500).json({ error: 'Failed' }); }
});

router.get('/expiry-timeline', async (req, res) => {
    try {
        const response = await fetch(`${PYTHON_AI_BASE_URL}/expiry_timeline`);
        res.json(await response.json());
    } catch (e) { res.status(500).json({ error: 'Failed' }); }
});

export default router;