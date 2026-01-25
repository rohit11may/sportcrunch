import { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import ObservationCharts from '../components/ObservationCharts';
import EventLedger from '../components/EventLedger';
import './Lab.css';

const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost:3000';
const DEVICE_BASE = import.meta.env.VITE_DEVICE_BASE || 'http://localhost:8080';

function Lab() {
  const { runId } = useParams();
  const [observations, setObservations] = useState(null);
  const [run, setRun] = useState(null);
  const [loading, setLoading] = useState(true);
  const [syncing, setSyncing] = useState(false);
  const [error, setError] = useState(null);
  const [syncStatus, setSyncStatus] = useState('');

  // Fetch run metadata
  useEffect(() => {
    fetchRun();
  }, [runId]);

  // Fetch observations (from backend cache)
  useEffect(() => {
    if (run) {
      fetchObservations();
    }
  }, [run]);

  const fetchRun = async () => {
    try {
      // Fetch from iOS device first
      const response = await fetch(`${DEVICE_BASE}/runs/${runId}`);
      if (!response.ok) throw new Error('Run not found');
      const data = await response.json();
      setRun(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const fetchObservations = async () => {
    try {
      const response = await fetch(`${API_BASE}/api/runs/${runId}/observations`);
      if (response.ok) {
        const data = await response.json();
        setObservations(data);
      } else {
        // Observations not synced yet
        setObservations(null);
      }
    } catch (err) {
      console.warn('Observations not available:', err.message);
    }
  };

  const syncObservations = async () => {
    setSyncing(true);
    setSyncStatus('Fetching observations from device...');

    try {
      // 1. Fetch observations.json from device
      const devicePath = `/var/mobile/Containers/Data/Application/SportCrunchRuns/${runId}/observations.json`;
      const obsResponse = await fetch(`${DEVICE_BASE}/files?path=${encodeURIComponent(devicePath)}`);

      if (!obsResponse.ok) {
        throw new Error('Observations file not found on device');
      }

      const observationsData = await obsResponse.json();

      // 2. Send to backend for caching
      setSyncStatus('Syncing to backend...');
      const syncResponse = await fetch(`${API_BASE}/api/sync/observations`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          runId,
          observations: observationsData
        })
      });

      if (!syncResponse.ok) {
        throw new Error('Failed to sync observations to backend');
      }

      // 3. Update local state
      setObservations(observationsData);
      setSyncStatus('✓ Sync complete');

      // Clear success message after 2 seconds
      setTimeout(() => setSyncStatus(''), 2000);
    } catch (err) {
      setSyncStatus(`❌ Sync failed: ${err.message}`);
    } finally {
      setSyncing(false);
    }
  };

  if (loading) {
    return <div className="lab-container"><div className="loading">Loading run...</div></div>;
  }

  if (error) {
    return <div className="lab-container"><div className="error">Error: {error}</div></div>;
  }

  return (
    <div className="lab-container">
      {/* Header */}
      <div className="lab-header">
        <h1>🧪 Observation Lab</h1>
        <div className="run-info">
          <div className="run-metadata">
            <span className="label">Run ID:</span>
            <span className="value">{runId?.slice(0, 8)}</span>
          </div>
          <div className="run-metadata">
            <span className="label">Method:</span>
            <span className="value">{run?.method}/{run?.config}</span>
          </div>
          <div className="run-metadata">
            <span className="label">Status:</span>
            <span className={`status ${run?.status}`}>{run?.status}</span>
          </div>
        </div>
      </div>

      {/* Sync Controls */}
      <div className="sync-controls">
        <button
          className="sync-button"
          onClick={syncObservations}
          disabled={syncing}
        >
          {syncing ? 'Syncing...' : '🔄 Sync from Device'}
        </button>
        {syncStatus && <span className="sync-status">{syncStatus}</span>}
      </div>

      {/* Content */}
      {!observations ? (
        <div className="placeholder">
          <p>No observations available.</p>
          <p>Click "Sync from Device" to fetch observation data.</p>
        </div>
      ) : (
        <div className="lab-content">
          {/* Note: Video seeking functionality placeholder */}
          {/* In a full implementation, this would control a video player */}
          <div className="video-note">
            <p>📹 Video seeking: Click on charts or event times to seek (video player not implemented in this demo)</p>
          </div>

          {/* Charts */}
          <ObservationCharts
            observations={observations}
            onTimeClick={(time) => {
              console.log(`Video seek to ${time}s requested`);
              // TODO: Implement video player integration
              alert(`Video seek to ${time.toFixed(2)}s`);
            }}
          />

          {/* Event Ledger */}
          <EventLedger
            observations={observations}
            runId={runId}
            onTimeClick={(time) => {
              console.log(`Video seek to ${time}s requested`);
              // TODO: Implement video player integration
              alert(`Video seek to ${time.toFixed(2)}s`);
            }}
          />
        </div>
      )}
    </div>
  );
}

export default Lab;
