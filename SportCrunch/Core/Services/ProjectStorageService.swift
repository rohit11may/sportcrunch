//
//  ProjectStorageService.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import Foundation

// MARK: - Project Storage Protocol

protocol ProjectStorageServiceProtocol {
    /// Load all saved projects
    func loadProjects() -> [Project]
    
    /// Save a new project
    func saveProject(_ project: Project)
    
    /// Update an existing project
    func updateProject(_ project: Project)
    
    /// Delete a project
    func deleteProject(_ project: Project)
    
    /// Get a project by ID
    func getProject(id: UUID) -> Project?
}

// MARK: - UserDefaults Implementation

final class UserDefaultsProjectStorageService: ProjectStorageServiceProtocol {
    
    private let projectsKey = "com.sportcrunch.projects"
    private let defaults: UserDefaults
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    func loadProjects() -> [Project] {
        guard let data = defaults.data(forKey: projectsKey) else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([Project].self, from: data)
        } catch {
            print("Failed to decode projects: \(error)")
            return []
        }
    }
    
    func saveProject(_ project: Project) {
        var projects = loadProjects()
        projects.insert(project, at: 0)
        saveAllProjects(projects)
    }
    
    func updateProject(_ project: Project) {
        var projects = loadProjects()
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            saveAllProjects(projects)
        }
    }
    
    func deleteProject(_ project: Project) {
        var projects = loadProjects()
        projects.removeAll { $0.id == project.id }
        saveAllProjects(projects)
    }
    
    func getProject(id: UUID) -> Project? {
        loadProjects().first { $0.id == id }
    }
    
    // MARK: - Private
    
    private func saveAllProjects(_ projects: [Project]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(projects)
            defaults.set(data, forKey: projectsKey)
        } catch {
            print("Failed to encode projects: \(error)")
        }
    }
}

// MARK: - Mock Implementation for Previews

final class MockProjectStorageService: ProjectStorageServiceProtocol {
    
    private var projects: [Project] = []
    
    init(withSampleData: Bool = true) {
        if withSampleData {
            var completed1 = Project.sampleTennis
            completed1.status = .completed
            completed1.highlightDuration = 1080
            
            var completed2 = Project.sampleCricket
            completed2.status = .completed
            completed2.highlightDuration = 1800
            
            projects = [completed1, completed2]
        }
    }
    
    func loadProjects() -> [Project] {
        projects
    }
    
    func saveProject(_ project: Project) {
        projects.insert(project, at: 0)
    }
    
    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        }
    }
    
    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
    }
    
    func getProject(id: UUID) -> Project? {
        projects.first { $0.id == id }
    }
}

