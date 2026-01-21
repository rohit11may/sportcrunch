import { useState, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import VideoSelector from '../components/VideoSelector'
import MethodSelector from '../components/MethodSelector'
import RunTrigger from '../components/RunTrigger'
import { createRun, getRun } from '../services/api'
import './Home.css'

function Home() {
  const navigate = useNavigate()
  const [selectedVideo, setSelectedVideo] = useState('')
  const [selectedMethod, setSelectedMethod] = useState('')
  const [isProcessing, setIsProcessing] = useState(false)
  const [error, setError] = useState(null)

  const handleVideoChange = useCallback((videoPath) => {
    setSelectedVideo(videoPath)
    setError(null)
  }, [])

  const handleMethodChange = useCallback((method) => {
    setSelectedMethod(method)
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
    if (!selectedVideo || !selectedMethod) {
      setError('Please select a video and method')
      return
    }

    try {
      setIsProcessing(true)
      setError(null)

      // Create the run
      const result = await createRun(
        selectedVideo,
        selectedMethod,
        'tennis',
        'shot',
        {}
      )

      // Poll for completion
      await pollRunStatus(result.runId)

      // Navigate to results page
      navigate(`/results/${result.runId}`)
    } catch (err) {
      setError(err.message || 'Failed to process video')
      setIsProcessing(false)
    }
  }

  return (
    <div className="home-page">
      <h2>Create New Run</h2>

      <VideoSelector onChange={handleVideoChange} />

      <MethodSelector onChange={handleMethodChange} />

      <RunTrigger
        videoPath={selectedVideo}
        method={selectedMethod}
        isProcessing={isProcessing}
        error={error}
        onTrigger={handleTriggerRun}
      />
    </div>
  )
}

export default Home
