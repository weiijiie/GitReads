//
//  ContentView.swift
//  GitReads
//
//  Created by Zhou Jiahao on 10/3/22.
//

import SwiftUI
import CoreData
import Cache

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State var repo: Repo?

    let gitClient: GitClient

    init() {
        let api = GitHubApi()
        let factory = GitHubCachedDataFetcherFactory()
        if factory == nil {
            print("Failed to initialize cache for git client")
        }

        self.gitClient = GitHubClient(gitHubApi: api, cachedDataFetcherFactory: factory)
    }

    var body: some View {
        ZStack {
            RepoSearchView(gitClient: gitClient)
        }
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
