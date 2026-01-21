import { BrowserRouter, Routes, Route } from 'react-router-dom'
import Home from './pages/Home'
import Results from './pages/Results'
import './App.css'

function App() {
  return (
    <BrowserRouter>
      <div className="app">
        <header>
          <h1>SportCrunch Runner Dashboard</h1>
        </header>
        <main>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/results/:runId" element={<Results />} />
          </Routes>
        </main>
      </div>
    </BrowserRouter>
  )
}

export default App
