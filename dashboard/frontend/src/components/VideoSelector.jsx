import { useState, useEffect } from 'react'
import { fetchVideos } from '../services/api'
import './VideoSelector.css'

function VideoSelector({ onChange }) {
  const [videos, setVideos] = useState([])
  const [selectedVideo, setSelectedVideo] = useState('')
  const [error, setError] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadVideos()
  }, [])

  async function loadVideos() {
    try {
      setLoading(true)
      setError(null)
      const videoList = await fetchVideos()
      setVideos(videoList)
    } catch (err) {
      setError(`Failed to load videos: ${err.message}`)
    } finally {
      setLoading(false)
    }
  }

  function handleSelectChange(e) {
    const path = e.target.value
    setSelectedVideo(path)
    onChange(path)
  }

  return (
    <div className="video-selector">
      <h3>Select Video</h3>

      {error && <div className="error-message">{error}</div>}

      <div className="selector-group">
        <label htmlFor="video-dropdown">Choose from test videos:</label>
        {loading ? (
          <div className="loading-text">Loading videos...</div>
        ) : (
          <select
            id="video-dropdown"
            value={selectedVideo}
            onChange={handleSelectChange}
          >
            <option value="">-- Select a video --</option>
            {videos.map((video) => (
              <option key={video.path} value={video.path}>
                {video.name}
              </option>
            ))}
          </select>
        )}
      </div>
    </div>
  )
}

export default VideoSelector
