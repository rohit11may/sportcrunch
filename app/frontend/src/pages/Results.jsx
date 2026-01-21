import { useState, useEffect } from 'react'
import { useParams } from 'react-router-dom'
import { getRun } from '../services/api'
import './Results.css'

function Results() {
  const { runId } = useParams()
  const [run, setRun] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

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
        <div className="placeholder-box">
          <p className="placeholder-text">
            VideoPlayer component will be built in Plan 06-03
          </p>
          <p className="placeholder-hint">
            Will display segmented video with playback controls
          </p>
        </div>
      </div>

      <div className="timeline-section">
        <h3>Timeline Visualization</h3>
        <div className="placeholder-box">
          <p className="placeholder-text">
            Timeline component will be built in Plan 06-03
          </p>
          <p className="placeholder-hint">
            Will show horizontal bars for segments with click-to-scrub functionality
          </p>
        </div>
      </div>
    </div>
  )
}

export default Results
