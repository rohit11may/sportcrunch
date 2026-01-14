import { useEffect, useState, useRef } from 'react';
import { api, getVideoUrl } from '../api';
import type { VideoSession, AnnotationData, Segment } from '../types';
import VideoPlayer, { type VideoPlayerHandle } from './VideoPlayer';
import { Save, Video as VideoIcon, Plus, Trash2, ArrowRight } from 'lucide-react';
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

        }
    }, [currentSessionIndex, currentSession?.id]);

    const handleSave = async () => {
        if (!currentSession) return;
        const annotation: AnnotationData = {
            videoFilename: currentSession.id,
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
                                    onTimeUpdate={setCurrentTime}
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
                        </div>
                    </div>
                </div>


            </div>
        </div>
    );
};

export default Labeller;
