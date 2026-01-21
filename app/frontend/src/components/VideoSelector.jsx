import { useState, useEffect } from 'react'
import { fetchVideos, uploadVideo } from '../services/api'
import './VideoSelector.css'

function VideoSelector({ onChange }) {
  const [videos, setVideos] = useState([])
  const [selectedVideo, setSelectedVideo] = useState('')
  const [uploading, setUploading] = useState(false)
  const [uploadedFileName, setUploadedFileName] = useState('')
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
    setUploadedFileName('')
    onChange(path)
  }

  async function handleFileUpload(e) {
    const file = e.target.files?.[0]
    if (!file) return

    try {
      setUploading(true)
      setError(null)
      const result = await uploadVideo(file)
      setUploadedFileName(file.name)
      setSelectedVideo(result.path)
      onChange(result.path)
    } catch (err) {
      setError(`Upload failed: ${err.message}`)
    } finally {
      setUploading(false)
    }
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
            disabled={uploading}
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

      <div className="divider">
        <span>OR</span>
      </div>

      <div className="selector-group">
        <label htmlFor="file-upload">Upload your own video:</label>
        <input
          id="file-upload"
          type="file"
          accept=".mp4,.mov,.m4v"
          onChange={handleFileUpload}
          disabled={uploading}
        />
        {uploading && <div className="loading-text">Uploading...</div>}
        {uploadedFileName && !uploading && (
          <div className="success-text">Uploaded: {uploadedFileName}</div>
        )}
      </div>
    </div>
  )
}

export default VideoSelector
