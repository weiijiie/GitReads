//
//  GitHubClient.swift
//  GitReads

import Cache
import Foundation

enum GitHubClientError: Error {
    case unexpectedContentType(owner: String, repo: String, path: String)
}

class GitHubClient: GitClient {

    private let api: GitHubApi
    private let cachedDataFetcherFactory: GitHubCachedDataFetcherFactory

    init(gitHubApi: GitHubApi, cachedDataFetcherFactory: GitHubCachedDataFetcherFactory) {
        self.api = gitHubApi
        self.cachedDataFetcherFactory = cachedDataFetcherFactory
    }

    func getRepository(
        owner: String,
        name: String,
        ref: GitRef? = nil
    ) async -> Swift.Result<GitRepo, Error> {

        async let asyncBranches = api.getRepoBranches(owner: owner, name: name)
        let repo = await api.getRepo(owner: owner, name: name)

        let tree = await repo.asyncFlatMap { repo in
            await api.getRef(owner: owner, repoName: name, ref: ref ?? .branch(repo.defaultBranch))
        }
        .asyncFlatMap { defaultRef in
            await cachedDataFetcher(owner: owner, repo: name, sha: defaultRef.object.sha) {
                await self.api.getTree(owner: owner, repoName: name, treeSha: defaultRef.object.sha)
            }.fetchValue()
        }

        let branches = await asyncBranches

        return repo.flatMap { repo in
            branches.flatMap { branches in
                tree.map { tree in
                    let currBranch = ref?.name ?? repo.defaultBranch
                    let tree = GitTree(
                        commitSha: tree.sha,
                        gitObjects: tree.objects.map(GitObject.init),
                        fileContentFetcher: { object, commitSha in
                            self.getFileContent(owner: owner, repoName: name, object: object, commitSha: commitSha)
                        },
                        symlinkContentFetcher: { object, commitSha in
                            self.getSymlinkContent(owner: owner, repoName: name, object: object, commitSha: commitSha)
                        },
                        submoduleContentFetcher: { object, commitSha in
                            self.getSubmoduleContent(owner: owner, repoName: name, object: object, commitSha: commitSha)
                        }
                    )
                    tree.rootDir.contents.preload()

                    return GitRepo(fullName: repo.fullName,
                                   htmlURL: repo.htmlURL,
                                   description: repo.description ?? "",
                                   defaultBranch: repo.defaultBranch,
                                   branches: branches.map { $0.name },
                                   currBranch: currBranch,
                                   tree: tree)
                }
            }
        }
    }

    private func getFileContent(
        owner: String,
        repoName: String,
        object: GitObject,
        commitSha: String
    ) -> GitContent {
        let fetcher = rawGitHubUserContentFetcher(
            owner: owner, repoName: repoName, object: object, commitSha: commitSha
        )

        let file = GitFile(contents: LazyDataSource(fetcher: fetcher))
        return GitContent(from: object, type: .file(file))
    }

    private func getSymlinkContent(
        owner: String,
        repoName: String,
        object: GitObject,
        commitSha: String
    ) -> GitContent {
        let fetcher = rawGitHubUserContentFetcher(
            owner: owner, repoName: repoName, object: object, commitSha: commitSha
        )

        let symlink = GitSymlink(target: LazyDataSource(fetcher: fetcher))
        return GitContent(from: object, type: .symlink(symlink))
    }

    private func getSubmoduleContent(
        owner: String,
        repoName: String,
        object: GitObject,
        commitSha: String
    ) -> GitContent {
        let fetcher = submoduleContentFetcher(
            owner: owner, repoName: repoName, object: object, commitSha: commitSha
        )

        let submodule = GitSubmodule(gitURL: LazyDataSource(fetcher: fetcher))
        return GitContent(from: object, type: .submodule(submodule))
    }

    private func rawGitHubUserContentFetcher(
        owner: String,
        repoName: String,
        object: GitObject,
        commitSha: String
    ) -> GitHubCachedDataFetcher<String> {
        cachedDataFetcher(owner: owner, repo: repoName, sha: object.sha) {
            await self.api.getRawGitHubUserContent(
                owner: owner,
                repo: repoName,
                commitSha: commitSha,
                path: object.path,
                encoding: .utf8
            )
        }
    }

    private func submoduleContentFetcher(
        owner: String,
        repoName: String,
        object: GitObject,
        commitSha: String
    ) -> GitHubCachedDataFetcher<URL> {
        cachedDataFetcher(owner: owner, repo: repoName, sha: object.sha) {
            let contents = await self.api.getRepoContents(
                owner: owner, name: repoName, path: object.path.string, ref: commitSha
            )

            return contents.flatMap { contents in
                guard case let .submodule(submoduleContent) = contents else {
                    return .failure(GitHubClientError.unexpectedContentType(
                        owner: owner, repo: repoName, path: object.path.string
                    ))
                }

                return .success(submoduleContent.submoduleGitURL)
            }
        }
    }

    private func cachedDataFetcher<T>(
        owner: String,
        repo: String,
        sha: String,
        fetcher: @escaping () async -> Swift.Result<T, Error>
    ) -> GitHubCachedDataFetcher<T> where T: Codable {
        let key = GitHubCacheKey(owner: owner, repo: repo, sha: sha)
        return cachedDataFetcherFactory.makeCachedDataFetcher(key: key, fetcher: fetcher)
    }
 }