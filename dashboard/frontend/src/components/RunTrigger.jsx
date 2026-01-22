import './RunTrigger.css'

function RunTrigger({ videoPath, method, isProcessing, error, statusMessage, onTrigger }) {
  const canProcess = videoPath && method && !isProcessing

  return (
    <div className="run-trigger">
      <button
        onClick={onTrigger}
        disabled={!canProcess}
        className="process-button"
      >
        {isProcessing ? (
          <>
            <span className="spinner"></span>
            Processing Video...
          </>
        ) : (
          'Process Video'
        )}
      </button>

      {isProcessing && (
        <div className="status-text">
          {statusMessage || 'Processing video... This may take 1-2 minutes for test videos.'}
        </div>
      )}

      {error && (
        <div className="error-box">
          <strong>Error:</strong> {error}
        </div>
      )}

      {!videoPath && !isProcessing && (
        <div className="hint-text">
          Select a video to begin processing
        </div>
      )}
    </div>
  )
}

export default RunTrigger
