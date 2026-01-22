import { useState, useEffect } from 'react'
import './VideoPlayer.css'

function VideoPlayer({ videoSrc, onTimeUpdate, videoRef }) {
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState(null)
  const [duration, setDuration] = useState(0)

  // Handle video load metadata
  const handleLoadedMetadata = (e) => {
    setIsLoading(false)
    setDuration(e.target.duration)
  }

  // Handle video time update
  const handleTimeUpdate = (e) => {
    if (onTimeUpdate) {
      onTimeUpdate(e.target.currentTime)
    }
  }

  // Handle video load error
  const handleError = (e) => {
    setIsLoading(false)
    setError('Failed to load video. Please check the file path.')
    console.error('Video load error:', e)
  }

  // Handle video can play (ready to play)
  const handleCanPlay = () => {
    setIsLoading(false)
    setError(null)
  }

  // Handle video waiting (buffering)
  const handleWaiting = () => {
    setIsLoading(true)
  }

  // Handle video playing
  const handlePlaying = () => {
    setIsLoading(false)
  }

  // Transform video source path for frontend access
  const getVideoUrl = () => {
    if (!videoSrc) return null

    // If it's already a full URL, use as-is
    if (videoSrc.startsWith('http://') ||
      videoSrc.startsWith('https://')) {
      return videoSrc
    }

    // Handle relative paths that go through Vite proxy to backend
    if (videoSrc.startsWith('/api/') ||
      videoSrc.startsWith('/videos/') ||
      videoSrc.startsWith('/highlights/') ||
      videoSrc.startsWith('/uploads/') ||
      videoSrc.startsWith('/artifacts/')) {
      return videoSrc
    }

    // If it's an absolute filesystem path, extract filename and serve appropriately
    if (videoSrc.startsWith('/')) {
      const filename = videoSrc.split('/').pop()
      // Check if it's a highlight file
      if (filename.includes('-highlight.mp4')) {
        return `/highlights/${filename}`
      }
      return `/videos/${filename}`
    }

    // Otherwise, assume it's a relative path
    return videoSrc
  }

  const videoUrl = getVideoUrl()

  if (!videoUrl) {
    return (
      <div className="video-player-container">
        <div className="video-player-error">
          <p>No video source provided</p>
        </div>
      </div>
    )
  }

  return (
    <div className="video-player-container">
      {isLoading && !error && (
        <div className="video-player-loading">
          <div className="spinner"></div>
          <p>Loading video...</p>
        </div>
      )}

      {error && (
        <div className="video-player-error">
          <p>{error}</p>
          <p className="video-player-error-hint">Video source: {videoSrc}</p>
        </div>
      )}

      <video
        ref={videoRef}
        className="video-player"
        controls
        onLoadedMetadata={handleLoadedMetadata}
        onTimeUpdate={handleTimeUpdate}
        onError={handleError}
        onCanPlay={handleCanPlay}
        onWaiting={handleWaiting}
        onPlaying={handlePlaying}
        preload="metadata"
      >
        <source src={videoUrl} type="video/mp4" />
        <source src={videoUrl} type="video/quicktime" />
        Your browser does not support the video tag.
      </video>

      {duration > 0 && (
        <div className="video-player-info">
          <span>Duration: {formatTime(duration)}</span>
        </div>
      )}
    </div>
  )
}

// Format time for display (HH:MM:SS or MM:SS)
function formatTime(seconds) {
  const hours = Math.floor(seconds / 3600)
  const mins = Math.floor((seconds % 3600) / 60)
  const secs = Math.floor(seconds % 60)

  if (hours > 0) {
    return `${hours}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }
  return `${mins}:${secs.toString().padStart(2, '0')}`
}

export default VideoPlayer
