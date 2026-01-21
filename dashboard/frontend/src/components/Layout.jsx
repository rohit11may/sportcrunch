import { NavLink } from 'react-router-dom'
import './Layout.css'

function Layout({ children }) {
    return (
        <div className="app-layout">
            <aside className="sidebar">
                <div className="sidebar-header">
                    <h2 className="app-logo">SportCrunch</h2>
                </div>

                <nav className="sidebar-nav">
                    <NavLink
                        to="/"
                        className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
                        end
                    >
                        <span className="nav-icon">🏠</span>
                        Home
                    </NavLink>

                    <div className="nav-divider"></div>

                    {/* We can add more specific links here later, possibly recent runs? */}
                </nav>

                <div className="sidebar-footer">
                    <p>Runner Dashboard v0.1</p>
                </div>
            </aside>

            <main className="main-content">
                <div className="content-scroll-area">
                    {children}
                </div>
            </main>
        </div>
    )
}

export default Layout
