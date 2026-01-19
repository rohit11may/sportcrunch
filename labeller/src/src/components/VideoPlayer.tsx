import { useRef, useEffect, useState, forwardRef, useImperativeHandle, useMemo } from 'react';
import { Play, Pause } from 'lucide-react';
import clsx from 'clsx';
import type { Segment } from '../types';

interface VideoPlayerProps {
    src: string;
    onTimeUpdate: (time: number) => void;
    onDurationChange?: (duration: number) => void;
    className?: string;
    segments?: Segment[];
}

export interface VideoPlayerHandle {
    getCurrentTime: () => number;
    seek: (time: number) => void;
    stepFrame: (frames: number) => void;
    togglePlay: () => void;
    getPlaybackRate: () => number;
    setPlaybackRate: (rate: number) => void;
}

const VideoPlayer = forwardRef<VideoPlayerHandle, VideoPlayerProps>(({ src, onTimeUpdate, onDurationChange, className, segments = [] }, ref) => {
    const videoRef = useRef<HTMLVideoElement>(null);
    const [isPlaying, setIsPlaying] = useState(false);
    const [playbackRate, setPlaybackRate] = useState(1);
    const [currentTime, setCurrentTime] = useState(0);
    const [duration, setDuration] = useState(0);

    // Check if current time is within any recorded segment
    const isInSegment = useMemo(() => {
        return segments.some(seg => currentTime >= seg.start && currentTime <= seg.end);
    }, [segments, currentTime]);

    useImperativeHandle(ref, () => ({
        getCurrentTime: () => videoRef.current?.currentTime || 0,
        seek: (time: number) => {
            if (videoRef.current) {
                videoRef.current.currentTime = Math.min(Math.max(time, 0), videoRef.current.duration);
            }
        },
        stepFrame: (frames: number) => {
            if (videoRef.current) {
                const FRAME_TIME = 1 / 30;
                const newTime = videoRef.current.currentTime + (frames * FRAME_TIME);
                videoRef.current.currentTime = Math.min(Math.max(newTime, 0), videoRef.current.duration);
            }
        },
        togglePlay: () => togglePlay(),
        getPlaybackRate: () => playbackRate,
        setPlaybackRate: (rate: number) => {
            const newRate = Math.min(Math.max(rate, 0.1), 16);
            setPlaybackRate(newRate);
        }
    }));

    useEffect(() => {
        if (videoRef.current) {
            videoRef.current.playbackRate = playbackRate;
        }
    }, [playbackRate]);

    const togglePlay = () => {
        if (videoRef.current) {
            if (isPlaying) {
                videoRef.current.pause();
            } else {
                videoRef.current.play();
            }
            setIsPlaying(!isPlaying);
        }
    };

    const handleTimeUpdate = () => {
        if (videoRef.current) {
            setCurrentTime(videoRef.current.currentTime);
            onTimeUpdate(videoRef.current.currentTime);
        }
    };

    const handleLoadedMetadata = () => {
        if (videoRef.current) {
            setDuration(videoRef.current.duration);
            onDurationChange?.(videoRef.current.duration);
        }
    };

    return (
        <div className={clsx("flex flex-col gap-2 rounded-lg bg-black/90 p-2", className)}>
            {/* Video with red overlay when playing through recorded segments */}
            <div className="relative">
                <video
                    ref={videoRef}
                    src={src}
                    className="w-full rounded bg-black"
                    onTimeUpdate={handleTimeUpdate}
                    onLoadedMetadata={handleLoadedMetadata}
                    onEnded={() => setIsPlaying(false)}
                    onClick={togglePlay}
                />
                {/* Red overlay when current time is within a recorded segment */}
                {isInSegment && (
                    <div
                        className="absolute inset-0 bg-red-500/30 rounded pointer-events-none"
                        aria-hidden="true"
                    />
                )}
            </div>

            {/* Scrubber with segment highlights */}
            <div className="relative group/seekbar px-1">
                {/* Segment highlight bars */}
                {duration > 0 && segments.map((seg, index) => {
                    const leftPercent = (seg.start / duration) * 100;
                    const widthPercent = ((seg.end - seg.start) / duration) * 100;
                    return (
                        <div
                            key={index}
                            className="absolute top-0 bottom-0 bg-green-500/50 rounded pointer-events-none"
                            style={{
                                left: `${leftPercent}%`,
                                width: `${widthPercent}%`,
                            }}
                            aria-hidden="true"
                        />
                    );
                })}
                <input
                    type="range"
                    min={0}
                    max={duration || 0}
                    step={0.01}
                    value={currentTime}
                    onChange={(e) => {
                        const time = parseFloat(e.target.value);
                        if (videoRef.current) {
                            videoRef.current.currentTime = time;
                        }
                    }}
                    className="relative z-10 w-full h-1.5 bg-gray-700 rounded-lg appearance-none cursor-pointer accent-blue-500 hover:h-2 transition-all outline-none"
                />
            </div>

            <div className="flex items-center justify-between text-white text-sm">
                <div className="flex items-center gap-2">
                    <button onClick={togglePlay} className="p-1 hover:text-blue-400 transition-colors">
                        {isPlaying ? <Pause size={20} fill="currentColor" /> : <Play size={20} fill="currentColor" />}
                    </button>
                    <div className="font-mono text-xs flex gap-1">
                        <span className="text-blue-400">
                            {currentTime.toFixed(2)}s
                        </span>
                        <span className="text-gray-600">/</span>
                        <span className="text-gray-400">
                            {duration.toFixed(2)}s
                        </span>
                    </div>
                </div>

                <div className="flex items-center gap-2">
                    <div className="text-xs font-bold text-blue-500 bg-blue-500/10 px-1.5 py-0.5 rounded border border-blue-500/20">
                        {playbackRate.toFixed(1)}x
                    </div>
                    <span className="text-[10px] text-gray-500 uppercase tracking-tighter font-bold">Presets:</span>
                    <div className="flex bg-gray-800 rounded p-0.5">
                        {[0.25, 0.5, 1, 1.5, 2].map(rate => (
                            <button
                                key={rate}
                                onClick={() => setPlaybackRate(rate)}
                                className={clsx(
                                    "px-2 py-0.5 rounded text-[10px] font-medium transition-all",
                                    playbackRate === rate
                                        ? "bg-blue-600 text-white shadow-sm"
                                        : "text-gray-400 hover:text-gray-200 hover:bg-gray-700"
                                )}
                            >
                                {rate}x
                            </button>
                        ))}
                    </div>
                </div>
            </div>
        </div>
    );
});

export default VideoPlayer;
