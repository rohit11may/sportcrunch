import type { AnnotationData, VideoSession } from './types';

const API_BASE = `http://${window.location.hostname}:3001/api`;

export const api = {
    getSessions: async (): Promise<VideoSession[]> => {
        const res = await fetch(`${API_BASE}/session`);
        if (!res.ok) throw new Error(`Failed to load sessions: ${res.statusText}`);
        return res.json();
    },

    saveAnnotation: async (data: AnnotationData): Promise<void> => {
        const res = await fetch(`${API_BASE}/save`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
        if (!res.ok) throw new Error(`Failed to save annotation: ${res.statusText}`);
    },

    uploadVideo: async (file: File): Promise<string> => {
        const formData = new FormData();
        formData.append('video', file);
        const res = await fetch(`${API_BASE}/upload`, {
            method: 'POST',
            body: formData,
        });
        const data = await res.json();
        return data.filename;
    },

    deleteSession: async (id: string): Promise<void> => {
        await fetch(`${API_BASE}/session/${id}`, {
            method: 'DELETE',
        });
    }
};

export const getVideoUrl = (filename: string) => `http://${window.location.hostname}:3001/videos/${filename}`;
