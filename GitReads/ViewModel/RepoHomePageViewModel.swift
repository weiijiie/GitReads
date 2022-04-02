//
//  RepoHomePageViewModel.swift
//  GitReads

import SwiftUI
import CoreData

class RepoHomePageViewModel: ObservableObject {

    @Published var readmeContents: String?

    let repo: Repo
    private var preloader: PreloadVisitor?

    init(repo: Repo) {
        self.repo = repo
        self.preload()
    }

    func cleanUp() {
        self.preloader?.stop()
    }

    func preload() {
        self.preloader = PreloadVisitor()
        if let preloader = preloader {
            self.repo.accept(visitor: preloader)
            preloader.preload()
        }
    }

    @MainActor func loadReadme() async throws {
        if readmeContents != nil {
            return
        }

        let readme = repo.root.files.first { $0.isReadme() }
        guard let readme = readme else {
            readmeContents = "*No description provided*"
            return
        }

        let readmeLines = try await readme.parseOutput.value.get().lines
        readmeContents = readmeLines.map { $0.content }.joined(separator: "\n")
    }

    func favouriteRepository(context: NSManagedObjectContext) throws {
        let favouritedRepo = FavouritedRepo(context: context)
        favouritedRepo.name = repo.name
        favouritedRepo.owner = repo.owner
        favouritedRepo.platform = repo.platform

        try context.save()
    }

    func unfavouriteRepository<T: Sequence>(
        context: NSManagedObjectContext,
        repos: T
    ) throws where T.Element == FavouritedRepo {
        for repo in repos {
            context.delete(repo)
        }
        try context.save()
    }
}
