import { useState, useEffect, useCallback } from 'react'
import './SportSelector.css'

const STORAGE_KEY = 'sportcrunch_sport_selection'

function SportSelector({ onChange }) {
  const [sports, setSports] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  // Selection state
  const [selectedSport, setSelectedSport] = useState(null)
  const [selectedMode, setSelectedMode] = useState(null)

  // Load sports from API
  useEffect(() => {
    async function fetchSports() {
      try {
        const response = await fetch('/api/sports')
        if (!response.ok) throw new Error('Failed to fetch sports')

        const data = await response.json()
        setSports(data || [])

        // Restore last selection from localStorage
        const saved = localStorage.getItem(STORAGE_KEY)
        if (saved) {
          const { sportId, modeId } = JSON.parse(saved)
          const sport = data.find(s => s.id === sportId)
          if (sport) {
            setSelectedSport(sport)
            // Find mode if specified, otherwise use null (no mode)
            if (modeId) {
              const mode = sport.modes.find(m => m.id === modeId)
              setSelectedMode(mode || null)
            } else {
              setSelectedMode(null)
            }
          }
        }

        // Default to first sport if nothing saved
        if (!saved && data.length > 0) {
          const first = data[0]
          setSelectedSport(first)
          // Default to no mode (null) - user can select if they want
          setSelectedMode(null)
        }

        setLoading(false)
      } catch (err) {
        console.error('Failed to load sports:', err)
        setError(err.message)
        setLoading(false)
      }
    }

    fetchSports()
  }, [])

  // Notify parent when selection changes
  useEffect(() => {
    if (selectedSport) {
      // Save to localStorage
      localStorage.setItem(STORAGE_KEY, JSON.stringify({
        sportId: selectedSport.id,
        modeId: selectedMode?.id || null
      }))

      // Notify parent
      onChange({
        sport: selectedSport.id,
        sportMode: selectedMode?.id || null,
        sportDisplayName: selectedSport.displayName,
        modeDisplayName: selectedMode?.displayName || 'No Mode'
      })
    }
  }, [selectedSport, selectedMode, onChange])

  const handleSportChange = useCallback((e) => {
    const sportId = e.target.value
    const sport = sports.find(s => s.id === sportId)
    if (sport) {
      setSelectedSport(sport)
      // Reset mode to null when sport changes
      setSelectedMode(null)
    }
  }, [sports])

  const handleModeChange = useCallback((e) => {
    const modeId = e.target.value
    if (modeId === '') {
      setSelectedMode(null)
    } else {
      const mode = selectedSport?.modes.find(m => m.id === modeId)
      setSelectedMode(mode || null)
    }
  }, [selectedSport])

  if (loading) {
    return (
      <div className="sport-selector">
        <h3>Sport & Mode</h3>
        <div className="sport-loading">Loading sports...</div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="sport-selector">
        <h3>Sport & Mode</h3>
        <div className="sport-error">Error: {error}</div>
      </div>
    )
  }

  if (sports.length === 0) {
    return (
      <div className="sport-selector">
        <h3>Sport & Mode</h3>
        <div className="sport-empty">
          No sports available. Please ensure SportCrunchRunner is running.
        </div>
      </div>
    )
  }

  return (
    <div className="sport-selector">
      <h3>Sport & Mode</h3>

      {/* Sport dropdown */}
      <div className="sport-field">
        <label htmlFor="sport-select">Sport</label>
        <select
          id="sport-select"
          value={selectedSport?.id || ''}
          onChange={handleSportChange}
        >
          {sports.map(sport => (
            <option key={sport.id} value={sport.id}>
              {sport.displayName}
            </option>
          ))}
        </select>
      </div>

      {/* Sport description */}
      {selectedSport && (
        <div className="sport-description">
          {selectedSport.description}
        </div>
      )}

      {/* Mode dropdown (only if sport has modes) */}
      {selectedSport && selectedSport.modes && selectedSport.modes.length > 0 && (
        <div className="sport-field">
          <label htmlFor="mode-select">Mode</label>
          <select
            id="mode-select"
            value={selectedMode?.id || ''}
            onChange={handleModeChange}
          >
            <option value="">No mode</option>
            {selectedSport.modes.map(mode => (
              <option key={mode.id} value={mode.id}>
                {mode.displayName}
              </option>
            ))}
          </select>
        </div>
      )}

      {/* Mode description */}
      {selectedMode && (
        <div className="mode-description">
          {selectedMode.description}
        </div>
      )}

      {/* No mode indicator */}
      {selectedSport && (!selectedSport.modes || selectedSport.modes.length === 0) && (
        <div className="sport-no-modes">
          This sport has no modes
        </div>
      )}
    </div>
  )
}

export default SportSelector
