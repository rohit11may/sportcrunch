import { useRef, useEffect, useState, forwardRef, useImperativeHandle } from 'react';
import { Play, Pause } from 'lucide-react';
import clsx from 'clsx';

interface VideoPlayerProps {
    src: string;
    onTimeUpdate: (time: number) => void;
    onDurationChange: (duration: number) => void;
    className?: string;
}

export interface VideoPlayerHandle {
    getCurrentTime: () => number;
    seek: (time: number) => void;
    stepFrame: (frames: number) => void;
}

const VideoPlayer = forwardRef<VideoPlayerHandle, VideoPlayerProps>(({ src, onTimeUpdate, onDurationChange, className }, ref) => {
    const videoRef = useRef<HTMLVideoElement>(null);
    const [isPlaying, setIsPlaying] = useState(false);
    const [playbackRate, setPlaybackRate] = useState(1);
    const [currentTime, setCurrentTime] = useState(0);
    const [duration, setDuration] = useState(0);

    useImperativeHandle(ref, () => ({
        getCurrentTime: () => videoRef.current?.currentTime || 0,
        seek: (time: number) => {
            if (videoRef.current) {
                videoRef.current.currentTime = time;
            }
        },
        stepFrame: (frames: number) => {
            if (videoRef.current) {
                // Assumes 30fps roughly for stepping if simpler, or 1/30
                const FRAME_TIME = 1 / 30; // Standard approximation
                videoRef.current.currentTime = Math.min(Math.max(videoRef.current.currentTime + (frames * FRAME_TIME), 0), videoRef.current.duration);
            }
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
            onDurationChange(videoRef.current.duration);
        }
    };

    return (
        <div className={clsx("flex flex-col gap-2 rounded-lg bg-black/90 p-2", className)}>
            <video
                ref={videoRef}
                src={src}
                className="w-full rounded bg-black"
                onTimeUpdate={handleTimeUpdate}
                onLoadedMetadata={handleLoadedMetadata}
                onEnded={() => setIsPlaying(false)}
                onClick={togglePlay}
            />

            <div className="flex items-center justify-between text-white text-sm">
                <div className="flex items-center gap-2">
                    <button onClick={togglePlay} className="p-1 hover:text-blue-400">
                        {isPlaying ? <Pause size={20} /> : <Play size={20} />}
                    </button>
                    <div className="font-mono text-xs">
                        {currentTime.toFixed(2)}s / {duration.toFixed(2)}s
                    </div>
                </div>

                <div className="flex items-center gap-2">
                    <span className="text-xs text-gray-400">Speed:</span>
                    {[0.25, 0.5, 1, 1.5, 2].map(rate => (
                        <button
                            key={rate}
                            onClick={() => setPlaybackRate(rate)}
                            className={clsx(
                                "px-1.5 py-0.5 rounded text-xs",
                                playbackRate === rate ? "bg-blue-600 text-white" : "bg-gray-700 text-gray-300 hover:bg-gray-600"
                            )}
                        >
                            {rate}x
                        </button>
                    ))}
                </div>
            </div>
        </div>
    );
});

export default VideoPlayer;
