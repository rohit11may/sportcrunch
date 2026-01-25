import { useState, useEffect } from 'react'
import { NavLink } from 'react-router-dom'
import { fetchRuns } from '../services/api'
import './RunHistory.css'

function RunHistory() {
    const [runs, setRuns] = useState([])
    const [loading, setLoading] = useState(true)
    const [error, setError] = useState(null)

    useEffect(() => {
        loadRuns()
        const interval = setInterval(loadRuns, 10000)
        return () => clearInterval(interval)
    }, [])

    async function loadRuns() {
        try {
            const data = await fetchRuns()

            // Handle different response formats
            let runsArray = []
            if (Array.isArray(data)) {
                runsArray = data
            } else if (data && typeof data === 'object' && data.runs && Array.isArray(data.runs)) {
                runsArray = data.runs
            } else if (data && typeof data === 'object') {
                // If it's an object with run IDs as keys, convert to array
                runsArray = Object.entries(data).map(([id, runData]) => ({
                    id,
                    ...(typeof runData === 'object' ? runData : {})
                }))
            }

            const sortedRuns = runsArray
                .filter(run => run && run.id)
                .sort((a, b) => {
                    const dateA = new Date(a.timestamp || a.createdAt || a.created || 0)
                    const dateB = new Date(b.timestamp || b.createdAt || b.created || 0)
                    return dateB - dateA
                })
                .slice(0, 15)

            // Debug: log first run to see structure
            if (sortedRuns.length > 0) {
                console.log('Sample run data:', sortedRuns[0])
            }

            setRuns(sortedRuns)
            setLoading(false)
        } catch (err) {
            console.error('Failed to load runs:', err)
            setError(err.message)
            setLoading(false)
        }
    }

    function formatTimeSince(timestamp) {
        if (!timestamp) return null

        try {
            const date = new Date(timestamp)
            if (isNaN(date.getTime())) return null

            const now = new Date()
            const diffMs = now - date
            const diffMins = Math.floor(diffMs / 60000)
            const diffHours = Math.floor(diffMs / 3600000)

            if (diffMins < 1) return 'now'
            if (diffMins < 60) return `${diffMins}m`

            // Format as hours and minutes (e.g., 4h20m)
            const hours = Math.floor(diffMins / 60)
            const mins = diffMins % 60
            if (hours < 24) {
                return mins > 0 ? `${hours}h${mins}m` : `${hours}h`
            }

            // For longer times, just show days
            const days = Math.floor(diffHours / 24)
            return `${days}d`
        } catch (err) {
            return null
        }
    }

    function getVideoName(videoPath) {
        if (!videoPath) return 'UNKNOWN'
        const parts = videoPath.split('/')
        const filename = parts[parts.length - 1]
        return filename.replace(/\.(mp4|mov|avi)$/i, '').toUpperCase()
    }

    function getStatusIndicator(status) {
        const indicators = {
            completed: '●',
            running: '◐',
            queued: '○',
            failed: '✕'
        }
        return indicators[status] || '○'
    }

    if (loading) {
        return (
            <div className="run-history">
                <div className="run-history-header">
                    <span className="archive-label">Previous Runs</span>
                </div>
            </div>
        )
    }

    if (error) {
        return (
            <div className="run-history">
                <div className="run-history-header">
                    <span className="archive-label">Previous Runs</span>
                </div>
                <div className="archive-error">
                    ERROR: {error}
                </div>
            </div>
        )
    }

    return (
        <div className="run-history">
            <div className="run-history-header">
                <span className="archive-label">Previous Runs</span>
            </div>

            <div className="run-list">
                {runs.length === 0 ? (
                    <div className="empty-archive">
                        NO RUNS FOUND
                    </div>
                ) : (
                    runs.map((run, index) => {
                        if (!run || !run.id) return null

                        const segmentCount = run.segments?.length || 0
                        // Try multiple timestamp fields
                        const timeSince = formatTimeSince(run.timestamp || run.createdAt || run.created || run.startTime)
                        const method = run.method || 'unknown'
                        const config = run.config || 'default'
                        const configName = typeof config === 'string' ? config : config.name || Object.keys(config)[0] || 'default'

                        return (
                            <NavLink
                                key={run.id}
                                to={`/results/${run.id}`}
                                className={({ isActive }) => `run-item ${isActive ? 'active' : ''}`}
                            >
                                <div className="run-index">
                                    #{String(index + 1).padStart(2, '0')}
                                </div>
                                <div className="run-details">
                                    <div className="run-header">
                                        <div className="run-video-name">
                                            {getVideoName(run.videoPath)}
                                        </div>
                                        {timeSince && (
                                            <div className="run-time-since">
                                                {timeSince}
                                            </div>
                                        )}
                                    </div>
                                    <div className="run-method-info">
                                        <span className="run-method">{method}</span>
                                        <span className="run-config">{configName}</span>
                                        {segmentCount > 0 && (
                                            <span className="run-segments">
                                                {segmentCount} seg{segmentCount !== 1 ? 's' : ''}
                                            </span>
                                        )}
                                    </div>
                                </div>
                            </NavLink>
                        )
                    })
                )}
            </div>
        </div>
    )
}

export default RunHistory
