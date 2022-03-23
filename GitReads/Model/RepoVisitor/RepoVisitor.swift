//
//  RepoVisitor.swift
//  GitReads
//
//  Created by Tan Kang Liang on 23/3/22.
//

/// Protocol for implementations to traverse the repository structure without having to modify `Repo`.
///
/// Implementations of `RepoVisitor` should not attempt to manually recurse on
/// directories. Visiting of all relevant directories and files will be handled by `Repo`
protocol RepoVisitor {
    func visit(directory: Directory)
    func visit(file: File)
}
