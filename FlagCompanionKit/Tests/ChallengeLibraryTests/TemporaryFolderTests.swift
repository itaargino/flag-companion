import Foundation
import Testing

private enum BodyFailure: Error {
    case thrown
}

private func folderExists(at url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
}

@Test func temporaryFolderExistsAndIsEmptyInsideBody() throws {
    try withTemporaryFolder { folder in
        #expect(folderExists(at: folder))
        let contents = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(contents.isEmpty)
    }
}

@Test func temporaryFolderIsDeletedAfterBody() throws {
    let folder = try withTemporaryFolder { folder in
        try Data("{}".utf8).write(to: folder.appending(path: "ctf.json"))
        return folder
    }
    #expect(!folderExists(at: folder))
}

@Test func temporaryFolderIsDeletedWhenBodyThrows() throws {
    var usedFolder: URL?
    #expect(throws: BodyFailure.thrown) {
        try withTemporaryFolder { folder in
            usedFolder = folder
            throw BodyFailure.thrown
        }
    }
    let folder = try #require(usedFolder)
    #expect(!folderExists(at: folder))
}

@Test func eachTemporaryFolderIsUnique() throws {
    let first = try withTemporaryFolder { $0 }
    let second = try withTemporaryFolder { $0 }
    #expect(first != second)
}
