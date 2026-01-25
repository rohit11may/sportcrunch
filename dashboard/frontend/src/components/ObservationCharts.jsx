import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine } from 'recharts';
import './ObservationCharts.css';

function ObservationCharts({ observations, onTimeClick }) {
  if (!observations || !observations.signals) {
    return null;
  }

  const { signals, events } = observations;

  // Prepare data for audio_flux chart
  const audioFluxData = (signals.audio_flux || []).map(point => ({
    time: point.time,
    value: point.value
  }));

  // Prepare data for motion_score chart
  const motionScoreData = (signals.motion_score || []).map(point => ({
    time: point.time,
    value: point.value
  }));

  // Get audio peak events for reference lines
  const audioPeaks = events.filter(e => e.name === 'audio_peak');

  // Format time for tooltip (MM:SS)
  const formatTime = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const handleChartClick = (data) => {
    if (data && data.activePayload && data.activePayload[0]) {
      const time = data.activePayload[0].payload.time;
      if (onTimeClick) {
        onTimeClick(time);
      }
    }
  };

  return (
    <div className="observation-charts">
      {/* Audio Flux Chart */}
      {audioFluxData.length > 0 && (
        <div className="chart-container">
          <h3>Audio Flux (Onset Strength)</h3>
          <ResponsiveContainer width="100%" height={250}>
            <LineChart
              data={audioFluxData}
              onClick={handleChartClick}
              style={{ cursor: 'pointer' }}
            >
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis
                dataKey="time"
                tickFormatter={formatTime}
                label={{ value: 'Time', position: 'insideBottom', offset: -5 }}
              />
              <YAxis
                label={{ value: 'Onset Strength', angle: -90, position: 'insideLeft' }}
              />
              <Tooltip
                labelFormatter={formatTime}
                formatter={(value) => [value.toFixed(2), 'Onset']}
              />
              <Line
                type="monotone"
                dataKey="value"
                stroke="#8884d8"
                dot={false}
                strokeWidth={2}
                isAnimationActive={false}
              />
              {/* Show audio peaks as reference lines */}
              {audioPeaks.slice(0, 20).map((peak, idx) => (
                <ReferenceLine
                  key={idx}
                  x={peak.timestamp}
                  stroke="#ff7300"
                  strokeDasharray="3 3"
                  label={{ value: '🎵', position: 'top' }}
                />
              ))}
            </LineChart>
          </ResponsiveContainer>
          <p className="chart-hint">
            Click on the chart to seek video to that timestamp. Orange lines show detected audio peaks.
          </p>
        </div>
      )}

      {/* Motion Score Chart */}
      {motionScoreData.length > 0 && (
        <div className="chart-container">
          <h3>Motion Score (Visual Validation)</h3>
          <ResponsiveContainer width="100%" height={250}>
            <LineChart
              data={motionScoreData}
              onClick={handleChartClick}
              style={{ cursor: 'pointer' }}
            >
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis
                dataKey="time"
                tickFormatter={formatTime}
                label={{ value: 'Time', position: 'insideBottom', offset: -5 }}
              />
              <YAxis
                label={{ value: 'Motion Score', angle: -90, position: 'insideLeft' }}
              />
              <Tooltip
                labelFormatter={formatTime}
                formatter={(value) => [value.toFixed(2), 'Motion']}
              />
              <Line
                type="stepAfter"
                dataKey="value"
                stroke="#82ca9d"
                dot={false}
                strokeWidth={2}
                isAnimationActive={false}
              />
            </LineChart>
          </ResponsiveContainer>
          <p className="chart-hint">
            Click on the chart to seek video to that timestamp.
          </p>
        </div>
      )}
    </div>
  );
}

export default ObservationCharts;
