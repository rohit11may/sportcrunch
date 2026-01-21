import express from 'express';
import cors from 'cors';
import multer from 'multer';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

// Get current directory (ES module equivalent of __dirname)
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Environment configuration
const PORT = process.env.PORT || 3000;
const RUNNER_URL = process.env.RUNNER_URL || 'http://localhost:8080';

// Path to test videos
const TEST_VIDEOS_PATH = path.resolve(__dirname, '../SportCrunchTests/TestResources/Videos');
const UPLOADS_PATH = path.resolve(__dirname, 'uploads');

// Create Express app
const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Create uploads directory if it doesn't exist
if (!fs.existsSync(UPLOADS_PATH)) {
  fs.mkdirSync(UPLOADS_PATH, { recursive: true });
  console.log(`📁 Created uploads directory: ${UPLOADS_PATH}`);
}

// Configure multer for video uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, UPLOADS_PATH);
  },
  filename: (req, file, cb) => {
    cb(null, file.originalname);
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 500 * 1024 * 1024 // 500MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowedExtensions = ['.mp4', '.mov', '.m4v'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowedExtensions.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error(`Invalid file extension. Allowed: ${allowedExtensions.join(', ')}`));
    }
  }
});

// ==========================================
// Health Check Endpoint
// ==========================================

app.get('/api/health', async (req, res) => {
  const health = {
    backend: 'ready'
  };

  // Check iOS Runner health
  try {
    const response = await fetch(`${RUNNER_URL}/health`, {
      method: 'GET',
      signal: AbortSignal.timeout(2000) // 2 second timeout
    });

    if (response.ok) {
      health.runner = 'ready';
    } else {
      health.runner = 'unavailable';
    }
  } catch (error) {
    health.runner = 'unavailable';
  }

  res.json(health);
});

// ==========================================
// Video Management Endpoints
// ==========================================

// GET /api/videos - List videos from TestResources
app.get('/api/videos', (req, res) => {
  try {
    // Check if directory exists
    if (!fs.existsSync(TEST_VIDEOS_PATH)) {
      console.warn(`⚠️ Test videos directory not found: ${TEST_VIDEOS_PATH}`);
      return res.json([]);
    }

    // Read directory
    const files = fs.readdirSync(TEST_VIDEOS_PATH);

    // Filter video files and get details
    const videos = files
      .filter(file => {
        const ext = path.extname(file).toLowerCase();
        return ['.mp4', '.mov', '.m4v'].includes(ext);
      })
      .map(file => {
        const filePath = path.join(TEST_VIDEOS_PATH, file);
        const stats = fs.statSync(filePath);
        return {
          name: file,
          path: filePath,
          size: stats.size
        };
      });

    res.json(videos);
  } catch (error) {
    console.error('❌ Error listing videos:', error);
    res.status(500).json({ error: 'Failed to list videos' });
  }
});

// POST /api/videos/upload - Handle video upload
app.post('/api/videos/upload', upload.single('video'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No video file uploaded' });
    }

    const filePath = path.resolve(UPLOADS_PATH, req.file.filename);

    res.json({
      name: req.file.filename,
      path: filePath,
      size: req.file.size
    });

    console.log(`✅ Uploaded video: ${req.file.filename} (${req.file.size} bytes)`);
  } catch (error) {
    console.error('❌ Upload error:', error);
    res.status(500).json({ error: 'Failed to upload video' });
  }
});

// ==========================================
// iOS Runner Proxy Endpoints
// ==========================================

// POST /api/runs - Create new run
app.post('/api/runs', async (req, res) => {
  try {
    const { videoPath, method, sport, sportMode, config } = req.body;

    // Validate required fields
    if (!videoPath) {
      return res.status(400).json({ error: 'Missing required field: videoPath' });
    }
    if (!method) {
      return res.status(400).json({ error: 'Missing required field: method' });
    }
    if (!sport) {
      return res.status(400).json({ error: 'Missing required field: sport' });
    }

    // Forward to iOS Runner
    const response = await fetch(`${RUNNER_URL}/runs`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        videoPath,
        method,
        sport,
        sportMode,
        config: config || {}
      }),
      signal: AbortSignal.timeout(10000) // 10 second timeout
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ iOS Runner error (${response.status}):`, errorText);
      return res.status(response.status).json({
        error: `iOS Runner error: ${errorText}`
      });
    }

    const data = await response.json();
    res.status(202).json(data);

    console.log(`✅ Created run: ${data.id} (${method} on ${sport})`);
  } catch (error) {
    if (error.name === 'AbortError' || error.code === 'ECONNREFUSED') {
      console.error('❌ iOS Runner unavailable:', error.message);
      return res.status(503).json({
        error: 'iOS Runner unavailable. Please ensure the Runner app is running in the simulator.'
      });
    }

    console.error('❌ Error creating run:', error);
    res.status(500).json({ error: 'Failed to create run' });
  }
});

// GET /api/runs - List all runs
app.get('/api/runs', async (req, res) => {
  try {
    const response = await fetch(`${RUNNER_URL}/runs`, {
      method: 'GET',
      signal: AbortSignal.timeout(5000)
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ iOS Runner error (${response.status}):`, errorText);
      return res.status(response.status).json({
        error: `iOS Runner error: ${errorText}`
      });
    }

    const data = await response.json();
    res.json(data);
  } catch (error) {
    if (error.name === 'AbortError' || error.code === 'ECONNREFUSED') {
      console.error('❌ iOS Runner unavailable:', error.message);
      return res.status(503).json({
        error: 'iOS Runner unavailable. Please ensure the Runner app is running in the simulator.'
      });
    }

    console.error('❌ Error listing runs:', error);
    res.status(500).json({ error: 'Failed to list runs' });
  }
});

// GET /api/runs/:id - Get specific run details
app.get('/api/runs/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const response = await fetch(`${RUNNER_URL}/runs/${id}`, {
      method: 'GET',
      signal: AbortSignal.timeout(5000)
    });

    if (response.status === 404) {
      return res.status(404).json({ error: 'Run not found' });
    }

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ iOS Runner error (${response.status}):`, errorText);
      return res.status(response.status).json({
        error: `iOS Runner error: ${errorText}`
      });
    }

    const data = await response.json();
    res.json(data);
  } catch (error) {
    if (error.name === 'AbortError' || error.code === 'ECONNREFUSED') {
      console.error('❌ iOS Runner unavailable:', error.message);
      return res.status(503).json({
        error: 'iOS Runner unavailable. Please ensure the Runner app is running in the simulator.'
      });
    }

    console.error('❌ Error getting run:', error);
    res.status(500).json({ error: 'Failed to get run' });
  }
});

// ==========================================
// Error Handling Middleware
// ==========================================

app.use((err, req, res, next) => {
  console.error('❌ Unhandled error:', err);

  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(413).json({ error: 'File too large (max 500MB)' });
    }
    return res.status(400).json({ error: `Upload error: ${err.message}` });
  }

  res.status(500).json({ error: err.message || 'Internal server error' });
});

// ==========================================
// Start Server
// ==========================================

const server = app.listen(PORT, () => {
  console.log(`🚀 Backend server running on port ${PORT}`);
  console.log(`📁 Test videos: ${TEST_VIDEOS_PATH}`);
  console.log(`📁 Uploads: ${UPLOADS_PATH}`);
  console.log(`📡 iOS Runner: ${RUNNER_URL}`);
});

export { app, server };
