//
//  User.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

public struct User: Equatable, Identifiable, Codable, Hashable{
    public let id: String
    public let name: String
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
