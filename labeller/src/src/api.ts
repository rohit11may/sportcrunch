import type { AnnotationData, VideoSession } from './types';

const API_BASE = 'http://localhost:3001/api';

export const api = {
    getSessions: async (): Promise<VideoSession[]> => {
        const res = await fetch(`${API_BASE}/session`);
        return res.json();
    },

    saveAnnotation: async (data: AnnotationData): Promise<void> => {
        await fetch(`${API_BASE}/save`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
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

    saveSplit: async (videoFilename: string, parts: any[]): Promise<void> => {
        await fetch(`${API_BASE}/split`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ videoFilename, parts }),
        });
    },

    deleteSession: async (id: string): Promise<void> => {
        await fetch(`${API_BASE}/session/${id}`, {
            method: 'DELETE',
        });
    }
};

export const getVideoUrl = (filename: string) => `http://localhost:3001/videos/${filename}`;
