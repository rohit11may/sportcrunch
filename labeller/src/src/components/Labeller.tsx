import { useEffect, useState, useRef } from 'react';
import { api, getVideoUrl } from '../api';
import type { VideoSession, AnnotationData, Segment } from '../types';
import VideoPlayer, { type VideoPlayerHandle } from './VideoPlayer';
import { Save, Video as VideoIcon, Plus, Trash2, ArrowRight } from 'lucide-react';
import clsx from 'clsx';

const Labeller: React.FC = () => {
    const [sessions, setSessions] = useState<VideoSession[]>([]);
    const [currentSessionIndex, setCurrentSessionIndex] = useState<number>(-1);
    const [sport, setSport] = useState<'tennis' | 'cricket' | 'custom'>('tennis'); // Allow custom initially or just type
    const [mode, setMode] = useState<string>('rally');
    const [segments, setSegments] = useState<Segment[]>([]);

    // Transient state for "current segment being recorded"
    const [pendingStart, setPendingStart] = useState<number | null>(null);

    const [loading, setLoading] = useState(true);
    const [, setCurrentTime] = useState(0);
    const videoRef = useRef<VideoPlayerHandle>(null);

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
                // Auto-select first if none selected
                // But generally wait for user or select index 0
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
                // Keep previous sport/mode settings or reset? User might want persistence.
            }
        }
    }, [currentSessionIndex, currentSession]); // Depend on index to trigger reload if same session object changed deep? No, just session.

    const handleSave = async () => {
        if (!currentSession) return;
        const annotation: AnnotationData = {
            videoFilename: currentSession.filename,
            sport: sport as any,
            mode: mode as any,
            segments
        };
        await api.saveAnnotation(annotation);
        // Optimistically update local session
        const newSessions = [...sessions];
        newSessions[currentSessionIndex].annotation = annotation;
        setSessions(newSessions);
        alert('Saved!');
    };

    // Hotkeys
    useEffect(() => {
        const handler = (e: KeyboardEvent) => {
            // Ignore if typing in input (if we had any)
            if (e.target instanceof HTMLInputElement) return;

            switch (e.key) {
                case '[':
                    if (videoRef.current) {
                        const time = videoRef.current.getCurrentTime();
                        setPendingStart(time);
                        console.log('Start set at', time);
                    }
                    break;
                case ']':
                    if (pendingStart !== null && videoRef.current) {
                        const end = videoRef.current.getCurrentTime();
                        if (end > pendingStart) {
                            setSegments(prev => [...prev, { start: pendingStart, end }].sort((a, b) => a.start - b.start));
                            setPendingStart(null);
                            console.log('Segment added', pendingStart, end);
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
                case 'ArrowUp':
                    // Optional: Navigate videos?
                    break;
                case 'ArrowDown':
                    break;
            }
        };

        window.addEventListener('keydown', handler);
        return () => window.removeEventListener('keydown', handler);
    }, [pendingStart, currentSessionIndex]); // Need pendingStart in deps? Yes, inside closure.

    const fileInputRef = useRef<HTMLInputElement>(null);
    const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
        if (e.target.files && e.target.files[0]) {
            await api.uploadVideo(e.target.files[0]);
            await loadSessions();
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
                        <button
                            key={s.filename}
                            onClick={() => setCurrentSessionIndex(idx)}
                            className={clsx(
                                "w-full text-left px-3 py-2 rounded text-sm flex items-center gap-2 transition-colors",
                                idx === currentSessionIndex ? "bg-blue-600 text-white" : "text-slate-400 hover:bg-slate-800"
                            )}
                        >
                            <VideoIcon size={14} />
                            <span className="truncate">{s.filename}</span>
                            {s.annotation && <span className="ml-auto w-2 h-2 rounded-full bg-green-400"></span>}
                        </button>
                    ))}
                </div>
            </div>

            {/* Main Content */}
            <div className="flex-1 flex flex-col overflow-hidden">
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

                    <button
                        onClick={handleSave}
                        className="flex items-center gap-2 bg-green-600 hover:bg-green-500 text-white px-4 py-1.5 rounded font-medium text-sm transition-transform active:scale-95"
                    >
                        <Save size={16} /> Save
                    </button>
                </div>

                {/* Workspace */}
                <div className="flex-1 flex overflow-hidden">
                    {/* Video Area */}
                    <div className="flex-1 p-6 flex flex-col justify-center items-center bg-black/40 relative">
                        {currentSession ? (
                            <div className="w-full max-w-4xl">
                                <VideoPlayer
                                    ref={videoRef}
                                    src={getVideoUrl(currentSession.filename)}
                                    onTimeUpdate={setCurrentTime}
                                    onDurationChange={() => { }}
                                />
                                <div className="mt-4 text-center text-slate-400 text-sm">
                                    <span className="px-2 py-1 bg-slate-800 rounded mx-1 text-slate-200">[</span> Start Segment
                                    <span className="px-2 py-1 bg-slate-800 rounded mx-1 text-slate-200">]</span> End Segment
                                    <span className="px-2 py-1 bg-slate-800 rounded mx-1 text-slate-200">←/→</span> Step Frame
                                </div>

                                {pendingStart !== null && (
                                    <div className="absolute top-4 left-1/2 -translate-x-1/2 bg-red-500/90 text-white px-4 py-1 rounded-full text-sm animate-pulse">
                                        Recording Segment... (Start: {pendingStart.toFixed(2)}s)
                                    </div>
                                )}
                            </div>
                        ) : (
                            <div className="text-slate-500">Select a video to start labelling</div>
                        )}
                    </div>

                    {/* Segment List (Right Panel) */}
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
                                        {seg.start.toFixed(2)}s <ArrowRight size={12} className="inline text-slate-500" /> {seg.end.toFixed(2)}s
                                    </div>
                                    <button
                                        onClick={(e) => { e.stopPropagation(); setSegments(segments.filter((_, idx) => idx !== i)); }}
                                        className="text-slate-500 hover:text-red-400 opacity-0 group-hover:opacity-100 transition-opacity p-1"
                                    >
                                        <Trash2 size={14} />
                                    </button>
                                </div>
                            ))}
                            {segments.length === 0 && (
                                <div className="text-center text-slate-600 mt-10 text-sm italic">
                                    No segments yet. Use [ and ] to add.
                                </div>
                            )}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Labeller;
