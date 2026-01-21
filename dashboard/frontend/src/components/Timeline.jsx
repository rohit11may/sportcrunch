import { useState } from 'react'
import './Timeline.css'

function Timeline({ segments, onSegmentClick, currentTime, videoDuration }) {
    const [showRejected, setShowRejected] = useState(false)

    // Handle case where data isn't loaded yet
    if (!segments || !videoDuration) {
        return (
            <div className="timeline-container">
                <div className="timeline-loading">
                    <p>Loading timeline...</p>
                </div>
            </div>
        )
    }

    // Filter segments based on showRejected toggle
    const filteredSegments = showRejected
        ? segments // Show all segments
        : segments.filter(seg => seg.type === 'kept') // Only show kept segments

    // Timeline width in pixels
    const TIMELINE_WIDTH = 800

    // Calculate position and width for each segment
    const getSegmentStyle = (segment) => {
        const left = (segment.startTime / videoDuration) * TIMELINE_WIDTH
        const width = ((segment.endTime - segment.startTime) / videoDuration) * TIMELINE_WIDTH
        return { left: `${left}px`, width: `${width}px` }
    }

    // Calculate current position indicator
    const getCurrentTimeStyle = () => {
        const left = (currentTime / videoDuration) * TIMELINE_WIDTH
        return { left: `${left}px` }
    }

    // Handle segment click
    const handleSegmentClick = (segment) => {
        if (onSegmentClick) {
            onSegmentClick(segment.startTime)
        }
    }

    // Handle keyboard navigation
    const handleKeyDown = (e, segment, index) => {
        if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault()
            handleSegmentClick(segment)
        } else if (e.key === 'ArrowRight') {
            e.preventDefault()
            const nextSegment = document.querySelector(
                `.segment-bar[data-index="${index + 1}"]`
            )
            nextSegment?.focus()
        } else if (e.key === 'ArrowLeft') {
            e.preventDefault()
            const prevSegment = document.querySelector(
                `.segment-bar[data-index="${index - 1}"]`
            )
            prevSegment?.focus()
        }
    }

    // Generate time axis tick marks (every 30 seconds)
    const getTimeAxisTicks = () => {
        const ticks = []
        const interval = 30 // seconds
        for (let time = 0; time <= videoDuration; time += interval) {
            const position = (time / videoDuration) * TIMELINE_WIDTH
            ticks.push({ time, position })
        }
        return ticks
    }

    const timeAxisTicks = getTimeAxisTicks()

    // Format time for display (MM:SS)
    const formatTime = (seconds) => {
        const mins = Math.floor(seconds / 60)
        const secs = Math.floor(seconds % 60)
        return `${mins}:${secs.toString().padStart(2, '0')}`
    }

    return (
        <div className="timeline-container">
            <div className="timeline-header">
                <h4>Segment Timeline</h4>
                <button
                    className="timeline-toggle"
                    onClick={() => setShowRejected(!showRejected)}
                    aria-pressed={showRejected}
                >
                    {showRejected ? 'Hide Rejected Segments' : 'Show Rejected Segments'}
                </button>
            </div>

            <div className="timeline-wrapper" style={{ width: `${TIMELINE_WIDTH}px` }}>
                {/* Time axis */}
                <div className="timeline-axis">
                    {timeAxisTicks.map((tick, i) => (
                        <div
                            key={i}
                            className="timeline-tick"
                            style={{ left: `${tick.position}px` }}
                        >
                            <div className="timeline-tick-mark"></div>
                            <div className="timeline-tick-label">{formatTime(tick.time)}</div>
                        </div>
                    ))}
                </div>

                {/* Segments */}
                <div className="timeline-segments">
                    {filteredSegments.map((segment, index) => {
                        const isKept = segment.type === 'kept'
                        return (
                            <div
                                key={index}
                                data-index={index}
                                className={`segment-bar ${isKept ? 'segment-kept' : 'segment-rejected'}`}
                                style={getSegmentStyle(segment)}
                                onClick={() => handleSegmentClick(segment)}
                                onKeyDown={(e) => handleKeyDown(e, segment, index)}
                                tabIndex={0}
                                role="button"
                                aria-label={`${isKept ? 'Kept' : 'Rejected'} segment from ${formatTime(segment.startTime)} to ${formatTime(segment.endTime)}`}
                            >
                                <div className="segment-tooltip">
                                    <div>{isKept ? 'Kept' : 'Rejected'}</div>
                                    <div>{formatTime(segment.startTime)} - {formatTime(segment.endTime)}</div>
                                    <div>Duration: {formatTime(segment.endTime - segment.startTime)}</div>
                                </div>
                            </div>
                        )
                    })}

                    {/* Current time indicator */}
                    {currentTime > 0 && (
                        <div
                            className="timeline-position-indicator"
                            style={getCurrentTimeStyle()}
                            aria-label={`Current position: ${formatTime(currentTime)}`}
                        />
                    )}
                </div>
            </div>

            <div className="timeline-info">
                <span>Total segments: {filteredSegments.length}</span>
                {showRejected && (
                    <>
                        <span className="timeline-divider">|</span>
                        <span className="segment-kept-label">Kept: {segments.filter(s => s.type === 'kept').length}</span>
                        <span className="timeline-divider">|</span>
                        <span className="segment-rejected-label">Rejected: {segments.filter(s => s.type !== 'kept').length}</span>
                    </>
                )}
            </div>
        </div>
    )
}

export default Timeline
