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
        setMethods(data || [])

        // Restore last selection from localStorage
        const saved = localStorage.getItem(STORAGE_KEY)
        if (saved) {
          const { methodFamily, configName } = JSON.parse(saved)
          const method = data.find(m => m.method === methodFamily)
          if (method) {
            setSelectedMethod(method)
            // Find config
            const config = method.configs.find(c => c.name === configName)
            setSelectedConfig(config || method.configs[0] || null)
          }
        }

        // Default to first method + first config if nothing saved
        if (!saved && data.length > 0) {
          const first = data[0]
          setSelectedMethod(first)
          setSelectedConfig(first.configs[0] || null)
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
        methodFamily: selectedMethod.method,
        configName: selectedConfig.name
      }))

      // Notify parent
      onChange({
        method: selectedMethod.method,
        config: selectedConfig.name,
        methodDisplayName: selectedMethod.displayName,
        configDisplayName: selectedConfig.displayName
      })
    }
  }, [selectedMethod, selectedConfig, onChange])

  const handleMethodChange = useCallback((e) => {
    const methodFamily = e.target.value
    const method = methods.find(m => m.method === methodFamily)
    if (method) {
      setSelectedMethod(method)
      // Reset to first config
      setSelectedConfig(method.configs[0] || null)
    }
  }, [methods])

  const handleConfigChange = useCallback((e) => {
    const configName = e.target.value
    const config = selectedMethod?.configs.find(c => c.name === configName)
    setSelectedConfig(config || null)
  }, [selectedMethod])

  if (loading) {
    return (
      <div className="method-selector">
        <h3>Method & Config</h3>
        <div className="method-loading">Loading methods...</div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="method-selector">
        <h3>Method & Config</h3>
        <div className="method-error">Error: {error}</div>
      </div>
    )
  }

  if (methods.length === 0) {
    return (
      <div className="method-selector">
        <h3>Method & Config</h3>
        <div className="method-empty">
          No methods available. Please ensure SportCrunchRunner is running.
        </div>
      </div>
    )
  }

  return (
    <div className="method-selector">
      <h3>Method & Config</h3>

      {/* Method dropdown */}
      <div className="method-field">
        <label htmlFor="method-select">Method</label>
        <select
          id="method-select"
          value={selectedMethod?.method || ''}
          onChange={handleMethodChange}
        >
          {methods.map(method => (
            <option key={method.method} value={method.method}>
              {method.displayName} ({method.version})
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

      {/* Config dropdown (only if method has configs) */}
      {selectedMethod && selectedMethod.configs && selectedMethod.configs.length > 0 && (
        <div className="method-field">
          <label htmlFor="config-select">Config</label>
          <select
            id="config-select"
            value={selectedConfig?.name || ''}
            onChange={handleConfigChange}
          >
            {selectedMethod.configs.map(config => (
              <option key={config.name} value={config.name}>
                {config.displayName}
              </option>
            ))}
          </select>
        </div>
      )}

      {/* Config description */}
      {selectedConfig && (
        <div className="config-description">
          {selectedConfig.description}
        </div>
      )}

      {/* No config indicator */}
      {selectedMethod && (!selectedMethod.configs || selectedMethod.configs.length === 0) && (
        <div className="method-no-configs">
          This method has no configs
        </div>
      )}
    </div>
  )
}

export default MethodSelector
