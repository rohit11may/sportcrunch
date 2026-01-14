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
    id: string; // Filename (e.g., "video.mp4")
    videoFilename: string; // The actual video file path/name to play
    displayName: string; // User friendly name
    annotation: AnnotationData | null;
}
