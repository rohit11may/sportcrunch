import { useState } from 'react';
import './EventLedger.css';

const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost:3000';

function EventLedger({ observations, runId, onTimeClick }) {
  const [selectedEvent, setSelectedEvent] = useState(null);

  if (!observations || !observations.events) {
    return null;
  }

  const { events } = observations;

  // Sort events by timestamp
  const sortedEvents = [...events].sort((a, b) => a.timestamp - b.timestamp);

  // Format time (MM:SS.mmm)
  const formatTime = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    const ms = Math.floor((seconds % 1) * 1000);
    return `${mins}:${secs.toString().padStart(2, '0')}.${ms.toString().padStart(3, '0')}`;
  };

  // Get event icon based on name
  const getEventIcon = (name) => {
    switch (name) {
      case 'audio_peak':
        return '🎵';
      case 'validation_decision':
        return '👁️';
      default:
        return '📌';
    }
  };

  // Get artifact URL if event has artifactId
  const getArtifactUrl = (artifactId) => {
    if (!artifactId) return null;
    return `${API_BASE}/cache/runs/${runId}/artifacts/${artifactId}.jpg`;
  };

  const handleEventClick = (event) => {
    setSelectedEvent(event);
    if (onTimeClick) {
      onTimeClick(event.timestamp);
    }
  };

  return (
    <div className="event-ledger">
      <h3>Event Ledger</h3>
      <div className="event-table-container">
        <table className="event-table">
          <thead>
            <tr>
              <th>Type</th>
              <th>Time</th>
              <th>Metadata</th>
              <th>Artifact</th>
            </tr>
          </thead>
          <tbody>
            {sortedEvents.map((event, idx) => (
              <tr
                key={event.id || idx}
                className={selectedEvent === event ? 'selected' : ''}
                onClick={() => handleEventClick(event)}
              >
                <td className="event-type">
                  <span className="event-icon">{getEventIcon(event.name)}</span>
                  <span className="event-name">{event.name}</span>
                </td>
                <td className="event-time">
                  <button
                    className="time-button"
                    onClick={(e) => {
                      e.stopPropagation();
                      if (onTimeClick) onTimeClick(event.timestamp);
                    }}
                  >
                    {formatTime(event.timestamp)}
                  </button>
                </td>
                <td className="event-metadata">
                  {Object.entries(event.metadata || {}).map(([key, value]) => (
                    <div key={key} className="metadata-entry">
                      <span className="metadata-key">{key}:</span>
                      <span className="metadata-value">{value}</span>
                    </div>
                  ))}
                </td>
                <td className="event-artifact">
                  {event.artifactId && (
                    <a
                      href={getArtifactUrl(event.artifactId)}
                      target="_blank"
                      rel="noopener noreferrer"
                      onClick={(e) => e.stopPropagation()}
                      className="artifact-link"
                    >
                      View 🖼️
                    </a>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="ledger-hint">
        Click on any row or time to seek video to that event. Total events: {events.length}
      </p>
    </div>
  );
}

export default EventLedger;
