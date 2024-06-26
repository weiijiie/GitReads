//
//  RepoSearchView.swift
//  GitReads

import SwiftUI

struct HomeView: View {

    @StateObject private var searchViewModel: RepoSearchViewModel

    let repoService: RepoService

    init(repoService: RepoService) {
        self.repoService = repoService
        _searchViewModel = StateObject(
            wrappedValue: RepoSearchViewModel(gitClient: repoService.gitClient)
        )
    }

    var body: some View {
        NavigationView {
            VStack {
                List {
                    if searchViewModel.isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                    ForEach(searchViewModel.repos, id: \.fullName) { repo in
                        repoSummary(repo)
                            .onAppear {
                                searchViewModel.scrolledToItem(repo: repo)
                            }
                    }
                }

            }
            .navigationTitle("Home")
            .overlay {
                FavouritesView(repoService: repoService)
            }
        }
        .searchable(text: $searchViewModel.searchText, prompt: "Search for a repo")
        .navigationViewStyle(.stack)
    }

    func repoSummary(_ repo: GitRepoSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let fetcher = repoFetcherFor(repoService: repoService, owner: repo.owner, name: repo.name)
            let repoView = RepoHomePageView(repoFetcher: fetcher)
                .navigationBarTitle("", displayMode: .inline)

            NavigationLink(destination: repoView) {
                Text(repo.fullName)
                    .font(.headline)
            }
            if !repo.description.isEmpty {
                Text(repo.description)
                    .fontWeight(.light)
                    .font(.caption)
                    .lineLimit(3)
            }
        }
        .padding()
    }
}

func repoFetcherFor(
    repoService: RepoService,
    owner: String,
    name: String
) -> ((String?) async -> Result<Repo, Error>) {
    { branch in
        let ref = branch.map { GitRef.branch($0) }
        return await repoService.getRepository(owner: owner, name: name, ref: ref)
    }
}

struct FavouritesView: View {

    @Environment(\.managedObjectContext) var managedObjectContext
    @Environment(\.isSearching) var isSearching

    @FetchRequest(sortDescriptors: [SortDescriptor(\.name)])
    var favouritedRepos: FetchedResults<FavouritedRepo>

    @StateObject var viewModel: FavouritesViewModel

    @State private var selectedRepo: FavouritedRepo?
    @State private var showRepoPage = false

    let repoService: RepoService

    init(repoService: RepoService) {
        _viewModel = StateObject(wrappedValue: FavouritesViewModel(repoService: repoService))
        self.repoService = repoService
    }

    var favouritesHeader: some View {
        HStack {
            Label {
                Text("Favourites")
                    .font(.title)
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    func favouriteItem(idx: Int, repo: FavouritedRepo, numRepos: Int) -> some View {
        let first = idx == 0
        let last = idx == numRepos - 1

        return Group {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(repo.owner ?? "")
                            .fontWeight(.light)
                            .foregroundColor(Color(.darkGray))
                            .padding(.top, 12)
                        Text(repo.name ?? "")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.bottom, 12)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .padding(.trailing, 2)
                }

                if !last {
                    Divider()
                }
            }
            .padding(.horizontal)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .background {
                Rectangle()
                    .fill(.white)
                    .cornerRadius(
                        8,
                        corners: first && last ? .allCorners
                        : first ? [.topLeft, .topRight]
                        : last ? [.bottomLeft, .bottomRight]
                        : []
                    )
            }
            .onTapGesture {
                selectedRepo = repo
                showRepoPage = true
            }
        }
    }

    var favouritesView: some View {
        ScrollView {
            HStack {
                Spacer()
                VStack(spacing: 0) {
                    if let selectedRepo = selectedRepo {
                        let fetcher = repoFetcherFor(
                            repoService: repoService,
                            owner: selectedRepo.owner ?? "",
                            name: selectedRepo.name ?? ""
                        )

                        let repoView = RepoHomePageView(repoFetcher: fetcher)
                            .navigationBarTitle("Repo", displayMode: .inline)
                        // We must use a hidden navigation link with the isActive argument instead
                        // of a more normal method where the navigation link is embedded in
                        // the view of the repository. This is to avoid the case where the user
                        // unfavourites a repository after he navigated via this navigation link.
                        // With the other method, the fetched results will update and the repository
                        // will be gone from the search results, causing the navigation link for that repo
                        // to not be rendered, and thus forcibly navigating the user back. With this approach,
                        // the navigation link will still exist so the user can continue browsing in peace :)
                        NavigationLink("", destination: repoView, isActive: $showRepoPage).hidden()
                    }

                    let repos = Array(favouritedRepos.enumerated())
                    ForEach(repos, id: \.element.key) { idx, repo in
                        favouriteItem(idx: idx, repo: repo, numRepos: repos.count)
                    }

                    if favouritedRepos.isEmpty {
                        HStack {
                            Spacer()
                            Text("""
                                 You have no favourited repositories. 😅

                                 Add repositories to your favourites to quickly access them. \
                                 The default branches of repositories you favourite will be \
                                 saved so you can view them offline.
                                 """)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .padding(.vertical, 24)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray6))
                        }
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                Spacer()
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray5))
        }
    }

    var body: some View {
        if !isSearching {
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    VStack {
                        favouritesHeader
                        favouritesView
                            .padding(.bottom, 24)
                    }
                    .padding()
                    .background {
                        Rectangle()
                            .fill(.white)
                            .cornerRadius(32, corners: [.topLeft, .topRight])
                    }
                    .edgesIgnoringSafeArea(.bottom)
                    .frame(width: geometry.size.width, height: geometry.size.height * 9 / 10)
                }
            }
            .transition(.move(edge: .bottom))
            .animation(.easeInOut, value: isSearching)
            .onAppear {
                viewModel.onFavouriteReposLoaded(favouritedRepos, context: managedObjectContext)
            }
        }
    }
}
