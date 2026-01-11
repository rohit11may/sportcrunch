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
    filename: string;
    annotation: AnnotationData | null;
}
