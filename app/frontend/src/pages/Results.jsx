import { useState, useEffect, useRef } from 'react'
import { useParams } from 'react-router-dom'
import { getRun } from '../services/api'
import Timeline from '../components/Timeline'
import VideoPlayer from '../components/VideoPlayer'
import './Results.css'

function Results() {
  const { runId } = useParams()
  const [run, setRun] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [currentTime, setCurrentTime] = useState(0)
  const [videoDuration, setVideoDuration] = useState(0)
  const videoRef = useRef(null)

  useEffect(() => {
    loadRun()
  }, [runId])

  async function loadRun() {
    try {
      setLoading(true)
      setError(null)
      const runData = await getRun(runId)
      setRun(runData)
    } catch (err) {
      setError(err.message || 'Failed to load run')
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="results-page">
        <div className="loading-spinner">
          <div className="spinner"></div>
          <p>Loading run details...</p>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="results-page">
        <div className="error-box">
          <h3>Error Loading Run</h3>
          <p>{error}</p>
        </div>
      </div>
    )
  }

  if (!run) {
    return (
      <div className="results-page">
        <div className="error-box">
          <h3>Run Not Found</h3>
          <p>The run with ID {runId} could not be found.</p>
        </div>
      </div>
    )
  }

  const segmentCount = run.segments?.length || 0

  // Handle segment click - seek video to timestamp
  const handleSegmentClick = (timestamp) => {
    if (videoRef.current) {
      videoRef.current.currentTime = timestamp
    }
  }

  // Handle video time update - update timeline position
  const handleTimeUpdate = (time) => {
    setCurrentTime(time)
  }

  // Handle video metadata loaded - get duration
  useEffect(() => {
    if (videoRef.current) {
      const video = videoRef.current
      const handleLoadedMetadata = () => {
        setVideoDuration(video.duration)
      }
      video.addEventListener('loadedmetadata', handleLoadedMetadata)
      return () => {
        video.removeEventListener('loadedmetadata', handleLoadedMetadata)
      }
    }
  }, [run])

  // Determine video source
  const getVideoSource = () => {
    if (!run) return null

    // If highlightVideo artifact exists, use that (segmented output)
    if (run.artifactPaths?.highlightVideo) {
      return run.artifactPaths.highlightVideo
    }

    // Otherwise, use original video path
    return run.videoPath
  }

  const videoSource = getVideoSource()

  return (
    <div className="results-page">
      <h2>Run Results</h2>

      <div className="run-info">
        <h3>Run Information</h3>
        <div className="info-grid">
          <div className="info-item">
            <span className="info-label">Run ID:</span>
            <span className="info-value">{run.id}</span>
          </div>
          <div className="info-item">
            <span className="info-label">Video:</span>
            <span className="info-value">{run.videoPath.split('/').pop()}</span>
          </div>
          <div className="info-item">
            <span className="info-label">Method:</span>
            <span className="info-value">{run.method}</span>
          </div>
          <div className="info-item">
            <span className="info-label">Sport:</span>
            <span className="info-value">{run.sport} ({run.sportMode})</span>
          </div>
          <div className="info-item">
            <span className="info-label">Status:</span>
            <span className={`info-value status-${run.status}`}>
              {run.status}
            </span>
          </div>
          <div className="info-item">
            <span className="info-label">Segments:</span>
            <span className="info-value">{segmentCount}</span>
          </div>
          {run.createdAt && (
            <div className="info-item">
              <span className="info-label">Created:</span>
              <span className="info-value">
                {new Date(run.createdAt).toLocaleString()}
              </span>
            </div>
          )}
          {run.completedAt && (
            <div className="info-item">
              <span className="info-label">Completed:</span>
              <span className="info-value">
                {new Date(run.completedAt).toLocaleString()}
              </span>
            </div>
          )}
        </div>
      </div>

      <div className="video-section">
        <h3>Video Player</h3>
        {videoSource ? (
          <VideoPlayer
            videoRef={videoRef}
            videoSrc={videoSource}
            onTimeUpdate={handleTimeUpdate}
          />
        ) : (
          <div className="placeholder-box">
            <p className="placeholder-text">No video available</p>
            <p className="placeholder-hint">
              Video source not found in run data
            </p>
          </div>
        )}
      </div>

      <div className="timeline-section">
        <h3>Timeline Visualization</h3>
        {run.segments && run.segments.length > 0 ? (
          <Timeline
            segments={run.segments}
            onSegmentClick={handleSegmentClick}
            currentTime={currentTime}
            videoDuration={videoDuration}
          />
        ) : (
          <div className="placeholder-box">
            <p className="placeholder-text">No segments available</p>
            <p className="placeholder-hint">
              Segments will appear after video processing completes
            </p>
          </div>
        )}
      </div>
    </div>
  )
}

export default Results
