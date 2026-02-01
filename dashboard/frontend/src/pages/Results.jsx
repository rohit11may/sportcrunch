import { useState, useEffect, useRef } from 'react'
import { useParams } from 'react-router-dom'
import { getRun } from '../services/api'
import Timeline from '../components/Timeline'
import VideoPlayer from '../components/VideoPlayer'
import ObservationCharts from '../components/ObservationCharts'
import EventLedger from '../components/EventLedger'
import './Results.css'

const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost:3000'
const DEVICE_BASE = import.meta.env.VITE_DEVICE_BASE || 'http://localhost:8080'

function Results() {
    const { runId } = useParams()
    const [run, setRun] = useState(null)
    const [loading, setLoading] = useState(true)
    const [error, setError] = useState(null)
    const [currentTime, setCurrentTime] = useState(0)
    const [videoDuration, setVideoDuration] = useState(0)
    const originalVideoRef = useRef(null)
    const highlightVideoRef = useRef(null)
    
    // Observations State
    const [observations, setObservations] = useState(null)
    const [syncing, setSyncing] = useState(false)
    const [syncStatus, setSyncStatus] = useState('')

    useEffect(() => {
        loadRun()
        if (runId) {
            fetchObservations()
        }
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

    const fetchObservations = async () => {
        try {
            const response = await fetch(`${API_BASE}/api/runs/${runId}/observations`)
            if (response.ok) {
                const data = await response.json()
                setObservations(data)
            } else {
                setObservations(null)
            }
        } catch (err) {
            console.warn('Observations not available:', err.message)
        }
    }

    const syncObservations = async () => {
        setSyncing(true)
        setSyncStatus('Fetching...')

        try {
            const obsResponse = await fetch(`${DEVICE_BASE}/runs/${runId}/observations`)
            if (!obsResponse.ok) throw new Error('Observations not found on device')
            const observationsData = await obsResponse.json()

            await fetch(`${API_BASE}/api/sync/observations`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ runId, observations: observationsData })
            })

            setObservations(observationsData)
            setSyncStatus('✓')
            setTimeout(() => setSyncStatus(''), 2000)
        } catch (err) {
            setSyncStatus('❌')
            console.error(err)
        } finally {
            setSyncing(false)
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
        if (run.highlightPath) return run.highlightPath
        if (run.artifactPaths?.highlightVideo) return run.artifactPaths.highlightVideo
        return null
    }

    const originalSource = getOriginalVideoSource()
    const highlightSource = getHighlightVideoSource()

    return (
        <div className="results-page">
            <div className="layout-grid">
                {/* LEFT COLUMN: Media (25%) */}
                <div className="left-column">
                    <div className="panel video-panel">
                        <div className="panel-header">Original Video</div>
                        <div className="video-wrapper">
                            {originalSource ? (
                                <VideoPlayer
                                    videoRef={originalVideoRef}
                                    videoSrc={originalSource}
                                    onTimeUpdate={handleTimeUpdate}
                                />
                            ) : (
                                <div className="placeholder-box">No Video</div>
                            )}
                        </div>
                    </div>

                    <div className="panel video-panel">
                        <div className="panel-header">Highlight Reel</div>
                        <div className="video-wrapper">
                            {highlightSource ? (
                                <VideoPlayer
                                    videoRef={highlightVideoRef}
                                    videoSrc={highlightSource}
                                />
                            ) : (
                                <div className="placeholder-box">No Highlight</div>
                            )}
                        </div>
                    </div>
                    
                    <div className="panel info-panel">
                        <div className="info-row">
                            <span className={`status-badge ${run.status}`}>{run.status}</span>
                            <span className="info-id">#{run.id.slice(0,6)}</span>
                            <span className="info-meta">{run.method}</span>
                        </div>
                        <button className="sync-btn" onClick={syncObservations} disabled={syncing}>
                            {syncing ? 'Syncing...' : 'Sync Device Data'} {syncStatus}
                        </button>
                    </div>
                </div>

                {/* RIGHT COLUMN: Data (75%) */}
                <div className="right-column">
                    <div className="panel charts-panel">
                        <ObservationCharts 
                            observations={observations} 
                            onTimeClick={handleSegmentClick} 
                        />
                    </div>
                    
                    <div className="panel ledger-panel">
                        <EventLedger 
                            observations={observations} 
                            runId={runId} 
                            onTimeClick={handleSegmentClick} 
                        />
                    </div>

                    <div className="panel timeline-panel">
                        <Timeline
                            segments={run.segments || []}
                            onSegmentClick={handleSegmentClick}
                            currentTime={currentTime}
                            videoDuration={videoDuration}
                        />
                    </div>
                </div>
            </div>
        </div>
    )
}

export default Results
