export interface Segment {
    start: number;
    end: number;
}

export interface AnnotationData {
    videoFilename: string;
    sport: 'tennis' | 'cricket';
    mode: 'shot' | 'rally';
    segments: Segment[];
}

export interface VideoSession {
    id: string; // Unique identifier (e.g., "video.mp4" or "video.mp4::part1")
    videoFilename: string; // The actual video file path/name to play
    displayName: string; // User friendly name
    startTime?: number; // Optional start time in seconds
    endTime?: number; // Optional end time in seconds
    annotation: AnnotationData | null;
}
