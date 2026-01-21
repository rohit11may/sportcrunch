import { useEffect } from 'react'
import './MethodSelector.css'

function MethodSelector({ onChange }) {
  useEffect(() => {
    // Emit SpectralFlux on mount (hardcoded for Phase 6)
    onChange('SpectralFlux')
  }, [onChange])

  return (
    <div className="method-selector">
      <h3>Detection Method</h3>
      <div className="method-info">
        <div className="method-name">SpectralFlux</div>
        <div className="method-description">Audio + Visual Validation</div>
        <div className="method-note">
          Additional methods will be available in Phase 7
        </div>
      </div>
    </div>
  )
}

export default MethodSelector
