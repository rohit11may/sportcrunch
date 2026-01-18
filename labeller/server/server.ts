import express from 'express';
import cors from 'cors';
import fs from 'fs-extra';
import path from 'path';
import multer from 'multer';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

const app = express();
const PORT = 3001;

const VIDEOS_DIR = path.join(__dirname, '../data/videos');
const ANNOTATIONS_DIR = path.join(__dirname, '../data/annotations');

// Helper to get annotation path from a video filename/session ID
const getAnnotationPath = (id: string) => {
    const base = id.endsWith('.mp4') ? id.slice(0, -4) : id;
    return path.join(ANNOTATIONS_DIR, `${base}.json`);
};

// Ensure directories exist
fs.ensureDirSync(VIDEOS_DIR);
fs.ensureDirSync(ANNOTATIONS_DIR);

app.use(cors());
app.use(express.json());

// Serve static video files
app.use('/videos', express.static(VIDEOS_DIR));

// Setup multer for file copy/upload
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, VIDEOS_DIR);
    },
    filename: (req, file, cb) => {
        cb(null, file.originalname);
    }
});
const upload = multer({ storage });

// API: Upload/Copy video
// Since this is a local tool, we can also just accept a file path in the body 
// if we wanted to copy from fs to fs, but upload is more universal for the UI.
// For now, let's just use standard upload middleware which handles the copy.
app.post('/api/upload', upload.single('video'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
    }
    res.json({ filename: req.file.filename });
});

// API: Get Session (List videos + annotations)
app.get('/api/session', async (req, res) => {
    try {
        const videoFiles = await fs.readdir(VIDEOS_DIR);
        const sessions = [];

        for (const filename of videoFiles) {
            if (!filename.endsWith('.mp4')) continue;

            const annotationPath = getAnnotationPath(filename);
            let annotation = null;
            if (await fs.pathExists(annotationPath)) {
                annotation = await fs.readJson(annotationPath);
            }
            sessions.push({
                id: filename,
                videoFilename: filename,
                displayName: filename,
                annotation
            });
        }

        res.json(sessions);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to list session' });
    }
});

// API: Save Annotation
app.post('/api/save', async (req, res) => {
    try {
        const data = req.body;
        if (!data.videoFilename || !data.segments) {
            return res.status(400).json({ error: 'Invalid data format' });
        }
        const annotationPath = getAnnotationPath(data.videoFilename);
        await fs.writeJson(annotationPath, data, { spaces: 2 });
        console.log(`Saved annotation for ${data.videoFilename}`);
        res.json({ success: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to save annotation' });
    }
});

// API: Delete Session
app.delete('/api/session/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const videoPath = path.join(VIDEOS_DIR, id);
        const annotationPath = getAnnotationPath(id);

        if (await fs.pathExists(videoPath)) await fs.remove(videoPath);
        if (await fs.pathExists(annotationPath)) await fs.remove(annotationPath);

        console.log(`Deleted session ${id}`);
        res.json({ success: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to delete session' });
    }
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://localhost:${PORT}`);
});
