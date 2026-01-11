import { useEffect, useState, useRef } from 'react';
import { api, getVideoUrl } from '../api';
import type { VideoSession, AnnotationData, Segment } from '../types';
import VideoPlayer, { type VideoPlayerHandle } from './VideoPlayer';
import { Save, Video as VideoIcon, Plus, Trash2, ArrowRight, Scissors, X } from 'lucide-react';
import clsx from 'clsx';

const Labeller: React.FC = () => {
    const [sessions, setSessions] = useState<VideoSession[]>([]);
    const [currentSessionIndex, setCurrentSessionIndex] = useState<number>(-1);
    const [sport, setSport] = useState<'tennis' | 'cricket' | 'custom'>('tennis');
    const [mode, setMode] = useState<string>('rally');
    const [segments, setSegments] = useState<Segment[]>([]);

    const [pendingStart, setPendingStart] = useState<number | null>(null);
    const [loading, setLoading] = useState(true);
    const [, setCurrentTime] = useState(0);
    const [videoDuration, setVideoDuration] = useState(0); // Track duration
    const videoRef = useRef<VideoPlayerHandle>(null);

    // Split Modal State
    const [isSplitModalOpen, setIsSplitModalOpen] = useState(false);
    const [splitParts, setSplitParts] = useState<{ id: string, name: string, start: number, end: number }[]>([]);

    const currentSession = currentSessionIndex >= 0 ? sessions[currentSessionIndex] : null;

    useEffect(() => {
        loadSessions();
    }, []);

    const loadSessions = async () => {
        try {
            setLoading(true);
            const data = await api.getSessions();
            setSessions(data);
            if (data.length > 0 && currentSessionIndex === -1) {
                setCurrentSessionIndex(0);
            }
        } finally {
            setLoading(false);
        }
    };

    // Initialize state when switching videos
    useEffect(() => {
        if (currentSession) {
            if (currentSession.annotation) {
                setSport(currentSession.annotation.sport);
                setMode(currentSession.annotation.mode);
                setSegments(currentSession.annotation.segments);
            } else {
                setSegments([]);
                setPendingStart(null);
            }
            // Auto-seek to start range if applicable
            if (currentSession.startTime !== undefined && videoRef.current) {
                videoRef.current.seek(currentSession.startTime);
            }
        }
    }, [currentSessionIndex, currentSession?.id]);

    const handleSave = async () => {
        if (!currentSession) return;
        // Use currentSession.id (which handles split IDs correctly e.g. "vid__part1")
        // But backend expects "videoFilename" in body as the identifier. 
        // We will pass currentSession.id as videoFilename property to api.saveAnnotation
        // Wait, types says videoFilename. 
        const annotation: AnnotationData = {
            videoFilename: currentSession.id, // This ensures we save to vid__part1.json
            sport: sport as any,
            mode: mode as any,
            segments
        };
        await api.saveAnnotation(annotation);

        // Optimistically update
        const newSessions = [...sessions];
        newSessions[currentSessionIndex].annotation = annotation;
        setSessions(newSessions);
        alert('Saved!');
    };

    const handleOpenSplitModal = () => {
        if (!currentSession) return;
        // Find all sessions that share the same actual source video file
        const related = sessions.filter(s => s.sourceVideo === currentSession.sourceVideo);

        // Construct existing parts from sessions
        let parts = related.map((sess, idx) => ({
            id: sess.id.includes('__') ? sess.id.split('__')[1] : `part${idx + 1}`,
            name: sess.displayName,
            start: sess.startTime || 0,
            end: sess.endTime || videoDuration || 0
        }));

        // If simple session, might default to:
        if (parts.length === 0) {
            parts = [{ id: 'part1', name: 'Part 1', start: 0, end: videoDuration }];
        }

        setSplitParts(parts);
        setIsSplitModalOpen(true);
    };

    const handleSaveSplits = async () => {
        if (!currentSession) return;
        try {
            await api.saveSplit(currentSession.sourceVideo, splitParts);
            setIsSplitModalOpen(false);
            await loadSessions(); // Reload to see changes
        } catch (e: any) {
            console.error(e);
            alert(e.message || 'Failed to save splits');
        }
    };

    const addNewSplit = () => {
        const last = splitParts[splitParts.length - 1];
        const newStart = last ? last.end : 0;
        setSplitParts([...splitParts, {
            id: `part${splitParts.length + 1}`,
            name: `Part ${splitParts.length + 1}`,
            start: newStart,
            end: videoDuration
        }]);
    };

    const updateSplit = (idx: number, field: keyof typeof splitParts[0], value: any) => {
        const newParts = [...splitParts];
        newParts[idx] = { ...newParts[idx], [field]: value };
        setSplitParts(newParts);
    };

    // Hotkeys (unchanged mostly)
    useEffect(() => {
        const handler = (e: KeyboardEvent) => {
            if (e.target instanceof HTMLInputElement) return;
            switch (e.key) {
                case '[':
                    if (videoRef.current) {
                        const time = videoRef.current.getCurrentTime();
                        setPendingStart(time);
                    }
                    break;
                case ']':
                    if (pendingStart !== null && videoRef.current) {
                        const end = videoRef.current.getCurrentTime();
                        if (end > pendingStart) {
                            setSegments(prev => [...prev, { start: pendingStart, end }].sort((a, b) => a.start - b.start));
                            setPendingStart(null);
                        }
                    }
                    break;
                case 'ArrowLeft':
                    e.preventDefault();
                    videoRef.current?.stepFrame(-1);
                    break;
                case 'ArrowRight':
                    e.preventDefault();
                    videoRef.current?.stepFrame(1);
                    break;
                case ' ':
                    e.preventDefault();
                    videoRef.current?.togglePlay();
                    break;
                case 'z':
                    if (videoRef.current) {
                        const time = videoRef.current.getCurrentTime();
                        videoRef.current.seek(Math.max(0, time - 5));
                    }
                    break;
                case 'x':
                    if (videoRef.current) {
                        const time = videoRef.current.getCurrentTime();
                        // Assume we can get duration or just use a large enough bound
                        videoRef.current.seek(time + 5);
                    }
                    break;
                case 'n':
                    if (videoRef.current) {
                        const time = videoRef.current.getCurrentTime();
                        videoRef.current.seek(Math.max(0, time - 2));
                    }
                    break;
                case 'm':
                    if (videoRef.current) {
                        const time = videoRef.current.getCurrentTime();
                        videoRef.current.seek(time + 2);
                    }
                    break;
                case 's':
                    if (videoRef.current) {
                        const currentRate = videoRef.current.getPlaybackRate();
                        videoRef.current.setPlaybackRate(Math.round((currentRate - 0.1) * 10) / 10);
                    }
                    break;
                case 'd':
                    if (videoRef.current) {
                        const currentRate = videoRef.current.getPlaybackRate();
                        videoRef.current.setPlaybackRate(Math.round((currentRate + 0.1) * 10) / 10);
                    }
                    break;
            }
        };
        window.addEventListener('keydown', handler);
        return () => window.removeEventListener('keydown', handler);
    }, [pendingStart, currentSessionIndex]);

    const fileInputRef = useRef<HTMLInputElement>(null);
    const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
        if (e.target.files && e.target.files[0]) {
            await api.uploadVideo(e.target.files[0]);
            await loadSessions();
        }
    };

    const handleDeleteSession = async (e: React.MouseEvent, id: string) => {
        e.stopPropagation();
        if (window.confirm('Are you sure you want to delete this video/part?')) {
            try {
                await api.deleteSession(id);
                await loadSessions();
                if (currentSession?.id === id) {
                    setCurrentSessionIndex(-1);
                }
            } catch (err) {
                console.error(err);
                alert('Failed to delete');
            }
        }
    };

    if (loading) return <div className="text-white p-10">Loading...</div>;

    return (
        <div className="flex h-screen w-full bg-slate-900 text-slate-100 overflow-hidden font-sans">
            {/* Sidebar */}
            <div className="w-80 flex-shrink-0 border-r border-slate-700 flex flex-col bg-slate-950">
                <div className="p-4 border-b border-slate-700">
                    <h1 className="text-xl font-bold bg-gradient-to-r from-blue-400 to-indigo-400 bg-clip-text text-transparent">SportLabel</h1>
                    <button
                        onClick={() => fileInputRef.current?.click()}
                        className="mt-4 w-full flex items-center justify-center gap-2 bg-slate-800 hover:bg-slate-700 py-2 rounded border border-slate-700 transition"
                    >
                        <Plus size={16} /> Import Video
                    </button>
                    <input ref={fileInputRef} type="file" accept=".mp4" className="hidden" onChange={handleUpload} />
                </div>

                <div className="flex-1 overflow-y-auto p-2 space-y-1">
                    {sessions.map((s, idx) => (
                        <div
                            key={s.id}
                            className={clsx(
                                "group relative w-full flex items-center gap-2 px-3 py-2 rounded text-sm transition-colors cursor-pointer",
                                idx === currentSessionIndex ? "bg-blue-600 text-white" : "text-slate-400 hover:bg-slate-800"
                            )}
                            onClick={() => setCurrentSessionIndex(idx)}
                        >
                            <VideoIcon size={14} className="flex-shrink-0" />
                            <span className="truncate flex-1">{s.displayName || s.videoFilename}</span>
                            <div className="flex items-center gap-1.5">
                                {s.annotation && <span className="w-2 h-2 rounded-full bg-green-400"></span>}
                                <button
                                    onClick={(e) => handleDeleteSession(e, s.id)}
                                    className={clsx(
                                        "p-1 rounded hover:bg-black/20 text-slate-400 hover:text-red-400 transition-opacity",
                                        idx === currentSessionIndex ? "opacity-100" : "opacity-0 group-hover:opacity-100"
                                    )}
                                    title="Delete video"
                                >
                                    <Trash2 size={14} />
                                </button>
                            </div>
                        </div>
                    ))}
                </div>
            </div>

            {/* Main Content */}
            <div className="flex-1 flex flex-col overflow-hidden relative">
                {/* Header */}
                <div className="h-14 border-b border-slate-700 flex items-center justify-between px-6 bg-slate-900">
                    <div className="flex items-center gap-4">
                        <select
                            value={sport}
                            onChange={(e) => setSport(e.target.value as any)}
                            className="bg-slate-800 border border-slate-600 rounded px-2 py-1 text-sm focus:outline-none focus:border-blue-500"
                        >
                            <option value="tennis">Tennis</option>
                            <option value="cricket">Cricket</option>
                        </select>

                        <div className="flex bg-slate-800 rounded p-1">
                            {['shot', 'rally'].map(m => (
                                <button
                                    key={m}
                                    onClick={() => setMode(m)}
                                    className={clsx(
                                        "px-3 py-0.5 rounded text-xs capitalize transition-colors",
                                        mode === m ? "bg-blue-500 text-white shadow-sm" : "text-slate-400 hover:text-slate-200"
                                    )}
                                >
                                    {m}
                                </button>
                            ))}
                        </div>
                    </div>

                    <div className="flex items-center gap-3">
                        <button
                            onClick={handleOpenSplitModal}
                            className="flex items-center gap-2 bg-slate-800 hover:bg-slate-700 text-slate-300 px-3 py-1.5 rounded text-sm transition"
                            title="Split into parts"
                        >
                            <Scissors size={16} /> Split
                        </button>
                        <button
                            onClick={handleSave}
                            className="flex items-center gap-2 bg-green-600 hover:bg-green-500 text-white px-4 py-1.5 rounded font-medium text-sm transition-transform active:scale-95"
                        >
                            <Save size={16} /> Save
                        </button>
                    </div>
                </div>

                {/* Workspace */}
                <div className="flex-1 flex overflow-hidden">
                    {/* Video Area */}
                    <div className="flex-1 p-6 flex flex-col justify-center items-center bg-black/40 relative">
                        {currentSession ? (
                            <div className="w-full max-w-4xl">
                                <VideoPlayer
                                    ref={videoRef}
                                    src={getVideoUrl(currentSession.videoFilename)}
                                    startTime={currentSession.startTime}
                                    endTime={currentSession.endTime}
                                    onTimeUpdate={setCurrentTime}
                                    onDurationChange={setVideoDuration}
                                />
                                <div className="mt-4 text-center text-slate-400 text-sm flex flex-wrap justify-center gap-x-4 gap-y-1">
                                    <span><span className="px-2 py-0.5 bg-slate-800 rounded border border-slate-700 mx-1 text-slate-200">Space</span> Play/Pause</span>
                                    <span><span className="px-2 py-0.5 bg-slate-800 rounded border border-slate-700 mx-1 text-slate-200">[</span> Begin</span>
                                    <span><span className="px-2 py-0.5 bg-slate-800 rounded border border-slate-700 mx-1 text-slate-200">]</span> End</span>
                                    <span><span className="px-2 py-0.5 bg-slate-800 rounded border border-slate-700 mx-1 text-slate-200">←/→</span> Step</span>
                                    <span><span className="px-2 py-0.5 bg-slate-800 rounded border border-slate-700 mx-1 text-slate-200 text-xs text-blue-400">Z / X</span> ±5s</span>
                                    <span><span className="px-2 py-0.5 bg-slate-800 rounded border border-slate-700 mx-1 text-slate-200 text-xs text-indigo-400">N / M</span> ±2s</span>
                                    <span><span className="px-2 py-0.5 bg-slate-800 rounded border border-slate-700 mx-1 text-slate-200 text-xs text-emerald-400">S / D</span> ±0.1x</span>
                                </div>
                                {currentSession.startTime !== undefined && (
                                    <div className="mt-2 text-center text-xs text-yellow-400">
                                        Part Range: {currentSession.startTime}s - {currentSession.endTime}s
                                    </div>
                                )}

                                {pendingStart !== null && (
                                    <div className="absolute top-4 left-1/2 -translate-x-1/2 bg-red-500/90 text-white px-4 py-1 rounded-full text-sm animate-pulse">
                                        Recording Segment... (Start: {(pendingStart - (currentSession?.startTime || 0)).toFixed(2)}s)
                                    </div>
                                )}
                            </div>
                        ) : (
                            <div className="text-slate-500">Select a video to start labelling</div>
                        )}
                    </div>

                    {/* Segment List */}
                    <div className="w-72 bg-slate-900 border-l border-slate-700 flex flex-col">
                        <div className="p-3 border-b border-slate-700 bg-slate-900 font-medium text-slate-300">
                            Segments ({segments.length})
                        </div>
                        <div className="flex-1 overflow-y-auto p-2 space-y-2">
                            {segments.map((seg, i) => (
                                <div
                                    key={i}
                                    className="group bg-slate-800 rounded p-2 flex items-center justify-between border border-slate-700 hover:border-blue-500/50 transition-colors cursor-pointer"
                                    onClick={() => videoRef.current?.seek(seg.start)}
                                >
                                    <div className="text-sm font-mono text-blue-300">
                                        {(seg.start - (currentSession?.startTime || 0)).toFixed(2)}s <ArrowRight size={12} className="inline text-slate-500" /> {(seg.end - (currentSession?.startTime || 0)).toFixed(2)}s
                                    </div>
                                    <button
                                        onClick={(e) => { e.stopPropagation(); setSegments(segments.filter((_, idx) => idx !== i)); }}
                                        className="text-slate-500 hover:text-red-400 opacity-0 group-hover:opacity-100 transition-opacity p-1"
                                    >
                                        <Trash2 size={14} />
                                    </button>
                                </div>
                            ))}
                        </div>
                    </div>
                </div>

                {/* Split Modal */}
                {isSplitModalOpen && (
                    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
                        <div className="bg-slate-900 border border-slate-700 p-6 rounded-xl w-[600px] shadow-2xl overflow-hidden max-h-[80vh] flex flex-col">
                            <div className="flex justify-between items-center mb-6">
                                <h2 className="text-xl font-bold text-white">Manage Video Splits</h2>
                                <button onClick={() => setIsSplitModalOpen(false)} className="text-slate-400 hover:text-white"><X size={20} /></button>
                            </div>

                            <div className="flex-1 overflow-y-auto space-y-3 mb-6 pr-2">
                                {splitParts.map((part, i) => (
                                    <div key={i} className="flex gap-3 items-center bg-slate-800/50 p-3 rounded border border-slate-700">
                                        <input
                                            value={part.name}
                                            onChange={(e) => updateSplit(i, 'name', e.target.value)}
                                            className="bg-slate-900 border border-slate-700 rounded px-2 py-1 text-sm text-white flex-1 min-w-0"
                                            placeholder="Part Name"
                                        />
                                        <div className="flex items-center gap-1">
                                            <input
                                                type="number"
                                                value={part.start}
                                                onChange={(e) => updateSplit(i, 'start', parseFloat(e.target.value))}
                                                className="w-20 bg-slate-900 border border-slate-700 rounded px-2 py-1 text-sm text-center font-mono"
                                            />
                                            <span className="text-slate-500">-</span>
                                            <input
                                                type="number"
                                                value={part.end}
                                                onChange={(e) => updateSplit(i, 'end', parseFloat(e.target.value))}
                                                className="w-20 bg-slate-900 border border-slate-700 rounded px-2 py-1 text-sm text-center font-mono"
                                            />
                                        </div>
                                        <button
                                            onClick={() => setSplitParts(splitParts.filter((_, idx) => idx !== i))}
                                            className="p-1 hover:bg-slate-700 rounded text-slate-400 hover:text-red-400 transition"
                                        >
                                            <Trash2 size={16} />
                                        </button>
                                    </div>
                                ))}
                                {splitParts.length === 0 && <div className="text-center text-slate-500 italic p-4">No parts defined.</div>}
                            </div>

                            <div className="flex justify-between items-center pt-4 border-t border-slate-800">
                                <button
                                    onClick={addNewSplit}
                                    className="flex items-center gap-2 text-blue-400 hover:text-blue-300 text-sm font-medium"
                                >
                                    <Plus size={16} /> Add Split
                                </button>
                                <div className="flex gap-3">
                                    <button
                                        onClick={() => setIsSplitModalOpen(false)}
                                        className="px-4 py-2 rounded text-slate-300 hover:bg-slate-800 transition text-sm"
                                    >
                                        Cancel
                                    </button>
                                    <button
                                        onClick={handleSaveSplits}
                                        className="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded font-medium text-sm shadow-lg shadow-blue-500/20"
                                    >
                                        Apply Splits
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
};

export default Labeller;
