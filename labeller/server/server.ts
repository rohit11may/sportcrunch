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
        const sessions = [];

        for (const filename of videoFiles) {
            if (!filename.endsWith('.mp4')) continue;

            // Check for splits
            const splitsPath = path.join(VIDEOS_DIR, `${filename}.splits.json`);
            const hasSplits = await fs.pathExists(splitsPath);

            if (hasSplits) {
                try {
                    const splitsData = await fs.readJson(splitsPath);
                    const parts = Array.isArray(splitsData) ? splitsData : (splitsData.parts || []);

                    if (parts.length > 0) {
                        for (const part of parts) {
                            // Construct ID: use __ as separator. 
                            // If part.id is simple (e.g. 'part1'), result is 'video.mp4__part1'
                            const partId = `${filename}__${part.id}`;
                            const annotationPath = path.join(ANNOTATIONS_DIR, `${partId}.json`);

                            let annotation = null;
                            if (await fs.pathExists(annotationPath)) {
                                annotation = await fs.readJson(annotationPath);
                            }

                            sessions.push({
                                id: partId,
                                videoFilename: filename,
                                displayName: part.name || part.label || part.id,
                                startTime: part.start,
                                endTime: part.end,
                                annotation
                            });
                        }
                        continue; // Done with this file
                    }
                } catch (e) {
                    console.error(`Error reading splits for ${filename}`, e);
                }
            }

            // Default (no splits or failed read)
            const annotationPath = path.join(ANNOTATIONS_DIR, `${filename}.json`);
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

// API: Save Split Config
app.post('/api/split', async (req, res) => {
    try {
        const { videoFilename, parts } = req.body;
        if (!videoFilename || !parts || !Array.isArray(parts)) {
            return res.status(400).json({ error: 'Invalid split data' });
        }
        // Parts should be Array<{id, name, start, end}>
        const splitsPath = path.join(VIDEOS_DIR, `${videoFilename}.splits.json`);
        await fs.writeJson(splitsPath, parts, { spaces: 2 });
        console.log(`Saved splits for ${videoFilename}`);
        res.json({ success: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to save splits' });
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

// API: Delete Session
app.delete('/api/session/:id', async (req, res) => {
    try {
        const { id } = req.params;
        // Find if it's a split part or a full video
        if (id.includes('__')) {
            const [videoFilename, partId] = id.split('__');
            const splitsPath = path.join(VIDEOS_DIR, `${videoFilename}.splits.json`);

            if (await fs.pathExists(splitsPath)) {
                const parts = await fs.readJson(splitsPath);
                const updatedParts = parts.filter((p: any) => p.id !== partId);

                if (updatedParts.length === 0) {
                    await fs.remove(splitsPath);
                } else {
                    await fs.writeJson(splitsPath, updatedParts, { spaces: 2 });
                }
            }

            // Delete annotation
            const annotationPath = path.join(ANNOTATIONS_DIR, `${id}.json`);
            if (await fs.pathExists(annotationPath)) {
                await fs.remove(annotationPath);
            }
        } else {
            // Full video
            const videoPath = path.join(VIDEOS_DIR, id);
            const annotationPath = path.join(ANNOTATIONS_DIR, `${id}.json`);
            const splitsPath = path.join(VIDEOS_DIR, `${id}.splits.json`);

            if (await fs.pathExists(videoPath)) await fs.remove(videoPath);
            if (await fs.pathExists(annotationPath)) await fs.remove(annotationPath);
            if (await fs.pathExists(splitsPath)) await fs.remove(splitsPath);
        }

        console.log(`Deleted session ${id}`);
        res.json({ success: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to delete session' });
    }
});

app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});
