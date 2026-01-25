const API_BASE_URL = import.meta.env.VITE_API_URL || ''

class APIError extends Error {
  constructor(message, status) {
    super(message)
    this.name = 'APIError'
    this.status = status
  }
}

async function handleResponse(response) {
  if (!response.ok) {
    const errorText = await response.text()
    let errorMessage
    try {
      const errorData = JSON.parse(errorText)
      errorMessage = errorData.error || errorData.message || `HTTP ${response.status}`
    } catch {
      errorMessage = errorText || `HTTP ${response.status}`
    }
    throw new APIError(errorMessage, response.status)
  }
  return response.json()
}

export async function fetchVideos() {
  try {
    const response = await fetch(`${API_BASE_URL}/api/videos`)
    return await handleResponse(response)
  } catch (error) {
    if (error instanceof APIError) throw error
    throw new APIError(`Failed to fetch videos: ${error.message}`, 0)
  }
}

export async function uploadVideo(file) {
  try {
    const formData = new FormData()
    formData.append('video', file)

    const response = await fetch(`${API_BASE_URL}/api/videos/upload`, {
      method: 'POST',
      body: formData
    })
    return await handleResponse(response)
  } catch (error) {
    if (error instanceof APIError) throw error
    throw new APIError(`Failed to upload video: ${error.message}`, 0)
  }
}

export async function fetchMethods() {
  try {
    const response = await fetch(`${API_BASE_URL}/api/methods`)
    return await handleResponse(response)
  } catch (error) {
    if (error instanceof APIError) throw error
    throw new APIError(`Failed to fetch methods: ${error.message}`, 0)
  }
}

export async function createRun(videoPath, method, config, deviceId = 'simulator', deviceIp = null) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/runs`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        videoPath,
        method,
        config,
        deviceId,
        deviceIp
      })
    })
    return await handleResponse(response)
  } catch (error) {
    if (error instanceof APIError) throw error
    throw new APIError(`Failed to create run: ${error.message}`, 0)
  }
}

export async function getRun(runId) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/runs/${runId}`)
    return await handleResponse(response)
  } catch (error) {
    if (error instanceof APIError) throw error
    throw new APIError(`Failed to fetch run: ${error.message}`, 0)
  }
}

export async function checkHealth() {
  try {
    const response = await fetch(`${API_BASE_URL}/api/health`)
    return await handleResponse(response)
  } catch (error) {
    if (error instanceof APIError) throw error
    throw new APIError(`Failed to check health: ${error.message}`, 0)
  }
}

export async function fetchDevices() {
  try {
    const response = await fetch(`${API_BASE_URL}/api/devices`)
    return await handleResponse(response)
  } catch (error) {
    if (error instanceof APIError) throw error
    throw new APIError(`Failed to fetch devices: ${error.message}`, 0)
  }
}

export async function copyVideoToDevice(deviceId, videoPath, videoName) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/devices/copy-video`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        deviceId,
        videoPath,
        videoName
      })
    })
    return await handleResponse(response)
  } catch (error) {
    if (error instanceof APIError) throw error
    throw new APIError(`Failed to copy video to device: ${error.message}`, 0)
  }
}
