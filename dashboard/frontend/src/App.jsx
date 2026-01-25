import { BrowserRouter, Routes, Route } from 'react-router-dom'
import Home from './pages/Home'
import Results from './pages/Results'
import Lab from './pages/Lab'
import ErrorBoundary from './components/ErrorBoundary'
import Layout from './components/Layout'
import './App.css'

function App() {
  return (
    <BrowserRouter>
      <ErrorBoundary>
        <Layout>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/results/:runId" element={<Results />} />
            <Route path="/lab/:runId" element={<Lab />} />
          </Routes>
        </Layout>
      </ErrorBoundary>
    </BrowserRouter>
  )
}

export default App
