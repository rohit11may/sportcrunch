import { useState, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import VideoSelector from '../components/VideoSelector'
import MethodSelector from '../components/MethodSelector'
import DeviceSelector from '../components/DeviceSelector'
import RunTrigger from '../components/RunTrigger'
import { createRun, getRun, copyVideoToDevice } from '../services/api'
import './Home.css'

function Home() {
  const navigate = useNavigate()
  const [selectedVideo, setSelectedVideo] = useState('')
  const [methodSelection, setMethodSelection] = useState(null)
  const [selectedDevice, setSelectedDevice] = useState('simulator')
  const [deviceIp, setDeviceIp] = useState(null)
  const [isProcessing, setIsProcessing] = useState(false)
  const [error, setError] = useState(null)
  const [statusMessage, setStatusMessage] = useState('')

  const handleVideoChange = useCallback((videoPath) => {
    setSelectedVideo(videoPath)
    setError(null)
  }, [])

  const handleMethodChange = useCallback((method) => {
    setMethodSelection(method)
  }, [])

  const handleDeviceChange = useCallback((deviceId, ip) => {
    setSelectedDevice(deviceId)
    setDeviceIp(ip)
    setError(null)
  }, [])

  async function pollRunStatus(runId) {
    const maxAttempts = 120 // 2 seconds * 120 = 4 minutes max
    let attempts = 0

    while (attempts < maxAttempts) {
      try {
        const run = await getRun(runId)

        if (run.status === 'completed') {
          return run
        } else if (run.status === 'failed') {
          throw new Error(run.error || 'Run failed')
        }

        // Continue polling if queued or running
        await new Promise(resolve => setTimeout(resolve, 2000))
        attempts++
      } catch (err) {
        throw err
      }
    }

    throw new Error('Run timed out after 4 minutes')
  }

  async function handleTriggerRun() {
    if (!selectedVideo || !methodSelection) {
      setError('Please select a video and method')
      return
    }

    try {
      setIsProcessing(true)
      setError(null)
      setStatusMessage('')

      let videoPathToUse = selectedVideo

      // If physical device, copy video first
      if (selectedDevice !== 'simulator') {
        setStatusMessage('Copying video to device...')

        const videoName = selectedVideo.split('/').pop()
        const copyResult = await copyVideoToDevice(
          selectedDevice,
          selectedVideo,
          videoName
        )

        if (copyResult.alreadyExists) {
          setStatusMessage('Video already on device, skipping copy')
        } else if (copyResult.copied) {
          setStatusMessage('Video copied successfully')
        }

        // Use the remote path on the device
        videoPathToUse = `Documents/test-videos/${videoName}`
      }

      setStatusMessage('Creating run...')

      // Create the run
      const result = await createRun(
        videoPathToUse,
        methodSelection.family,
        'tennis',
        'individual',  // Changed from 'shot' to match TennisMode.individual rawValue
        {
          methodVersion: methodSelection.version,
          config: methodSelection.config
        },
        selectedDevice,
        deviceIp
      )

      setStatusMessage('Processing video...')

      // Poll for completion
      await pollRunStatus(result.id)

      // Navigate to results page
      navigate(`/results/${result.id}`)
    } catch (err) {
      setError(err.message || 'Failed to process video')
      setIsProcessing(false)
      setStatusMessage('')
    }
  }

  return (
    <div className="home-page">
      <h2>Create New Run</h2>

      <DeviceSelector onChange={handleDeviceChange} disabled={isProcessing} />

      <VideoSelector onChange={handleVideoChange} />

      <MethodSelector onChange={handleMethodChange} />

      <RunTrigger
        videoPath={selectedVideo}
        method={methodSelection}
        isProcessing={isProcessing}
        error={error}
        statusMessage={statusMessage}
        onTrigger={handleTriggerRun}
      />
    </div>
  )
}

export default Home
