import { useState, useEffect, useRef } from 'react'
import { useParams, Link } from 'react-router-dom'
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
    const [showInfo, setShowInfo] = useState(false)
    const [showJson, setShowJson] = useState(false)
    const originalVideoRef = useRef(null)
    const highlightVideoRef = useRef(null)

    useEffect(() => {
        loadRun()
    }, [runId])

    // Handle video metadata loaded - get duration from ORIGINAL video
    useEffect(() => {
        if (originalVideoRef.current) {
            const video = originalVideoRef.current
            const handleLoadedMetadata = () => {
                setVideoDuration(video.duration)
            }
            video.addEventListener('loadedmetadata', handleLoadedMetadata)
            return () => {
                video.removeEventListener('loadedmetadata', handleLoadedMetadata)
            }
        }
    }, [run])

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

    // Handle segment click - seek ORIGINAL video to timestamp
    const handleSegmentClick = (timestamp) => {
        if (originalVideoRef.current) {
            originalVideoRef.current.currentTime = timestamp
            originalVideoRef.current.play()
        }
    }

    // Handle video time update - update timeline position from ORIGINAL video
    const handleTimeUpdate = (time) => {
        setCurrentTime(time)
    }

    // Determine ORIGINAL video source
    const getOriginalVideoSource = () => {
        if (!run) return null
        return run.videoPath
    }

    // Determine HIGHLIGHT video source
    const getHighlightVideoSource = () => {
        if (!run) return null

        // Use highlightPath from run data (now a full URL from backend)
        if (run.highlightPath) {
            return run.highlightPath
        }

        // Fallback: If highlightVideo artifact exists (legacy), use that
        if (run.artifactPaths?.highlightVideo) {
            return run.artifactPaths.highlightVideo
        }

        return null
    }

    const originalSource = getOriginalVideoSource()
    const highlightSource = getHighlightVideoSource()

    // Format the run ID for display (truncated)
    const formatRunId = (id) => {
        if (id && id.length > 8) {
            return `${id.substring(0, 8)}...`
        }
        return id
    }

    return (
        <div className="results-page">
            {/* Split View: Original (Left) vs Highlight (Right) */}
            <div className="video-main">
                <div className="split-view-container">
                    {/* LEFT: Original Video + Timeline Control */}
                    <div className="video-column original-column">
                        <div className="column-header">Original</div>
                        <div className="video-wrapper">
                            {originalSource ? (
                                <VideoPlayer
                                    videoRef={originalVideoRef}
                                    videoSrc={originalSource}
                                    onTimeUpdate={handleTimeUpdate}
                                />
                            ) : (
                                <div className="placeholder-box">
                                    <p>No Original Video</p>
                                </div>
                            )}
                        </div>
                    </div>

                    {/* RIGHT: Highlight Video */}
                    <div className="video-column highlight-column">
                        <div className="column-header">Highlight</div>
                        <div className="video-wrapper">
                            {highlightSource ? (
                                <VideoPlayer
                                    videoRef={highlightVideoRef}
                                    videoSrc={highlightSource}
                                // No onTimeUpdate for highlight - independent playback
                                />
                            ) : (
                                <div className="placeholder-box">
                                    <p>No Highlight Generated</p>
                                    <p className="placeholder-hint">Process segments to generate highlight</p>
                                </div>
                            )}
                        </div>
                    </div>
                </div>

                {/* Timeline below video - Controls ORIGINAL */}
                <div className="timeline-container">
                    <Timeline
                        segments={run.segments || []}
                        onSegmentClick={handleSegmentClick}
                        currentTime={currentTime}
                        videoDuration={videoDuration}
                    />
                </div>
            </div>

            {/* Compact info bar at bottom */}
            <div className="info-bar">
                <div className="info-bar-main">
                    <div className="info-chips">
                        <span className={`status-chip status-${run.status}`}>
                            {run.status}
                        </span>
                        <span className="info-chip">
                            <span className="chip-icon">🎾</span>
                            {run.sport}
                        </span>
                        <span className="info-chip">
                            <span className="chip-icon">⚙️</span>
                            {run.method}
                        </span>
                        <span className="info-chip">
                            <span className="chip-icon">📊</span>
                            {segmentCount} segments
                        </span>
                    </div>
                    <div className="info-actions">
                        <span className="video-name" title={run.videoPath}>
                            {run.videoPath.split('/').pop()}
                        </span>
                        <Link
                            to={`/lab/${runId}`}
                            className="info-toggle lab-link"
                        >
                            Lab 🔬
                        </Link>
                        <button
                            className="info-toggle"
                            onClick={() => setShowJson(!showJson)}
                        >
                            {showJson ? 'Hide JSON' : 'Show JSON'}
                        </button>
                        <button
                            className="info-toggle"
                            onClick={() => setShowInfo(!showInfo)}
                        >
                            {showInfo ? 'Hide Details' : 'Show Details'}
                        </button>
                    </div>
                </div>

                {/* Raw JSON Display */}
                {showJson && (
                    <div className="json-details">
                        <pre>{JSON.stringify(run, null, 2)}</pre>
                    </div>
                )}

                {/* Expandable details panel */}
                {showInfo && (
                    <div className="info-details">
                        <div className="detail-row">
                            <span className="detail-label">Run ID</span>
                            <span className="detail-value mono">{run.id}</span>
                        </div>
                        <div className="detail-row">
                            <span className="detail-label">Mode</span>
                            <span className="detail-value">{run.sportMode}</span>
                        </div>
                        {run.createdAt && (
                            <div className="detail-row">
                                <span className="detail-label">Created</span>
                                <span className="detail-value">
                                    {new Date(run.createdAt).toLocaleString()}
                                </span>
                            </div>
                        )}
                        {run.completedAt && (
                            <div className="detail-row">
                                <span className="detail-label">Completed</span>
                                <span className="detail-value">
                                    {new Date(run.completedAt).toLocaleString()}
                                </span>
                            </div>
                        )}
                    </div>
                )}
            </div>
        </div>
    )
}

export default Results
