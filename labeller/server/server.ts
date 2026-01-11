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
        const claimedFiles = new Set<string>();
        const sessions = [];

        // First pass: handle videos with splits
        for (const filename of videoFiles) {
            if (!filename.endsWith('.mp4')) continue;

            const splitsPath = path.join(VIDEOS_DIR, `${filename}.splits.json`);
            if (await fs.pathExists(splitsPath)) {
                try {
                    const splitsData = await fs.readJson(splitsPath);
                    const parts = Array.isArray(splitsData) ? splitsData : (splitsData.parts || []);

                    if (parts.length > 0) {
                        const ext = path.extname(filename);
                        const base = path.basename(filename, ext);

                        for (const part of parts) {
                            const physicalFilename = `${base}_${part.id}${ext}`;
                            const physicalPath = path.join(VIDEOS_DIR, physicalFilename);
                            const hasPhysical = await fs.pathExists(physicalPath);

                            if (hasPhysical) claimedFiles.add(physicalFilename);

                            const partId = `${filename}__${part.id}`;
                            const annotationPath = getAnnotationPath(partId);

                            let annotation = null;
                            if (await fs.pathExists(annotationPath)) {
                                annotation = await fs.readJson(annotationPath);
                            }

                            sessions.push({
                                id: partId,
                                videoFilename: hasPhysical ? physicalFilename : filename,
                                sourceVideo: filename, // Keep track of original
                                displayName: part.name || part.label || part.id,
                                startTime: hasPhysical ? undefined : part.start,
                                endTime: hasPhysical ? undefined : part.end,
                                annotation
                            });
                        }
                        claimedFiles.add(filename); // Also claim the original to avoid showing it twice
                        continue;
                    }
                } catch (e) {
                    console.error(`Error reading splits for ${filename}`, e);
                }
            }
        }

        // Second pass: handle remaining videos
        for (const filename of videoFiles) {
            if (!filename.endsWith('.mp4') || claimedFiles.has(filename)) continue;

            const annotationPath = getAnnotationPath(filename);
            let annotation = null;
            if (await fs.pathExists(annotationPath)) {
                annotation = await fs.readJson(annotationPath);
            }
            sessions.push({
                id: filename,
                videoFilename: filename,
                sourceVideo: filename,
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

// API: Save Split Config + Perform Actual Split
app.post('/api/split', async (req, res) => {
    try {
        const { videoFilename, parts } = req.body;
        if (!videoFilename || !parts || !Array.isArray(parts)) {
            return res.status(400).json({ error: 'Invalid split data' });
        }

        const inputPath = path.join(VIDEOS_DIR, videoFilename);
        console.log(`Checking source video at: ${inputPath}`);
        if (!(await fs.pathExists(inputPath))) {
            console.error(`Source video not found: ${inputPath}`);
            return res.status(404).json({ error: `Source video not found: ${videoFilename}` });
        }

        // 1. Save splits metadata (optional but helpful for UI)
        const splitsPath = path.join(VIDEOS_DIR, `${videoFilename}.splits.json`);
        await fs.writeJson(splitsPath, parts, { spaces: 2 });

        // 2. Perform physical splits
        console.log(`Starting physical split for ${videoFilename}...`);

        for (const part of parts) {
            const ext = path.extname(videoFilename);
            const base = path.basename(videoFilename, ext);
            // Output filename e.g. "video_part1.mp4"
            const outputFilename = `${base}_${part.id}${ext}`;
            const outputPath = path.join(VIDEOS_DIR, outputFilename);

            const startTime = part.start;
            const duration = part.end - part.start;

            if (duration <= 0) continue;

            // FFMPEG command: fast copy (no re-encoding)
            // -ss before -i for fast seeking
            // -t for duration
            const command = `ffmpeg -y -ss ${startTime} -i "${inputPath}" -t ${duration} -c copy "${outputPath}"`;

            console.log(`Executing: ${command}`);
            try {
                await execAsync(command);
                console.log(`Created split: ${outputFilename}`);
            } catch (ffmpegErr) {
                console.error(`FFmpeg error for ${outputFilename}:`, ffmpegErr);
                // Continue with other parts if one fails
            }
        }

        console.log(`Saved and processed physical splits for ${videoFilename}`);
        res.json({ success: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to process splits' });
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

                // Delete physical split if it exists
                const ext = path.extname(videoFilename);
                const base = path.basename(videoFilename, ext);
                const physicalFilename = `${base}_${partId}${ext}`;
                const physicalPath = path.join(VIDEOS_DIR, physicalFilename);
                if (await fs.pathExists(physicalPath)) {
                    await fs.remove(physicalPath);
                }
            }

            // Delete annotation
            const annotationPath = getAnnotationPath(id);
            if (await fs.pathExists(annotationPath)) {
                await fs.remove(annotationPath);
            }
        } else {
            // Full video
            const videoPath = path.join(VIDEOS_DIR, id);
            const annotationPath = getAnnotationPath(id);
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
