import express from 'express';
import cors from 'cors';
import fs from 'fs-extra';
import path from 'path';
import multer from 'multer';

const app = express();
const PORT = 3001;

const VIDEOS_DIR = path.join(__dirname, '../out/videos');
const ANNOTATIONS_DIR = path.join(__dirname, '../out/annotations');

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
        const videos = await Promise.all(videoFiles.filter(f => f.endsWith('.mp4')).map(async (filename) => {
            const annotationPath = path.join(ANNOTATIONS_DIR, `${filename}.json`);
            const hasAnnotation = await fs.pathExists(annotationPath);
            let annotation = null;
            if (hasAnnotation) {
                annotation = await fs.readJson(annotationPath);
            }
            return {
                filename,
                annotation
            };
        }));
        res.json(videos);
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
        const filename = `${data.videoFilename}.json`;
        await fs.writeJson(path.join(ANNOTATIONS_DIR, filename), data, { spaces: 2 });
        console.log(`Saved annotation for ${data.videoFilename}`);
        res.json({ success: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to save annotation' });
    }
});

app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});
