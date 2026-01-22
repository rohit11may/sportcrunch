import { useState, useEffect } from 'react'
import PropTypes from 'prop-types'
import { fetchDevices } from '../services/api'
import './DeviceSelector.css'

const DEVICE_IP_STORAGE_KEY = 'sportcrunch_device_ip'

function DeviceSelector({ onChange, disabled = false }) {
  const [devices, setDevices] = useState([])
  const [selectedDevice, setSelectedDevice] = useState('simulator')
  const [deviceIp, setDeviceIp] = useState(() => {
    return localStorage.getItem(DEVICE_IP_STORAGE_KEY) || ''
  })
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    loadDevices()
  }, [])

  // Notify parent when device or IP changes
  useEffect(() => {
    onChange(selectedDevice, selectedDevice !== 'simulator' ? deviceIp : null)
  }, [selectedDevice, deviceIp, onChange])

  async function loadDevices() {
    try {
      setLoading(true)
      setError(null)
      const deviceList = await fetchDevices()
      setDevices(deviceList)

      // Default to simulator
      if (deviceList.length > 0) {
        const simulator = deviceList.find(d => d.id === 'simulator')
        if (simulator) {
          setSelectedDevice('simulator')
        }
      }
    } catch (err) {
      setError(err.message || 'Failed to load devices')
      console.error('Failed to load devices:', err)
    } finally {
      setLoading(false)
    }
  }

  function handleChange(e) {
    const deviceId = e.target.value
    setSelectedDevice(deviceId)
  }

  function handleIpChange(e) {
    const ip = e.target.value
    setDeviceIp(ip)
    localStorage.setItem(DEVICE_IP_STORAGE_KEY, ip)
  }

  if (loading) {
    return (
      <div className="device-selector">
        <label htmlFor="device-select">Target Device</label>
        <select id="device-select" disabled>
          <option>Loading devices...</option>
        </select>
      </div>
    )
  }

  if (error) {
    return (
      <div className="device-selector error">
        <label htmlFor="device-select">Target Device</label>
        <select id="device-select" disabled>
          <option>Failed to load devices</option>
        </select>
        <div className="error-message">{error}</div>
        <button onClick={loadDevices} className="retry-button">
          Retry
        </button>
      </div>
    )
  }

  return (
    <div className="device-selector">
      <label htmlFor="device-select">Target Device</label>
      <select
        id="device-select"
        value={selectedDevice}
        onChange={handleChange}
        disabled={disabled || devices.length === 0}
      >
        {devices.length === 0 ? (
          <option value="">No devices available</option>
        ) : (
          devices.map(device => (
            <option key={device.id} value={device.id}>
              {device.name}
              {device.model !== 'Simulator' && ` (${device.model})`}
              {device.osVersion && ` - iOS ${device.osVersion}`}
            </option>
          ))
        )}
      </select>

      {selectedDevice !== 'simulator' && (
        <div className="device-info">
          <span className="device-badge">Physical Device</span>
          <div className="ip-input-container">
            <label htmlFor="device-ip">Device IP Address</label>
            <input
              id="device-ip"
              type="text"
              value={deviceIp}
              onChange={handleIpChange}
              placeholder="e.g., 192.168.1.100"
              disabled={disabled}
            />
            <span className="info-text">
              Find in Settings → Wi-Fi → (i) next to your network
            </span>
          </div>
        </div>
      )}
    </div>
  )
}

DeviceSelector.propTypes = {
  onChange: PropTypes.func.isRequired,
  disabled: PropTypes.bool
}

export default DeviceSelector
