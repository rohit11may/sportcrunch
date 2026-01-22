import { useState, useEffect, useCallback } from 'react'
import './MethodSelector.css'

const STORAGE_KEY = 'sportcrunch_method_selection'

function MethodSelector({ onChange }) {
  const [methods, setMethods] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  // Selection state
  const [selectedMethod, setSelectedMethod] = useState(null)
  const [selectedConfig, setSelectedConfig] = useState(null)

  // Load methods from API
  useEffect(() => {
    async function fetchMethods() {
      try {
        const response = await fetch('/api/methods')
        if (!response.ok) throw new Error('Failed to fetch methods')

        const data = await response.json()
        setMethods(data.methods || [])

        // Restore last selection from localStorage
        const saved = localStorage.getItem(STORAGE_KEY)
        if (saved) {
          const { methodId, configName } = JSON.parse(saved)
          const method = data.methods.find(m => m.id === methodId)
          if (method) {
            setSelectedMethod(method)
            setSelectedConfig(configName || method.defaultConfig)
          }
        }

        // Default to first method if nothing saved
        if (!saved && data.methods.length > 0) {
          const first = data.methods[0]
          setSelectedMethod(first)
          setSelectedConfig(first.defaultConfig)
        }

        setLoading(false)
      } catch (err) {
        console.error('Failed to load methods:', err)
        setError(err.message)
        setLoading(false)
      }
    }

    fetchMethods()
  }, [])

  // Notify parent when selection changes
  useEffect(() => {
    if (selectedMethod && selectedConfig) {
      // Save to localStorage
      localStorage.setItem(STORAGE_KEY, JSON.stringify({
        methodId: selectedMethod.id,
        configName: selectedConfig
      }))

      // Notify parent
      onChange({
        family: selectedMethod.family,
        version: selectedMethod.version,
        config: selectedConfig,
        name: selectedMethod.name
      })
    }
  }, [selectedMethod, selectedConfig, onChange])

  const handleMethodChange = useCallback((e) => {
    const methodId = e.target.value
    const method = methods.find(m => m.id === methodId)
    if (method) {
      setSelectedMethod(method)
      setSelectedConfig(method.defaultConfig)
    }
  }, [methods])

  const handleConfigChange = useCallback((e) => {
    setSelectedConfig(e.target.value)
  }, [])

  if (loading) {
    return (
      <div className="method-selector">
        <h3>Detection Method</h3>
        <div className="method-loading">Loading methods...</div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="method-selector">
        <h3>Detection Method</h3>
        <div className="method-error">Error: {error}</div>
      </div>
    )
  }

  if (methods.length === 0) {
    return (
      <div className="method-selector">
        <h3>Detection Method</h3>
        <div className="method-empty">
          No methods available. Run validation script to generate _index.json.
        </div>
      </div>
    )
  }

  return (
    <div className="method-selector">
      <h3>Detection Method</h3>

      {/* Method dropdown */}
      <div className="method-field">
        <label htmlFor="method-select">Method</label>
        <select
          id="method-select"
          value={selectedMethod?.id || ''}
          onChange={handleMethodChange}
        >
          {methods.map(method => (
            <option key={method.id} value={method.id}>
              {method.name}
            </option>
          ))}
        </select>
      </div>

      {/* Method description */}
      {selectedMethod && (
        <div className="method-description">
          {selectedMethod.description}
        </div>
      )}

      {/* Config dropdown (only if multiple configs) */}
      {selectedMethod && selectedMethod.configs.length > 1 && (
        <div className="method-field">
          <label htmlFor="config-select">Configuration</label>
          <select
            id="config-select"
            value={selectedConfig || ''}
            onChange={handleConfigChange}
          >
            {selectedMethod.configs.map(config => (
              <option key={config} value={config}>
                {config.replace('.config.json', '')}
              </option>
            ))}
          </select>
        </div>
      )}

      {/* Single config indicator */}
      {selectedMethod && selectedMethod.configs.length === 1 && (
        <div className="method-config-single">
          Config: {selectedConfig?.replace('.config.json', '') || 'default'}
        </div>
      )}
    </div>
  )
}

export default MethodSelector
