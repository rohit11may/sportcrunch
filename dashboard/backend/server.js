import express from 'express';
import cors from 'cors';
import multer from 'multer';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

// Get current directory (ES module equivalent of __dirname)
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Environment configuration
const PORT = process.env.PORT || 3000;
const RUNNER_URL = process.env.RUNNER_URL || 'http://localhost:8080';

// Path to test videos
const TEST_VIDEOS_PATH = path.resolve(__dirname, '../../app/SportCrunchTests/TestResources/Videos');
const UPLOADS_PATH = path.resolve(__dirname, 'uploads');

// Create Express app
const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Serve video files from TestResources/Videos
app.use('/videos', express.static(TEST_VIDEOS_PATH));

// Serve uploaded videos
app.use('/uploads', express.static(UPLOADS_PATH));

// Serve highlight videos from cache
const CACHE_PATH = path.resolve(__dirname, 'cache/highlights');
if (!fs.existsSync(CACHE_PATH)) {
  fs.mkdirSync(CACHE_PATH, { recursive: true });
}
app.use('/highlights', express.static(CACHE_PATH));

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
// Sport Discovery Endpoints
// ==========================================

// GET /api/sports - List available sports (proxy to iOS Runner)
app.get('/api/sports', async (req, res) => {
  try {
    const response = await fetch(`${RUNNER_URL}/sports`, {
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
        error: 'iOS Runner unavailable. Please ensure the Runner app is running.'
      });
    }

    console.error('❌ Error fetching sports:', error);
    res.status(500).json({ error: 'Failed to fetch sports' });
  }
});

// GET /api/sports/:sport - Get specific sport details (proxy to iOS Runner)
app.get('/api/sports/:sport', async (req, res) => {
  try {
    const { sport } = req.params;
    const response = await fetch(`${RUNNER_URL}/sports/${sport}`, {
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
        error: 'iOS Runner unavailable. Please ensure the Runner app is running.'
      });
    }

    console.error('❌ Error fetching sport:', error);
    res.status(500).json({ error: 'Failed to fetch sport details' });
  }
});

// ==========================================
// iOS Runner Proxy Endpoints
// ==========================================

// POST /api/runs - Create new run
app.post('/api/runs', async (req, res) => {
  try {
    const { videoPath, sport, sportMode, deviceId, deviceIp } = req.body;

    // Validate required fields
    if (!videoPath) {
      return res.status(400).json({ error: 'Missing required field: videoPath' });
    }
    if (!sport) {
      return res.status(400).json({ error: 'Missing required field: sport' });
    }

    // Determine the runner URL based on device selection
    let runnerUrl = RUNNER_URL; // Default to localhost (simulator)

    if (deviceId && deviceId !== 'simulator') {
      // Physical device - use the provided IP
      if (!deviceIp) {
        return res.status(400).json({
          error: 'Device IP is required for physical devices. Please enter your device IP address.'
        });
      }
      runnerUrl = `http://${deviceIp}:8080`;
      console.log(`📱 Targeting physical device at: ${runnerUrl}`);
    } else {
      console.log(`📱 Targeting simulator at: ${runnerUrl}`);
    }

    // Forward to iOS Runner with new API format
    const response = await fetch(`${runnerUrl}/runs`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        videoPath,
        sport,
        sportMode,
        deviceTarget: deviceId === 'simulator' ? 'simulator' : 'device'
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

    // Save mapping of Run ID -> Host Video Path
    try {
      const MAP_FILE = path.resolve(__dirname, 'run-map.json');
      let runMap = {};
      if (fs.existsSync(MAP_FILE)) {
        runMap = JSON.parse(fs.readFileSync(MAP_FILE, 'utf8'));
      }

      runMap[data.id] = videoPath;
      fs.writeFileSync(MAP_FILE, JSON.stringify(runMap, null, 2));
      console.log(`📝 Saved video path mapping for run ${data.id}`);
    } catch (err) {
      console.error('⚠️ Failed to save run mapping:', err);
    }

    res.status(202).json(data);

    console.log(`✅ Created run: ${data.id} (${sport}${sportMode ? `/${sportMode}` : ''})`);
  } catch (error) {
    if (error.name === 'AbortError' || error.code === 'ECONNREFUSED') {
      console.error('❌ iOS Runner unavailable:', error.message);
      return res.status(503).json({
        error: 'iOS Runner unavailable. Please ensure the Runner app is running on the target device.'
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

// ==========================================
// Helper: Run Map / Cache
// ==========================================
const MAP_FILE = path.resolve(__dirname, 'run-map.json');

function getRunMap() {
  try {
    if (fs.existsSync(MAP_FILE)) {
      return JSON.parse(fs.readFileSync(MAP_FILE, 'utf8'));
    }
  } catch (err) {
    console.error('⚠️ Failed to load run map:', err);
  }
  return {};
}

function updateRunMap(id, data) {
  try {
    const map = getRunMap();
    const existing = map[id] || {};

    // Handle migration from string (old format) to object
    const entry = typeof existing === 'string' ? { videoPath: existing } : existing;

    map[id] = { ...entry, ...data };
    fs.writeFileSync(MAP_FILE, JSON.stringify(map, null, 2));
    // console.log(`📝 Updated cache for run ${id}`);
  } catch (err) {
    console.error('⚠️ Failed to save run map:', err);
  }
}

function getRunFromCache(id) {
  const map = getRunMap();
  const entry = map[id];
  if (!entry) return null;
  // Handle migration
  return typeof entry === 'string' ? { videoPath: entry } : entry;
}


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

    // Cache segments for offline highlight generation
    if (data.segments) {
      updateRunMap(id, { segments: data.segments });
    }

    // Check if highlight video already exists
    const highlightPath = path.join(CACHE_PATH, `${id}-highlight.mp4`);
    if (fs.existsSync(highlightPath)) {
      const stats = fs.statSync(highlightPath);
      if (stats.size > 1000) {
        // Return absolute filesystem path - VideoPlayer will handle it
        data.highlightPath = highlightPath;
      }
    } else if (data.status === 'completed' && data.segments && data.segments.length > 0) {
      // Generate highlight video synchronously (blocks until ffmpeg completes)
      const cached = getRunFromCache(id);
      const hostVideoPath = cached?.videoPath;

      if (hostVideoPath && fs.existsSync(hostVideoPath)) {
        try {
          console.log(`🎬 Generating highlight video for ${id}...`);
          await generateHighlightVideo(id, data.segments, hostVideoPath);
          updateRunMap(id, { highlightPath: highlightPath });
          data.highlightPath = highlightPath;
          console.log(`✅ Highlight generation completed for ${id}`);
        } catch (err) {
          console.error('⚠️ Highlight generation failed:', err.message);
        }
      }
    }

    res.json(data);
  } catch (error) {
    if (error.name === 'AbortError' || error.code === 'ECONNREFUSED') {
      console.error('❌ iOS Runner unavailable:', error.message);

      // Try to serve from cache if available?
      // Not for now, frontend expects full run object.

      return res.status(503).json({
        error: 'iOS Runner unavailable. Please ensure the Runner app is running in the simulator.'
      });
    }

    console.error('❌ Error getting run:', error);
    res.status(500).json({ error: 'Failed to get run' });
  }
});
// ... 

// [Modified POST /api/runs logic is below, just verifying location]
// ...

// ==========================================
// Device Management Endpoints
// ==========================================

// Helper function to parse devicectl output
async function listDevices() {
  try {
    const { stdout } = await execAsync('xcrun devicectl list devices --json-output -');
    const data = JSON.parse(stdout);

    // Parse devices from the JSON output
    const devices = [];

    if (data.result && data.result.devices) {
      for (const device of data.result.devices) {
        devices.push({
          id: device.identifier,
          name: device.deviceProperties?.name || 'Unknown Device',
          model: device.hardwareProperties?.marketingName || device.hardwareProperties?.productType || 'Unknown Model',
          osVersion: device.deviceProperties?.osVersionNumber || 'Unknown',
          connectionType: device.connectionProperties?.tunnelTransport || 'usb',
          state: device.connectionProperties?.tunnelState || 'unknown'
        });
      }
    }

    return devices;
  } catch (error) {
    console.error('❌ Error listing devices:', error);
    return [];
  }
}

// Helper function to check if file exists on device
async function checkFileOnDevice(deviceId, bundleId, remotePath) {
  try {
    // Try to get file info using devicectl
    const { stdout, stderr } = await execAsync(
      `xcrun devicectl device info files --device "${deviceId}" --domain-type appDataContainer --domain-identifier "${bundleId}" "${remotePath}" 2>&1`
    );

    // If command succeeds and doesn't contain "not found" or "does not exist", file exists
    const output = (stdout + stderr).toLowerCase();
    return !output.includes('not found') && !output.includes('does not exist');
  } catch (error) {
    // If command fails, file doesn't exist
    return false;
  }
}

// Helper function to copy file to device
async function copyToDevice(deviceId, bundleId, sourcePath, destPath) {
  try {
    const command = `xcrun devicectl device copy to --device "${deviceId}" --domain-type appDataContainer --domain-identifier "${bundleId}" --source "${sourcePath}" --destination "${destPath}"`;

    console.log(`📲 Copying to device: ${command}`);
    const { stdout, stderr } = await execAsync(command);

    if (stderr && !stderr.includes('successfully')) {
      throw new Error(stderr);
    }

    return true;
  } catch (error) {
    console.error('❌ Error copying to device:', error);
    throw error;
  }
}

// GET /api/devices - List available devices
app.get('/api/devices', async (req, res) => {
  try {
    const devices = await listDevices();

    // Add simulator as a default option
    const allDevices = [
      {
        id: 'simulator',
        name: 'iOS Simulator',
        model: 'Simulator',
        osVersion: '',
        connectionType: 'local',
        state: 'available'
      },
      ...devices
    ];

    res.json(allDevices);
  } catch (error) {
    console.error('❌ Error getting devices:', error);
    res.status(500).json({ error: 'Failed to list devices' });
  }
});

// POST /api/devices/copy-video - Copy video to physical device
app.post('/api/devices/copy-video', async (req, res) => {
  try {
    const { deviceId, videoPath, videoName } = req.body;

    if (!deviceId || deviceId === 'simulator') {
      return res.json({ copied: false, message: 'Simulator does not require video copy' });
    }

    if (!videoPath || !videoName) {
      return res.status(400).json({ error: 'Missing required fields: videoPath, videoName' });
    }

    const bundleId = 'sportcrunch.SportCrunchRunner';
    const remotePath = `Documents/test-videos/${videoName}`;

    // Check if file already exists
    const exists = await checkFileOnDevice(deviceId, bundleId, remotePath);

    if (exists) {
      console.log(`✅ Video already exists on device: ${videoName}`);
      return res.json({
        copied: false,
        alreadyExists: true,
        message: 'Video already exists on device',
        remotePath
      });
    }

    // ... (previous endpoints)

    // Copy the file
    await copyToDevice(deviceId, bundleId, videoPath, remotePath);

    console.log(`✅ Copied video to device: ${videoName}`);
    res.json({
      copied: true,
      alreadyExists: false,
      message: 'Video copied successfully',
      remotePath
    });

  } catch (error) {
    console.error('❌ Error copying video to device:', error);
    res.status(500).json({ error: error.message || 'Failed to copy video to device' });
  }
});

// ==========================================
// Highlight Generation (Backend-side)
// ==========================================

// Helper to generate highlight video
async function generateHighlightVideo(runId, segments, hostVideoPath) {
  const highlightPath = path.join(CACHE_PATH, `${runId}-highlight.mp4`);

  // Return cached path if exists and valid
  if (fs.existsSync(highlightPath)) {
    const stats = fs.statSync(highlightPath);
    if (stats.size > 1000) {
      return highlightPath;
    }
  }

  console.log(`🎬 Generating highlight for run ${runId}...`);

  // Sort segments by start time
  const sortedSegments = [...segments].sort((a, b) => a.startTime - b.startTime);

  // Build ffmpeg filter - video only for reliability
  let filterComplex = '';
  let mapString = '';

  sortedSegments.forEach((seg, index) => {
    const start = seg.startTime.toFixed(3);
    const end = seg.endTime.toFixed(3);

    filterComplex += `[0:v]trim=start=${start}:end=${end},setpts=PTS-STARTPTS[v${index}];`;
    mapString += `[v${index}]`;
  });

  filterComplex += `${mapString}concat=n=${sortedSegments.length}:v=1:a=0[outv]`;

  // Video-only encoding with web-compatible settings
  const command = `ffmpeg -y -i "${hostVideoPath}" -filter_complex "${filterComplex}" -map "[outv]" -c:v libx264 -profile:v baseline -level 3.0 -pix_fmt yuv420p -movflags +faststart -an "${highlightPath}"`;

  console.log(`🛠 Executing ffmpeg...`);
  await execAsync(command);
  console.log(`✅ Highlight generated: ${highlightPath}`);

  return highlightPath;
}

// GET /api/runs/:id/highlight - Get or generate highlight video (legacy endpoint)
app.get('/api/runs/:id/highlight', async (req, res) => {
  const { id } = req.params;
  const highlightPath = path.join(CACHE_PATH, `${id}-highlight.mp4`);

  // 1. Serve cached file if exists
  if (fs.existsSync(highlightPath)) {
    // Check if file is empty or corrupted (e.g. < 1KB)
    const stats = fs.statSync(highlightPath);
    if (stats.size > 1000) {
      // console.log(`Serving cached highlight for ${id}`);
      return res.sendFile(highlightPath);
    }
  }

  console.log(`🎬 Generating highlight for run ${id}...`);

  try {
    // 2. Fetch run details to get segments
    // We fetch from the iOS Runner to get the latest status
    const response = await fetch(`${RUNNER_URL}/runs/${id}`, {
      method: 'GET',
      signal: AbortSignal.timeout(5000)
    });

    if (!response.ok) {
      if (response.status === 404) return res.status(404).send('Run not found');
      throw new Error(`Failed to fetch run: ${response.statusText}`);
    }

    const run = await response.json();

    if (!run.segments || run.segments.length === 0) {
      return res.status(404).send('No segments found for this run');
    }

    // 3. Find original video file on Host
    // First, check the run-map.json
    let hostVideoPath = null;
    try {
      const MAP_FILE = path.resolve(__dirname, 'run-map.json');
      if (fs.existsSync(MAP_FILE)) {
        const runMap = JSON.parse(fs.readFileSync(MAP_FILE, 'utf8'));
        if (runMap[id] && fs.existsSync(runMap[id])) {
          hostVideoPath = runMap[id];
          console.log(`📍 Found video path in map: ${hostVideoPath}`);
        }
      }
    } catch (err) { /* ignore */ }

    // If not in map, try resolving by filename
    if (!hostVideoPath) {
      // The run.videoPath is the DEVICE path (e.g. /Documents/...).
      // We need the HOST path. We search by filename.
      const filename = path.basename(run.videoPath);

      hostVideoPath = path.join(TEST_VIDEOS_PATH, filename);
      if (!fs.existsSync(hostVideoPath)) {
        // Try uploads
        hostVideoPath = path.join(UPLOADS_PATH, filename);
        if (!fs.existsSync(hostVideoPath)) {
          console.error(`❌ Original video not found on host: ${filename}`);
          return res.status(404).send('Original video file not found on server');
        }
      }
    }

    console.log(`📁 Found source video: ${hostVideoPath}`);

    // 4. Construct ffmpeg command
    // Filter complex to trim and concat
    const segments = run.segments.sort((a, b) => a.startTime - b.startTime);

    // Build filter string
    // [0:v]trim=start=S1:end=E1,setpts=PTS-STARTPTS[v0];
    // [0:a]atrim=start=S1:end=E1,asetpts=PTS-STARTPTS[a0];
    // ...
    // [v0][a0][v1][a1]concat=n=N:v=1:a=1[out]

    let filterComplex = '';
    let mapString = '';

    // Video-only encoding for reliability
    segments.forEach((seg, index) => {
      const start = seg.startTime.toFixed(3);
      const end = seg.endTime.toFixed(3);

      filterComplex += `[0:v]trim=start=${start}:end=${end},setpts=PTS-STARTPTS[v${index}];`;
      mapString += `[v${index}]`;
    });

    filterComplex += `${mapString}concat=n=${segments.length}:v=1:a=0[outv]`;

    // Video-only encoding with web-compatible settings
    const command = `ffmpeg -y -i "${hostVideoPath}" -filter_complex "${filterComplex}" -map "[outv]" -c:v libx264 -profile:v baseline -level 3.0 -pix_fmt yuv420p -movflags +faststart -an "${highlightPath}"`;

    console.log(`🛠 Executing ffmpeg...`);
    // console.log(command); // Debug

    const { stdout, stderr } = await execAsync(command);

    console.log(`✅ Highlight generated: ${highlightPath}`);
    res.sendFile(highlightPath);

  } catch (error) {
    console.error('❌ Error generating highlight:', error);
    // If ffmpeg failed, maybe due to missing audio? 
    // Fallback: try video only
    if (error.message && error.message.includes('Stream specifier') && error.message.includes('audio')) {
      // ... (Could implement fallback here)
    }

    res.status(500).json({
      error: 'Failed to generate highlight video',
      details: error.message
    });
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
